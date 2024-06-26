using PowerModels, Ipopt, Gurobi, JuMP, JLD2
const PM = PowerModels

file_path = "././Cases/case5.m"

data = PowerModels.parse_file(file_path)
PowerModels.standardize_cost_terms!(data, order=2)
PowerModels.calc_thermal_limits!(data)

# Initialize variables
ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
bus_data = ref[:bus]
gen_data = ref[:gen]
branch_data = ref[:branch]
load_data = ref[:load]

gen_length = length(gen_data)
bus_length = length(bus_data)
branch_length = length(branch_data)
load_length = length(load_data)

# Time periods
T = 1

# Create a random vector two multiply loads by for each T
factor = [1]
random_vector = [0.975, 0.98, 1.01, 1.015, 1.025, 0.99, 0.975, 1.03, 0.975, 0.98, 1.01, 1.015, 1.025, 0.99, 0.975, 1.03, 0.975, 0.98, 1.01, 1.015, 1.025, 0.99, 0.975]
factor = vcat(factor, random_vector)

# Set a ramping cost
ramping_cost = 7

# Possible scenarios for loads in the next time period
# load_scenarios_factors = Dict( # 2 scenarios for 3 load factors
#     1 => Dict(1 => 1.03, 2 => 1.03, 3 => 1.03, 4 => 1.03, 5 => 1.03), # 3% increase
#     2 => Dict(1 => 0.95, 2 => 0.95, 3 => 0.95, 4 => 0.95, 5 => 0.95)  # 5% decrease
# )
# load_scenarios_factors = Dict(
#     1 => Dict(1 => 1.03, 2 => 1.03, 3 => 1.03, 4 => 1.03, 5 => 1.03),
# )
# load_scenarios_factors = Dict(
#     1 => Dict(1 => 1.03, 2 => 1.03, 3 => 1.03, 4 => 1.03, 5 => 1.03),
#     2 => Dict(1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1)
# )
load_scenarios_factors = Dict(
    1 => Dict(1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1),
    2 => Dict(1 => 1.03, 2 => 1.03, 3 => 1.03, 4 => 1.03, 5 => 1.03),
    3 => Dict(1 => 0.95, 2 => 0.95, 3 => 0.95, 4 => 0.95, 5 => 0.95)
)

# load_scenarios_factors = Dict(
#     1 => Dict(1 => 1.001, 2 => 1.001, 3 => 1.001, 4 => 1.001, 5 => 1.001),
# )



# Create model
model = JuMP.Model(Ipopt.Optimizer) # Use Ipopt for AC-OPF

@variable(model, va[t in 1:T, i in keys(ref[:bus])])
@variable(model, ref[:bus][i]["vmin"] <= vm[t in 1:T, i in keys(ref[:bus])] <= ref[:bus][i]["vmax"], start=1.0)
@variable(model, ref[:gen][i]["pmin"] <= pg[t in 1:T, i in keys(ref[:gen])] <= ref[:gen][i]["pmax"])
@variable(model, ref[:gen][i]["qmin"] <= qg[t in 1:T, i in keys(ref[:gen])] <= ref[:gen][i]["qmax"])
@variable(model, -ref[:branch][l]["rate_a"] <= p[1:T,(l,i,j) in ref[:arcs]] <= ref[:branch][l]["rate_a"])
@variable(model, -ref[:branch][l]["rate_a"] <= q[1:T,(l,i,j) in ref[:arcs]] <= ref[:branch][l]["rate_a"])

# Ramping Up and Ramping Down
@variable(model, ramp_up[t in 2:T, g in keys(ref[:gen])] >= 0)
@variable(model, ramp_down[t in 2:T, g in keys(ref[:gen])] >= 0)

# Variables for changes in generation to meet future scenarios
@variable(model, mu_plus[t in 1:T, g in keys(ref[:gen]), s in 1:length(load_scenarios_factors)] >= 0)
@variable(model, mu_minus[t in 1:T, l in keys(ref[:load]), s in 1:length(load_scenarios_factors)] >= 0)

# Objective function with ramping costs
# @objective(model, Min,
# sum(sum(ref[:gen][g]["cost"][1]*pg[t,g]^2 + ref[:gen][g]["cost"][2]*pg[t,g] + ref[:gen][g]["cost"][3] for g in keys(ref[:gen])) for t in 1:T) +
# sum(ramping_cost * (ramp_up[t, g] + ramp_down[t, g]) for g in keys(ref[:gen]) for t in 2:T)
# )

