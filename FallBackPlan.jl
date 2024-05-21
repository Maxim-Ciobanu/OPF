using PowerModels
# using Gurobi
using Ipopt
using JuMP
const PM = PowerModels

file_path = "case5.m"

data = PM.parse_file(file_path)
PM.standardize_cost_terms!(data, order=2)
PM.calc_thermal_limits!(data)

local_ref = PM.build_ref(data)[:it][:pm][:nw][0]
local_ref[:bus]

model = JuMP.Model(Ipopt.Optimizer)

@variable(model, va[i in keys(local_ref[:bus])])
@variable(model, -local_ref[:branch][l]["rate_a"] <= p[(l,i,j) in local_ref[:arcs_from]] <= local_ref[:branch][l]["rate_a"])
@variable(model, local_ref[:gen][i]["pmin"] <= pg[i in keys(local_ref[:gen])] <= local_ref[:gen][i]["pmax"])

p_expr = Dict([((l,i,j), 1.0*p[(l,i,j)]) for (l,i,j) in local_ref[:arcs_from]])
p_expr = merge(p_expr, Dict([((l,j,i), -1.0*p[(l,i,j)]) for (l,i,j) in local_ref[:arcs_from]]))

@objective(model, Min, sum(gen["cost"][1]*pg[i]^2 + gen["cost"][2]*pg[i] + gen["cost"][3] for (i,gen) in local_ref[:gen]))

for (i,bus) in local_ref[:ref_buses]
    @constraint(model, va[i] == 0)
end

for (i,bus) in local_ref[:bus]
    # Build a list of the loads and shunt elements connected to the bus i
    bus_loads = [local_ref[:load][l] for l in local_ref[:bus_loads][i]]
    bus_shunts = [local_ref[:shunt][s] for s in local_ref[:bus_shunts][i]]

    # Active power balance at node i
    @constraint(model,
        sum(p_expr[a] for a in local_ref[:bus_arcs][i]) ==    
        sum(pg[g] for g in local_ref[:bus_gens][i]) -                 # sum of active power generation at bus i -
        sum(load["pd"] for load in bus_loads) -                 # sum of active load consumption at bus i -
        sum(shunt["gs"] for shunt in bus_shunts)*1.0^2          # sum of active shunt element injections at bus i
    )
end

# Branch power flow physics and limit constraints
for (i,branch) in local_ref[:branch]
    # Build the from variable id of the i-th branch, which is a tuple given by (branch id, from bus, to bus)
    f_idx = (i, branch["f_bus"], branch["t_bus"])

    p_fr = p[f_idx]                     # p_fr is a reference to the optimization variable p[f_idx]

    va_fr = va[branch["f_bus"]]         # va_fr is a reference to the optimization variable va on the from side of the branch
    va_to = va[branch["t_bus"]]         # va_fr is a reference to the optimization variable va on the to side of the branch

    # Compute the branch parameters and transformer ratios from the data
    g, b = PM.calc_branch_y(branch)

    # DC Power Flow Constraint
    @constraint(model, p_fr == -b*(va_fr - va_to))
   


    # Voltage angle difference limit
    @constraint(model, va_fr - va_to <= branch["angmax"])
    @constraint(model, va_fr - va_to >= branch["angmin"])
end

optimize!(model)
println("The solver termination status is $(termination_status(model))")

println("Final Voltage Angles (Thetas):")
for i in keys(local_ref[:bus])
    println("Bus $i: $(value(va[i]))")
end
