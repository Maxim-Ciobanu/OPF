using PowerModels, PlotlyJS
using Ipopt
using JuMP
const PM = PowerModels

file_path = "./Cases/case5.m"

#a function to deal with two different time variables (done by gpt using Sajad's code)
function run_optimization(data)
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]

    model = JuMP.Model(Ipopt.Optimizer)

    @variable(model, va[i in keys(ref[:bus])])

    @variable(model, ref[:gen][i]["pmin"] <= pg[i in keys(ref[:gen])] <= ref[:gen][i]["pmax"])

    @variable(model, -ref[:branch][l]["rate_a"] <= p[(l,i,j) in ref[:arcs_from]] <= ref[:branch][l]["rate_a"])

    p_expr = Dict([((l,i,j), 1.0*p[(l,i,j)]) for (l,i,j) in ref[:arcs_from]])
    p_expr = merge(p_expr, Dict([((l,j,i), -1.0*p[(l,i,j)]) for (l,i,j) in ref[:arcs_from]]))

    @objective(model, Min, sum(gen["cost"][1]*pg[i]^2 + gen["cost"][2]*pg[i] + gen["cost"][3] for (i,gen) in ref[:gen]))

    for (i,bus) in ref[:ref_buses]
        @constraint(model, va[i] == 0)
    end

    for (i,bus) in ref[:bus]
        # Build a list of the loads and shunt elements connected to the bus i
        bus_loads = [ref[:load][l] for l in ref[:bus_loads][i]]
        bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]

        # Active power balance at node i
        @constraint(model,
            sum(p_expr[a] for a in ref[:bus_arcs][i]) ==    
            sum(pg[g] for g in ref[:bus_gens][i]) -                 # sum of active power generation at bus i -
            sum(load["pd"] for load in bus_loads) -                 # sum of active load consumption at bus i -
            sum(shunt["gs"] for shunt in bus_shunts)*1.0^2          # sum of active shunt element injections at bus i
        )
    end

    # Branch power flow physics and limit constraints
    for (i,branch) in ref[:branch]
        # Build the from variable id of the i-th branch, which is a tuple given by (branch id, from bus, to bus)
        f_idx = (i, branch["f_bus"], branch["t_bus"])

        p_fr = p[f_idx]                     # p_fr is a reference to the optimization variable p[f_idx]

        va_fr = va[branch["f_bus"]]         # va_fr is a reference to the optimization variable va on the from side of the branch
        va_to = va[branch["t_bus"]]         # va_fr is a reference to the optimization variable va on the to side of the branch

        # Compute the branch parameters and transformer ratios from the data
        g, b = PowerModels.calc_branch_y(branch)

        # DC Power Flow Constraint
        @constraint(model, p_fr == -b*(va_fr - va_to))

        # Voltage angle difference limit
        @constraint(model, va_fr - va_to <= branch["angmax"])
        @constraint(model, va_fr - va_to >= branch["angmin"])
    end

    optimize!(model)
    return JuMP.value.(pg), objective_value(model)
end

# Time 1 optimization
data_time1 = PowerModels.parse_file(file_path)
PowerModels.standardize_cost_terms!(data_time1, order=2)
PowerModels.calc_thermal_limits!(data_time1)


pg_time1, cost1 = run_optimization(data_time1)
println("Time 1 generator outputs: ", pg_time1)

# Time 2 optimization with 3% increased demand
data_time2 = deepcopy(data_time1) # Make a copy of the original data

for (bus_id, load) in data_time2["load"]
    data_time2["load"][bus_id]["pd"] *= 1.03
end

pg_time2, cost2= run_optimization(data_time2)
println("Time 2 generator outputs: ", pg_time2)


val_vec = []
size = length(pg_time1)

for i in 1:size
    val = (pg_time2[i] - pg_time1[i])
    push!(val_vec, val)
end


println("The difference between the times: ", val_vec)

ramping = 0.0
for i in 1:size
    global ramping += abs(val_vec[i])
end


println("Total cost with ramping: ")
println(cost1 + cost2 + ramping*7)
println()
println("############################################")
println()



function run_optimization_changes(data, pgChange, epsilon, ind)
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]

    model = JuMP.Model(Ipopt.Optimizer)

    @variable(model, va[i in keys(ref[:bus])])

    @variable(model, ref[:gen][i]["pmin"] <= pg[i in keys(ref[:gen])] <= ref[:gen][i]["pmax"])

    @constraint(model, pg[ind] == pgChange[ind] + epsilon)

    @variable(model, -ref[:branch][l]["rate_a"] <= p[(l,i,j) in ref[:arcs_from]] <= ref[:branch][l]["rate_a"])

    p_expr = Dict([((l,i,j), 1.0*p[(l,i,j)]) for (l,i,j) in ref[:arcs_from]])
    p_expr = merge(p_expr, Dict([((l,j,i), -1.0*p[(l,i,j)]) for (l,i,j) in ref[:arcs_from]]))

    @objective(model, Min, sum(gen["cost"][1]*pg[i]^2 + gen["cost"][2]*pg[i] + gen["cost"][3] for (i,gen) in ref[:gen]))

    for (i,bus) in ref[:ref_buses]
        @constraint(model, va[i] == 0)
    end

    for (i,bus) in ref[:bus]
        # Build a list of the loads and shunt elements connected to the bus i
        bus_loads = [ref[:load][l] for l in ref[:bus_loads][i]]
        bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]

        # Active power balance at node i
        @constraint(model,
            sum(p_expr[a] for a in ref[:bus_arcs][i]) ==    
            sum(pg[g] for g in ref[:bus_gens][i]) -                 # sum of active power generation at bus i -
            sum(load["pd"] for load in bus_loads) -                 # sum of active load consumption at bus i -
            sum(shunt["gs"] for shunt in bus_shunts)*1.0^2          # sum of active shunt element injections at bus i
        )
    end

    # Branch power flow physics and limit constraints
    for (i,branch) in ref[:branch]
        # Build the from variable id of the i-th branch, which is a tuple given by (branch id, from bus, to bus)
        f_idx = (i, branch["f_bus"], branch["t_bus"])

        p_fr = p[f_idx]                     # p_fr is a reference to the optimization variable p[f_idx]

        va_fr = va[branch["f_bus"]]         # va_fr is a reference to the optimization variable va on the from side of the branch
        va_to = va[branch["t_bus"]]         # va_fr is a reference to the optimization variable va on the to side of the branch

        # Compute the branch parameters and transformer ratios from the data
        g, b = PowerModels.calc_branch_y(branch)

        # DC Power Flow Constraint
        @constraint(model, p_fr == -b*(va_fr - va_to))

        # Voltage angle difference limit
        @constraint(model, va_fr - va_to <= branch["angmax"])
        @constraint(model, va_fr - va_to >= branch["angmin"])
    end


    optimize!(model)
    return  JuMP.value.(pg), objective_value(model)
end

cost_vector = []
for i in 1:size
    epsilon = 0.5
    global ramping = 0.0
    for j in 1:2
        pg_change1, cost_after_change1 = run_optimization_changes(data_time1, pg_time1, epsilon, i)
        pg_change2, cost_after_change2 = run_optimization_changes(data_time2, pg_time2, epsilon, i)
        diff_vec = []
        for i in 1:size
            diff = abs(pg_change2[i] - pg_change1[i])
            push!(diff_vec, diff)
        end
        for i in 1:size
            global ramping += diff_vec[i]
        end

        epsilon *= -1
        push!(cost_vector, cost_after_change1 + cost_after_change2 + ramping*7)
        ramping = 0.0
    end
end

