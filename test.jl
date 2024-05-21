using PowerModels
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

# Define variables for voltage angles and magnitudes
@variable(model, va[i in keys(local_ref[:bus])])
@variable(model, 0.9 <= vm[i in keys(local_ref[:bus])] <= 1.1)

# Define variables for power flows and generation outputs
@variable(model, -local_ref[:branch][l]["rate_a"] <= p[(l,i,j) in local_ref[:arcs_from]] <= local_ref[:branch][l]["rate_a"])
@variable(model, local_ref[:gen][i]["pmin"] <= pg[i in keys(local_ref[:gen])] <= local_ref[:gen][i]["pmax"])

p_expr = Dict([((l,i,j), 1.0*p[(l,i,j)]) for (l,i,j) in local_ref[:arcs_from]])
p_expr = merge(p_expr, Dict([((l,j,i), -1.0*p[(l,i,j)]) for (l,i,j) in local_ref[:arcs_from]]))

# Objective function for minimizing generation cost
@objective(model, Min, sum(gen["cost"][1]*pg[i]^2 + gen["cost"][2]*pg[i] + gen["cost"][3] for (i,gen) in local_ref[:gen]))

# Reference bus constraint
for (i,bus) in local_ref[:ref_buses]
    @constraint(model, va[i] == 0)
end

# Power balance constraints
for (i,bus) in local_ref[:bus]
    bus_loads = [local_ref[:load][l] for l in local_ref[:bus_loads][i]]
    bus_shunts = [local_ref[:shunt][s] for s in local_ref[:bus_shunts][i]]

    @constraint(model,
        sum(p_expr[a] for a in local_ref[:bus_arcs][i]) ==
        sum(pg[g] for g in local_ref[:bus_gens][i]) -
        sum(load["pd"] for load in bus_loads) -
        sum(shunt["gs"] for shunt in bus_shunts) * vm[i]^2
    )
end

# Branch power flow constraints
for (i,branch) in local_ref[:branch]
    f_idx = (i, branch["f_bus"], branch["t_bus"])
    p_fr = p[f_idx]
    va_fr = va[branch["f_bus"]]
    va_to = va[branch["t_bus"]]
    vm_fr = vm[branch["f_bus"]]
    vm_to = vm[branch["t_bus"]]

    # DC Power Flow approximation
    @constraint(model, p_fr == -(branch["b_fr"]+branch["b_to"]) * (va_fr - va_to))

    # Voltage angle difference limits
    @constraint(model, va_fr - va_to <= branch["angmax"])
    @constraint(model, va_fr - va_to >= branch["angmin"])
end

# Solver settings and optimization
set_optimizer_attribute(model, "max_iter", 1000)
set_optimizer_attribute(model, "tol", 1e-25)

optimize!(model)
println("The solver termination status is $(termination_status(model))")

println("Final Voltage Angles (Thetas) and Magnitudes (Vm):")
for i in keys(local_ref[:bus])
    println("Bus $i: Voltage Angle = $(value(va[i])), Voltage Magnitude = $(value(vm[i]))")
end
