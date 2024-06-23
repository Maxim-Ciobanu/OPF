using PowerModels, Gurobi, JuMP, JLD2, Ipopt
const PM = PowerModels

file_path = "./Cases/case5.m"

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


# Create model
model = JuMP.Model(Gurobi.Optimizer)

# Time periods
T = 1

# load_scenarios_factors = Dict(
#     1 => Dict(1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1),
#     2 => Dict(1 => 1.001, 2 => 1.001, 3 => 1.003, 4 => 1.002, 5 => 1.001),
#     3 => Dict(1 => 0.98, 2 => 0.99, 3 => 0.997, 4 => 0.998, 5 => 0.99)
# )

load_scenarios_factors = Dict(
    1 => Dict(1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1),
    2 => Dict(1 => 1.03, 2 => 1.03, 3 => 1.03, 4 => 1.03, 5 => 1.03),
    3 => Dict(1 => 0.95, 2 => 0.95, 3 => 0.95, 4 => 0.95, 5 => 0.95)
)

# Set a ramping cost
ramping_cost = 10

@variable(model, va[t in 1:T, i in keys(ref[:bus])])

# Define variables
# Sets variables for each 1 -> T with upper and lower bounds

@variable(model, gen_data[g]["pmin"] <= pg[t in 1:T, g in 1:gen_length] <= gen_data[g]["pmax"])
@variable(model, -360 <= theta[t in 1:T, b in 1:bus_length] <= 360, start = 0)
@variable(model, mu_plus[t in 1:T, g in keys(ref[:gen]), s in 1:length(load_scenarios_factors)] >= 0)
@variable(model, mu_minus[t in 1:T, l in keys(ref[:load]), s in 1:length(load_scenarios_factors)] >= 0)

# Stuff below is from Sajads notebook
for t in 1:T
    for (i,bus) in ref[:ref_buses]
        @constraint(model, va[t,i] == 0)
    end
end
@variable(model, -ref[:branch][l]["rate_a"] <= p[1:T,(l,i,j) in ref[:arcs_from]] <= ref[:branch][l]["rate_a"])

p_expr = Dict()
for t in 1:T
    p_expr[t] = Dict()
end
# Iterate over each time period
for t in 1:T
    p_expr[t] = Dict([((l, i, j), 1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs_from]])
    p_expr[t] = merge(p_expr[t], Dict([((l, j, i), -1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs_from]]))
end

# Create a random vector two multiply loads by for each T
factor = [1]
random_vector = 0.975 .+ 0.05 .* rand(T-1)
factor = vcat(factor, random_vector)

num_scenarios = length(load_scenarios_factors)
for t in 1:T
    # Constraints for future scenarios
    for s in 1:num_scenarios
        scenario = load_scenarios_factors[s]
        for b in keys(ref[:bus])
            
            # Active power balance at node i for scenario s
            bus_loads = [ref[:load][l] for l in ref[:bus_loads][b]]
            bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][b]]

            @constraint(model,
                sum(p_expr[t][a] for a in ref[:bus_arcs][b]) ==
                sum(pg[t, g] + mu_plus[t, g, s] for g in ref[:bus_gens][b]) - 
                sum(load["pd"] * scenario[b] + mu_minus[t, l, s] for load in bus_loads for l in ref[:bus_loads][b]) - 
                sum(shunt["gs"] for shunt in bus_shunts)*vm[t,b]^2
            )
        end
    end

    # Branch power flow physics and limit constraints
    for (i,branch) in ref[:branch]
        # Build the from variable id of the i-th branch, which is a tuple given by (branch id, from bus, to bus)
        f_idx = (i, branch["f_bus"], branch["t_bus"])

        p_fr = p[t,f_idx]                     # p_fr is a reference to the optimization variable p[f_idx]

        va_fr = va[t,branch["f_bus"]]         # va_fr is a reference to the optimization variable va on the from side of the branch
        va_to = va[t,branch["t_bus"]]         # va_fr is a reference to the optimization variable va on the to side of the branch

        # Compute the branch parameters and transformer ratios from the data
        g, b = PowerModels.calc_branch_y(branch)

        # DC Power Flow Constraint
        @constraint(model, p_fr == -b*(va_fr - va_to))
    
        # Voltage angle difference limit
        @constraint(model, va_fr - va_to <= branch["angmax"])
        @constraint(model, va_fr - va_to >= branch["angmin"])
    end
end

#compute ramping up and down
@variable(model, ramp_up[t in 2:T, g in keys(ref[:gen])] >= 0)
@variable(model, ramp_down[t in 2:T, g in keys(ref[:gen])] >= 0)


@objective(model, Min,
    sum(sum(ref[:gen][g]["cost"][1] * pg[t, g]^2 + ref[:gen][g]["cost"][2] * pg[t, g] + ref[:gen][g]["cost"][3] for g in keys(ref[:gen])) for t in 1:T) +
    sum(ramping_cost * (ramp_up[t, g] + ramp_down[t, g]) for g in keys(ref[:gen]) for t in 2:T) 
    # Adding some cost for mu_plus and mu_minus.
    + sum(10000 * (mu_plus[t, g, s]^2 + mu_minus[t, l, s]) for g in keys(ref[:gen]) for l in keys(ref[:load]) for t in 1:T for s in 1:length(load_scenarios_factors))
)

for g in keys(ref[:gen])
    for t in 2:T
        @constraint(model, ramp_up[t, g] >= pg[t, g] - pg[t-1, g])
        @constraint(model, ramp_down[t, g] >= pg[t-1, g] - pg[t, g])
    end
end

optimize!(model)
optimal_cost = objective_value(model)
println("Optimal Cost: ")
show(optimal_cost)

initial_pg_values = JuMP.value.(pg)

# I commented out the following line since I dont want the code
# I run to overwride the already "initial_pg_values.jld2" saved file.
# @save "./Attachments/saved_data.jld2" initial_pg_values


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
