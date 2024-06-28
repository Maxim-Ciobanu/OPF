function single_variable_search(power_flow_model, T, num_of_gens, epsilon)
    optimal_value = objective_value(power_flow_model.model) + 1
    current_pg_values = power_flow_model.model[:pg]
    optimal_pg = value.(power_flow_model.model[:pg])
    iterations = 0
    
    while iterations < 1
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
            current_pg_values = min_solution[2]
            optimal_pg = min_solution[4]
            iterations = 0
        end
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
    updated_pg_values = pg
    values_of_pg = value.(updated_pg_values)

    # Print statements to confirm results if needed
    println(obj_value, " ###############################")
    println(value.(updated_pg_values), "##############")
    println(status, "#####################")

    # Unfix the variable and restore the upper and lower bounds
    if must_unfix == true
        unfix(pg[i,j])
        set_upper_bound(pg[i,j], upper)
        set_lower_bound(pg[i,j], lower)
    end
    return obj_value, updated_pg_values, status, values_of_pg
end
