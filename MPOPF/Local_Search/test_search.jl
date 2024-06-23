using Ipopt, Gurobi, JuMP, JLD2, PowerModels
const PM = PowerModels

file_path = "././Cases/case14.m"

data = PowerModels.parse_file(file_path)
PowerModels.standardize_cost_terms!(data, order=2)
PowerModels.calc_thermal_limits!(data)

ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
bus_data = ref[:bus]
gen_data = ref[:gen]
branch_data = ref[:branch]
load_data = ref[:load]

gen_length = length(gen_data)

@load "././Attachments/saved_data.jld2" initial_pg_values initial_optimal_value

function local_search(original_model::Model, pg, T::Int, gen_length::Int, epsilon::Float64, i, j)
    # Copy the model to avoid modifying the original model
    new_model = copy(original_model)
    set_optimizer(new_model, Ipopt.Optimizer)
    # Apply the epsilon perturbation to the first generator's pg value
    
    # Update the pg values in the copied model
    changed_pg = pg[i,j] + epsilon
    @constraint(new_model, pg[i,j] == changed_pg)

    # Resolve the new model
    optimize!(new_model)

    # Check feasibility
    status = termination_status(new_model)
    status = string(status)
    # Get the objective value from the new model
    obj_value = objective_value(new_model)

    # Get the updated pg values from the new model
    updated_pg_values = [value(pg[t, g]) for t in 1:T, g in 1:gen_length]

    return obj_value, updated_pg_values, status
end


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
model = JuMP.Model(Ipopt.Optimizer)

# Time periods
T = 3
# Set a ramping cost
ramping_cost = 7

@variable(model, va[t in 1:T, i in keys(ref[:bus])])

# Define variables
# Sets variables for each 1 -> T with upper and lower bounds
@variable(model, gen_data[g]["pmin"] <= pg[t in 1:T, g in 1:gen_length] <= gen_data[g]["pmax"])
@constraint(model, pg .>= 0)
@variable(model, -360 <= theta[t in 1:T, b in 1:bus_length] <= 360, start = 0)

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
random_vector = [0.975, 0.98, 1.01, 1.015, 1.025, 0.99, 0.975, 1.03, 0.975, 0.98, 1.01, 1.015, 1.025, 0.99, 0.975, 1.03, 0.975, 0.98, 1.01, 1.015, 1.025, 0.99, 0.975]
factor = vcat(factor, random_vector)

for t in 1:T
    for (i,bus) in ref[:bus]
        # Build a list of the loads and shunt elements connected to the bus i
        bus_loads = [ref[:load][l] for l in ref[:bus_loads][i]]
        bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]

        # Active power balance at node i
        @constraint(model,
            sum(p_expr[t][a] for a in ref[:bus_arcs][i]) ==    
            sum(pg[t, g] for g in ref[:bus_gens][i]) -  # Note the double loop over t and g
            sum(load["pd"] * factor[t] for load in bus_loads) -       # Maybe add * increase here               
            sum(shunt["gs"] for shunt in bus_shunts)*1.0^2          
        )
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
sum(sum(ref[:gen][g]["cost"][1]*pg[t,g]^2 + ref[:gen][g]["cost"][2]*pg[t,g] + ref[:gen][g]["cost"][3] for g in keys(ref[:gen])) for t in 1:T) +
sum(ramping_cost * (ramp_up[t, g] + ramp_down[t, g]) for g in keys(ref[:gen]) for t in 2:T)

)

for g in keys(ref[:gen])
    for t in 2:T
        @constraint(model, ramp_up[t, g] >= pg[t, g] - pg[t-1, g])
        @constraint(model, ramp_down[t, g] >= pg[t-1, g] - pg[t, g])
    end
end

optimize!(model)
println("Optimal Cost: ", objective_value(model))
status = termination_status(model)
status = string(status)
println(value.(pg))

global results = []
for t in 1:T
    for g in 1:gen_length
        temp = local_search(model, value.(pg), T, gen_length, 0.01, t, g)
        push!(results, temp)
    end
end

for x in results
    println(x[1])
    println(value.(x[2]))
    println(x[3])
    println()
end