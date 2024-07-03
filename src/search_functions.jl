function single_variable_search(power_flow_model, T, num_of_gens, epsilon)
    current_pg = value.(power_flow_model.model[:pg])
    current_obj_value = objective_value(power_flow_model.model)
    new_pg = current_pg
    new_obj_value = current_obj_value
    iterations = 0
    diff_of_solutions = Inf
    
    while iterations < 5 && diff_of_solutions > 0.01
        results = []
        for t in 1:T
            for g in 1:num_of_gens
                for i in 1:2
                    temp = single_variable_solve(power_flow_model, epsilon, t, g)
                    push!(results, temp)
                    # Re-optimize model to avoid querying results on modified model
                    optimize!(power_flow_model.model)
                    epsilon *= -1
                end
            end
        end
        # Filter solved models for cheapest objective value
        solved_solutions = filter(x -> x[3] == "LOCALLY_SOLVED", results)
        min_solution = solved_solutions[argmin(x[1] for x in solved_solutions)]
        # If cheapest found value is better than our current,
        # set update variables and reset loop with new variables
        if min_solution[1] < new_obj_value
            new_obj_value = min_solution[1]
            new_pg = min_solution[2]
            fix.(power_flow_model.model[:pg], new_pg; force=true)
            iterations = 0
            optimize!(power_flow_model.model)
        end
        # Calculate difference in solutions, if incremental, terminates loop
        diff_of_solutions = abs(new_obj_value - current_obj_value)
        iterations += 1
    end
    # Return the cheapest value with its corresponding pg variables
    return new_obj_value, new_pg
end

function single_variable_solve(power_flow_model, epsilon, i, j)
    # Store current values before modifying the model
    current_pg = power_flow_model.model[:pg]
    changed_pg = value(current_pg[i, j]) + epsilon
    must_unfix = false
    
    # Save current upper and lower bounds of the variable
    upper = power_flow_model.data["gen"][string(j)]["pmax"]
    lower = power_flow_model.data["gen"][string(j)]["pmin"]
    
    # Fix variable to the modified value
    if changed_pg >= lower - 1 && changed_pg <= upper
        fix(current_pg[i, j], changed_pg; force = true)
        must_unfix = true
    end

    # Optimize the model
    optimize!(power_flow_model.model)

    status = termination_status(power_flow_model.model)
    status = string(status)
    obj_value = objective_value(power_flow_model.model)
    new_pg = value.(current_pg)

    # Unfix the variable and restore the upper and lower bounds
    if must_unfix == true
        unfix(current_pg[i,j])
        set_upper_bound(current_pg[i,j], upper)
        set_lower_bound(current_pg[i,j], lower)
    end
    return obj_value, new_pg, status
end

function two_variable_search(power_flow_model, T, num_of_gens, epsilon)
    current_pg = value.(power_flow_model.model[:pg])
    current_obj_value = objective_value(power_flow_model.model)
    new_pg = current_pg
    new_obj_value = current_obj_value
    iterations = 0
    diff_of_solutions = Inf

    while iterations < 5 && diff_of_solutions > 0.01
        results = []
        for i in 1:T
            for j in 1:num_of_gens - 1
                temp = two_variable_solve(power_flow_model, epsilon, i, j)
                push!(results, temp)
                optimize!(power_flow_model.model)
                if temp[1] < new_obj_value
                    new_obj_value = temp[1]
                    new_pg = temp[2]
                    fix.(power_flow_model.model[:pg], temp[2], force=true)
                    optimize!(power_flow_model.model)
                end
            end
        end
    
        # Filter solved models for cheapest objective value
        solved_solutions = filter(x -> x[3] == "LOCALLY_SOLVED", results)
        min_solution = solved_solutions[argmin(x[1] for x in solved_solutions)]
        # If cheapest found value is better than our current,
        # set update variables and reset loop with new variables
        if min_solution[1] < new_obj_value
            new_obj_value = min_solution[1]
            new_pg = min_solution[2]
            fix.(power_flow_model.model[:pg], new_pg; force=true)
            iterations = 0
            optimize!(power_flow_model.model)
        end
        # Calculate difference in solutions, if incremental, terminates loop
        diff_of_solutions = abs(new_obj_value - current_obj_value)
        iterations += 1
    end
    # Return the cheapest value with its corresponding pg variables
    return new_obj_value, new_pg
