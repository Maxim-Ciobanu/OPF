using PowerModels
using Ipopt
using JuMP
const PM = PowerModels

include("functions.jl")

file_path = "./Cases/case5.m"

# Parse and prepare the network data
data = PowerModels.parse_file(file_path)
PowerModels.standardize_cost_terms!(data, order=2)
PowerModels.calc_thermal_limits!(data)

# Create a copy for the second time period with increased demand
data_time2 = deepcopy(data)
for (bus_id, load) in data_time2["load"]
    load["pd"] *= 1.03  # Increase demand by 3%
end

function run_two_period_optimization(data1, data2)
    model = JuMP.Model(Ipopt.Optimizer)
    
    # Build reference for buses, generators, and branches
    ref1 = PowerModels.build_ref(data1)[:it][:pm][:nw][0]
    ref2 = PowerModels.build_ref(data2)[:it][:pm][:nw][0]

    # Define variables for two periods
    @variable(model, va1[i in keys(ref1[:bus])])
    @variable(model, va2[i in keys(ref2[:bus])])

    @variable(model, ref1[:gen][i]["pmin"] <= pg1[i in keys(ref1[:gen])] <= ref1[:gen][i]["pmax"])
    @variable(model, ref2[:gen][i]["pmin"] <= pg2[i in keys(ref2[:gen])] <= ref2[:gen][i]["pmax"])

    @variable(model, -ref1[:branch][l]["rate_a"] <= p1[(l,i,j) in ref1[:arcs_from]] <= ref1[:branch][l]["rate_a"])
    @variable(model, -ref2[:branch][l]["rate_a"] <= p2[(l,i,j) in ref2[:arcs_from]] <= ref2[:branch][l]["rate_a"])

    # Define objective for minimizing cost over two periods
    @variable(model, ramp[i in keys(ref1[:gen])] >= 0)

    # Enforce ramp limits
    @constraint(model, [i in keys(ref1[:gen])], ramp[i] >= pg2[i] - pg1[i])
    @constraint(model, [i in keys(ref1[:gen])], ramp[i] >= pg1[i] - pg2[i])

    # Define objective function with ramping penalties
    @objective(model, Min, 
        sum(gen["cost"][1]*pg1[i]^2 + gen["cost"][2]*pg1[i] + gen["cost"][3] for (i,gen) in ref1[:gen]) +
        sum(gen["cost"][1]*pg2[i]^2 + gen["cost"][2]*pg2[i] + gen["cost"][3] for (i,gen) in ref2[:gen]) + 
        sum(7 * ramp[i] for i in keys(ref1[:gen]))
    )
    # Reference bus angle constraints for both periods
    for (i,bus) in ref1[:ref_buses]
        @constraint(model, va1[i] == 0)
    end
    for (i,bus) in ref2[:ref_buses]
        @constraint(model, va2[i] == 0)
    end


    p_expr1 = Dict([((l,i,j), 1.0*p1[(l,i,j)]) for (l,i,j) in ref1[:arcs_from]])
    p_expr1 = merge(p_expr1, Dict([((l,j,i), -1.0*p1[(l,i,j)]) for (l,i,j) in ref1[:arcs_from]]))

    p_expr2 = Dict([((l,i,j), 1.0*p2[(l,i,j)]) for (l,i,j) in ref2[:arcs_from]])
    p_expr2 = merge(p_expr2, Dict([((l,j,i), -1.0*p2[(l,i,j)]) for (l,i,j) in ref2[:arcs_from]]))


    for (i,bus) in ref1[:bus]
        # Build a list of the loads and shunt elements connected to the bus i
        bus_loads1 = [ref1[:load][l] for l in ref1[:bus_loads][i]]
        bus_shunts1 = [ref1[:shunt][s] for s in ref1[:bus_shunts][i]]

        # Active power balance at node i
        @constraint(model,
            sum(p_expr1[a] for a in ref1[:bus_arcs][i]) ==    
            sum(pg1[g] for g in ref1[:bus_gens][i]) -                 # sum of active power generation at bus i -
            sum(load["pd"] for load in bus_loads1) -                 # sum of active load consumption at bus i -
            sum(shunt["gs"] for shunt in bus_shunts1)*1.0^2          # sum of active shunt element injections at bus i
        )
    end
    for (i,bus) in ref2[:bus]
        # Build a list of the loads and shunt elements connected to the bus i
        bus_loads2 = [ref2[:load][l] for l in ref2[:bus_loads][i]]
        bus_shunts2 = [ref2[:shunt][s] for s in ref2[:bus_shunts][i]]

        # Active power balance at node i
        @constraint(model,
            sum(p_expr2[a] for a in ref2[:bus_arcs][i]) ==    
            sum(pg2[g] for g in ref2[:bus_gens][i]) -                 # sum of active power generation at bus i -
            sum(load["pd"] for load in bus_loads2) -                 # sum of active load consumption at bus i -
            sum(shunt["gs"] for shunt in bus_shunts2)*1.0^2          # sum of active shunt element injections at bus i
        )
    end

    # Branch flow and angle constraints for both periods
    for (i,branch) in ref1[:branch]
        # Build the from variable id of the i-th branch, which is a tuple given by (branch id, from bus, to bus)
        f_idx1 = (i, branch["f_bus"], branch["t_bus"])

        p_fr1 = p1[f_idx1]                     # p_fr is a reference to the optimization variable p[f_idx]

        va_fr1 = va1[branch["f_bus"]]         # va_fr is a reference to the optimization variable va on the from side of the branch
        va_to1 = va1[branch["t_bus"]]         # va_fr is a reference to the optimization variable va on the to side of the branch

        # Compute the branch parameters and transformer ratios from the data
        g, b = PowerModels.calc_branch_y(branch)

        # DC Power Flow Constraint
        @constraint(model, p_fr1 == -b*(va_fr1 - va_to1))

        # Voltage angle difference limit
        @constraint(model, va_fr1 - va_to1 <= branch["angmax"])
        @constraint(model, va_fr1 - va_to1 >= branch["angmin"])
    end
    # Branch power flow physics and limit constraints
    for (i,branch) in ref2[:branch]
        # Build the from variable id of the i-th branch, which is a tuple given by (branch id, from bus, to bus)
        f_idx2 = (i, branch["f_bus"], branch["t_bus"])

        p_fr2 = p2[f_idx2]                     # p_fr is a reference to the optimization variable p[f_idx]

        va_fr2 = va2[branch["f_bus"]]         # va_fr is a reference to the optimization variable va on the from side of the branch
        va_to2 = va2[branch["t_bus"]]         # va_fr is a reference to the optimization variable va on the to side of the branch

        # Compute the branch parameters and transformer ratios from the data
        g, b = PowerModels.calc_branch_y(branch)

        # DC Power Flow Constraint
        @constraint(model, p_fr2 == -b*(va_fr2 - va_to2))

        # Voltage angle difference limit
        @constraint(model, va_fr2 - va_to2 <= branch["angmax"])
        @constraint(model, va_fr2 - va_to2 >= branch["angmin"])
    end

    optimize!(model)

    # Collect results
    pg1_values = JuMP.value.(pg1)
    pg2_values = JuMP.value.(pg2)
    total_cost = objective_value(model)
    return pg1_values, pg2_values, total_cost
end


# Run the optimization
pg_time1, pg_time2, total_cost = run_two_period_optimization(data, data_time2)
println("Time 1 generator outputs: ", pg_time1)
println("Time 2 generator outputs: ", pg_time2)
println("Total cost: ", total_cost)
