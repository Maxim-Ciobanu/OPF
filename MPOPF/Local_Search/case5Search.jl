using PowerModels, Gurobi, JuMP, JLD2, Ipopt
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

function single_change_solve_model(solver, data, new_pg, epsilon, T, x, y)
    # Initialize variables
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
    bus_data = ref[:bus]
    gen_data = ref[:gen]

    # Create model
    model = JuMP.Model(solver.Optimizer)

    # Time periods
    
    # Set a ramping cost
    ramping_cost = 7

    @variable(model, va[t in 1:T, i in keys(ref[:bus])])

    # Define variables
    # Sets variables for each 1 -> T with upper and lower bounds
    @variable(model, gen_data[g]["pmin"] <= pg[t in 1:T, g in 1:gen_length] <= gen_data[g]["pmax"], start = value(new_pg[t,g]))
    @constraint(model, pg .>= 0)
    @variable(model, -360 <= theta[t in 1:T, b in 1:bus_length] <= 360, start = 0)

    # Modify some pg value +/- epsilon
    changed_pg = new_pg[x, y] + epsilon
    @constraint(model, pg[x,y] == changed_pg)
    
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
    status = termination_status(model)
    status = string(status)

    if status == "LOCALLY_SOLVED"
        return objective_value(model), pg, status
    else
        return status
    end
end

function two_var_change_solve_model(solver, data, new_pg, epsilon1, epsilon2, T, x, y)
    # Initialize variables
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
    bus_data = ref[:bus]
    gen_data = ref[:gen]

    gen_length = length(gen_data)
    bus_length = length(bus_data)

    # Create model
    model = JuMP.Model(solver.Optimizer)

    # Time periods
    
    # Set a ramping cost
    ramping_cost = 7

    @variable(model, va[t in 1:T, i in keys(ref[:bus])])

    # Define variables
    # Sets variables for each 1 -> T with upper and lower bounds
    @variable(model, gen_data[g]["pmin"] <= pg[t in 1:T, g in 1:gen_length] <= gen_data[g]["pmax"], start = value(new_pg[t,g]))
    @constraint(model, pg .>= 0)
    @variable(model, -360 <= theta[t in 1:T, b in 1:bus_length] <= 360, start = 0)

    # Modify some pg value +/- epsilon
    changed_pg1 = new_pg[x, y] + epsilon1
    @constraint(model, pg[x,y] == changed_pg1)

    changed_pg2 = new_pg[x, y + 1] + epsilon2
    @constraint(model, pg[x, y + 1] == changed_pg2)
    
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
    status = termination_status(model)
    status = string(status)

    if status == "LOCALLY_SOLVED"
        return objective_value(model), pg, status
    else
        return status
    end
end

function single_variable_neighbourhood(initial_optimal_value, initial_pg_values, solver, data, epsilon, T)
    new_optimal_value = initial_optimal_value
    new_pg_values = initial_pg_values
    iterations = 0
    diff_of_solutions = Inf

    while iterations < 40 && diff_of_solutions > 0.01
        results = []
        for t in 1:T
            for i in 1:gen_length
                temp = single_change_solve_model(solver, data, value.(new_pg_values), epsilon, T, t, i)
                push!(results, temp)
            end
        end

        solved_pairs = filter(x -> x[3] == "LOCALLY_SOLVED", results)
        if !isempty(solved_pairs)
            min_tuple = solved_pairs[argmin(x[1] for x in solved_pairs)]

            if min_tuple[1] < new_optimal_value
                new_optimal_value = min_tuple[1]
                new_pg_values = min_tuple[2]  
                iterations = 0  # Reset iterations if a cheaper solution is found
            end
        end

        diff_of_solutions = initial_optimal_value - new_optimal_value
        if initial_optimal_value > new_optimal_value
            initial_optimal_value = new_optimal_value
        end
        iterations += 1
    end

    return new_optimal_value, new_pg_values
end

function two_variable_neighbourhood(initial_optimal_value, initial_pg_values, solver, data, epsilon, T)
    new_optimal_value = initial_optimal_value
    new_pg_values = initial_pg_values
    iterations = 0
    diff_of_solutions = Inf
    epsilon1 = epsilon
    epsilon2 = -epsilon

    while iterations < 40 && diff_of_solutions > 0.01
        results = []
        for t in 1:T
            for i in 1:gen_length - 1
                temp = two_var_change_solve_model(solver, data, value.(new_pg_values), epsilon1, epsilon2, T, t, i)
                push!(results, temp)
            end
        end
        
        solved_pairs = filter(x -> x[3] == "LOCALLY_SOLVED", results)
        if !isempty(solved_pairs)
            min_tuple = solved_pairs[argmin(x[1] for x in solved_pairs)]

            if min_tuple[1] < new_optimal_value
                new_optimal_value = min_tuple[1]
                new_pg_values = min_tuple[2]  
                iterations = 0  # Reset iterations if a cheaper solution is found
            end
        end

        diff_of_solutions = initial_optimal_value - new_optimal_value
        if initial_optimal_value > new_optimal_value
            initial_optimal_value = new_optimal_value
        end
        iterations += 1

        diff_of_solutions = initial_optimal_value - new_optimal_value
        if initial_optimal_value > new_optimal_value
            initial_optimal_value = new_optimal_value
        end
        iterations += 1
    end

    return new_optimal_value, new_pg_values
end




##############################################

##############################################

T = 3

# Use random epsilon with range 0.005 - 0.025
epsilon = 0.01 #-(0.025 + (0.005 - 0.025) * rand())

# Solver to be used 
solver = Ipopt

new_values = single_variable_neighbourhood(initial_optimal_value, initial_pg_values, solver, data, epsilon, T)

new_values = two_variable_neighbourhood(new_values[1], new_values[2], solver, data, 0.01, T)

println("Initial optimal value: ", initial_optimal_value)
println("Lowest found value in search: ", new_values[1])