# Objective function with ramping costs and expected costs for scenarios
@objective(model, Min,
    sum(sum(ref[:gen][g]["cost"][1] * pg[t, g]^2 + ref[:gen][g]["cost"][2] * pg[t, g] + ref[:gen][g]["cost"][3] for g in keys(ref[:gen])) for t in 1:T) +
    sum(ramping_cost * (ramp_up[t, g] + ramp_down[t, g]) for g in keys(ref[:gen]) for t in 2:T) 
    # Adding some cost for mu_plus and mu_minus.
    + sum(10000 * (mu_plus[t, g, s] + mu_minus[t, l, s]) for g in keys(ref[:gen]) for l in keys(ref[:load]) for t in 1:T for s in 1:length(load_scenarios_factors))
)

# Stuff below is from Sajads notebook
for t in 1:T
    for (i,bus) in ref[:ref_buses]
        @constraint(model, va[t,i] == 0)
    end
end

ref[:load]

num_scenarios = length(load_scenarios_factors)
for t in 1:T
    # for (i,bus) in ref[:bus]
    #     # Build a list of the loads and shunt elements connected to the bus i
    #     bus_loads = [ref[:load][l] for l in ref[:bus_loads][i]]
    #     bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]

    #     # Active power balance at node i
    #     @constraint(model,
    #         sum(p[t,a] for a in ref[:bus_arcs][i]) ==    
    #         sum(pg[t, g] for g in ref[:bus_gens][i]) -  # Note the double loop over t and g
    #         sum(load["pd"] * factor[t] for load in bus_loads) -       # Maybe add * increase here               
    #         sum(shunt["gs"] for shunt in bus_shunts)*vm[t,i]^2
    #     )

    #     @constraint(model,
    #         sum(q[t,a] for a in ref[:bus_arcs][i]) ==    
    #         sum(qg[t, g] for g in ref[:bus_gens][i]) -  # Note the double loop over t and g
    #         sum(load["qd"] * factor[t] for load in bus_loads) +       # Maybe add * increase here               
    #         sum(shunt["bs"] for shunt in bus_shunts)*vm[t,i]^2         
    #     )
    # end

    # Constraints for future scenarios

    for s in 1:num_scenarios
        scenario = load_scenarios_factors[s]
        for b in keys(ref[:bus])
            
            # Active power balance at node i for scenario s
            bus_loads = [ref[:load][l] for l in ref[:bus_loads][b]]
            bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][b]]
            # adjusted_pd = isempty(bus_loads) ? 0.0 : sum(load["pd"] * scenario[b] for load in bus_loads)
            # adjusted_qd = isempty(bus_loads) ? 0.0 : sum(load["qd"] * scenario[b] for load in bus_loads)
            # adjusted_pd = isempty(bus_loads) ? 0.0 : sum(load["pd"] * scenario[b] + mu_minus[t, l, s] for load in bus_loads for l in ref[:bus_loads][b])


            # Active power balance at node i
            # @constraint(model,
            #     sum(p[t,a] for a in ref[:bus_arcs][b]) ==    
            #     sum(pg[t, g] for g in ref[:bus_gens][b]) -  # Note the double loop over t and g
            #     sum(load["pd"] * factor[t] for load in bus_loads) -       # Maybe add * increase here               
            #     sum(shunt["gs"] for shunt in bus_shunts)*vm[t,b]^2
            # )

            # @constraint(model,
            #     sum(q[t,a] for a in ref[:bus_arcs][b]) ==    
            #     sum(qg[t, g] for g in ref[:bus_gens][b]) -  # Note the double loop over t and g
            #     sum(load["qd"] * factor[t] for load in bus_loads) +       # Maybe add * increase here               
            #     sum(shunt["bs"] for shunt in bus_shunts)*vm[t,b]^2         
            # )

            # @constraint(model,
            #     sum(p[t, a] for a in ref[:bus_arcs][b]) ==
            #     sum(pg[t, g] + mu_plus[t, g, s] - mu_minus[t, g, s] for g in ref[:bus_gens][b]) - 
            #     adjusted_pd - 
            #     sum(shunt["gs"] for shunt in bus_shunts)*vm[t,b]^2
            # )

            # @constraint(model,
            #     sum(q[t, a] for a in ref[:bus_arcs][b]) ==
            #     sum(qg[t, g] for g in ref[:bus_gens][b]) - 
            #     adjusted_qd + 
            #     sum(shunt["bs"] for shunt in bus_shunts)*vm[t,b]^2 
            # )

            @constraint(model,
                sum(p[t, a] for a in ref[:bus_arcs][b]) ==
                sum(pg[t, g] + mu_plus[t, g, s] for g in ref[:bus_gens][b]) - 
                sum(load["pd"] * scenario[b] + mu_minus[t, l, s] for load in bus_loads for l in ref[:bus_loads][b]) - 
                sum(shunt["gs"] for shunt in bus_shunts)*vm[t,b]^2
            )

            @constraint(model,
                sum(q[t, a] for a in ref[:bus_arcs][b]) ==
                sum(qg[t, g] for g in ref[:bus_gens][b]) - 
                sum(load["qd"] * scenario[b] + mu_minus[t, l, s] for load in bus_loads for l in ref[:bus_loads][b]) + 
                sum(shunt["bs"] for shunt in bus_shunts)*vm[t,b]^2 
            )
        end
    end

    # Branch power flow physics and limit constraints
    for (i,branch) in ref[:branch]
        # Build the from variable id of the i-th branch, which is a tuple given by (branch id, from bus, to bus)
        f_idx = (i, branch["f_bus"], branch["t_bus"])
        t_idx = (i, branch["t_bus"], branch["f_bus"])

        p_to = p[t,t_idx]
        q_to = q[t,t_idx]
        p_fr = p[t,f_idx]                     # p_fr is a reference to the optimization variable p[f_idx]
        q_fr = q[t,f_idx]

        va_fr = va[t,branch["f_bus"]]         # va_fr is a reference to the optimization variable va on the from side of the branch
        va_to = va[t,branch["t_bus"]]         # va_fr is a reference to the optimization variable va on the to side of the branch
        vm_fr = vm[t,branch["f_bus"]]
        vm_to = vm[t,branch["t_bus"]]

        # Compute the branch parameters and transformer ratios from the data
        g, b = PowerModels.calc_branch_y(branch)
        tr, ti = PowerModels.calc_branch_t(branch)
        ttm = tr^2 + ti^2
        
        # Note: Dont know if we need t index here
        g_fr = branch["g_fr"]
        b_fr = branch["b_fr"]
        g_to = branch["g_to"]
        b_to = branch["b_to"]

        # From side of the branch flow
        @constraint(model, p_fr ==  (g+g_fr)/ttm*vm_fr^2 + (-g*tr+b*ti)/ttm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-b*tr-g*ti)/ttm*(vm_fr*vm_to*sin(va_fr-va_to)) )
        @constraint(model, q_fr == -(b+b_fr)/ttm*vm_fr^2 - (-b*tr-g*ti)/ttm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-g*tr+b*ti)/ttm*(vm_fr*vm_to*sin(va_fr-va_to)) )

        # To side of the branch flow
        @constraint(model, p_to ==  (g+g_to)*vm_to^2 + (-g*tr-b*ti)/ttm*(vm_to*vm_fr*cos(va_to-va_fr)) + (-b*tr+g*ti)/ttm*(vm_to*vm_fr*sin(va_to-va_fr)) )
        @constraint(model, q_to == -(b+b_to)*vm_to^2 - (-b*tr+g*ti)/ttm*(vm_to*vm_fr*cos(va_to-va_fr)) + (-g*tr-b*ti)/ttm*(vm_to*vm_fr*sin(va_to-va_fr)) )
    
        # Voltage angle difference limit
        @constraint(model, va_fr - va_to <= branch["angmax"])
        @constraint(model, va_fr - va_to >= branch["angmin"])

        # Apparent power limit, from side and to side
        @constraint(model, p_fr^2 + q_fr^2 <= branch["rate_a"]^2)
        @constraint(model, p_to^2 + q_to^2 <= branch["rate_a"]^2)
    end
end

for g in keys(ref[:gen])
    for t in 2:T
        @constraint(model, ramp_up[t, g] >= pg[t, g] - pg[t-1, g])
        @constraint(model, ramp_down[t, g] >= pg[t-1, g] - pg[t, g])
    end
end





optimize!(model)
optimal_cost = objective_value(model)

println()
println()
println()
println("Optimal Cost: ")
display(optimal_cost)

AC_initial_pg_values_Uncertainty = JuMP.value.(pg)
# @save "./Attachments/AC_initial_pg_values_Uncertainty.jld2" AC_initial_pg_values_Uncertainty


println()
println()
println()
println("PG-Values: ")
display(JuMP.value.(pg))

println()
println()
println()
println("mu-plus: ")
display(JuMP.value.(mu_plus))

println()
println()
println()
println("mu-minus: ")
display(JuMP.value.(mu_minus))

# println()
# println()
# println()
# println("mu-difference: ")
# display(JuMP.value.(mu_plus).data-JuMP.value.(mu_minus).data)

# And data, a 1×5 Matrix{Float64}:
#  4.70694  -6.51851e-9  1.7  3.24498  0.4