end

function two_variable_solve(power_flow_model, epsilon, i, j)
    current_pg = power_flow_model.model[:pg]
    changed_pg1 = value(current_pg[i,j]) + epsilon
    changed_pg2 = value(current_pg[i,j+1]) + epsilon
    must_unfix = false

    upper1 = power_flow_model.data["gen"][string(j)]["pmax"]
    lower1 = power_flow_model.data["gen"][string(j)]["pmin"]
    upper2 = power_flow_model.data["gen"][string(j + 1)]["pmax"]
    lower2 = power_flow_model.data["gen"][string(j + 1)]["pmin"]
    
    if (changed_pg1 >= lower1 && changed_pg1 <= upper1) &&
       (changed_pg2 >= lower2 && changed_pg2 <= upper2)
        fix(current_pg[i,j], changed_pg1; force = true)
        fix(current_pg[i, j+1], changed_pg2; force = true)
        must_unfix = true
    end

    optimize!(power_flow_model.model)

    status = termination_status(power_flow_model.model)
    status = string(status)
    obj_value = objective_value(power_flow_model.model)
    new_pg = value.(current_pg)

    if must_unfix == true
        unfix(current_pg[i,j])
        unfix(current_pg[i, j+1])
        set_upper_bound(current_pg[i,j], upper1)
        set_lower_bound(current_pg[i,j], lower1)
        set_upper_bound(current_pg[i, j+1], upper2)
        set_lower_bound(current_pg[i, j+1], lower2)
    end

    return obj_value, new_pg, status
end



# Putting here in case reformat doesnt work

#=
function single_variable_search(power_flow_model, T, num_of_gens, epsilon)
    optimal_value = objective_value(power_flow_model.model)
    initial_value = optimal_value
    current_pg_values = power_flow_model.model[:pg]
    optimal_pg = value.(power_flow_model.model[:pg])
    iterations = 0
    diff_of_solutions = Inf
    
    while iterations < 5 && diff_of_solutions > 0.01
        results = []
        for t in 1:T
            for g in 1:num_of_gens
                for i in 1:2
                    temp = single_variable_solve(power_flow_model, current_pg_values, epsilon, t, g)
                    push!(results, temp)
                    # Re-optimize model to avoid querying results on modified model
                    optimize!(power_flow_model.model)
                    epsilon *= -1
                end
            end
        end

        solved_solutions = filter(x -> x[3] == "LOCALLY_SOLVED", results)
        min_solution = solved_solutions[argmin(x[1] for x in solved_solutions)]
        if min_solution[1] < optimal_value
            optimal_value = min_solution[1]
            fix.(current_pg_values, min_solution[4], force=true)
            optimal_pg = min_solution[4]
            iterations = 0
            optimize!(power_flow_model.model)
        end
        diff_of_solutions = abs(optimal_value - initial_value)
        iterations += 1

    end
    return optimal_value, optimal_pg
end

function single_variable_solve(power_flow_model, pg, epsilon, i, j)
    # Store current values before modifying the model
    current_pg_values = value.(pg)
    changed_pg = current_pg_values[i, j] + epsilon
    must_unfix = false
    
    # Save current upper and lower bounds of the variable
    upper = power_flow_model.data["gen"][string(j)]["pmax"]
    lower = power_flow_model.data["gen"][string(j)]["pmin"]
    
    # Fix variable to the modified value
    if changed_pg >= lower && changed_pg <= upper
        fix(pg[i, j], changed_pg; force = true)
        must_unfix = true
    end

    # Optimize the model
    optimize!(power_flow_model.model)

    # Store the results of the model
    status = termination_status(power_flow_model.model)
    status = string(status)
    obj_value = objective_value(power_flow_model.model)

    # Get the updated pg values
    updated_pg_refs = pg
    values_of_pg = value.(updated_pg_refs)

    # Unfix the variable and restore the upper and lower bounds
    if must_unfix == true
        unfix(pg[i,j])
        set_upper_bound(pg[i,j], upper)
        set_lower_bound(pg[i,j], lower)
    end
    return obj_value, updated_pg_refs, status, values_of_pg
end
=#