function single_variable_search(power_flow_model, pg, T, num_of_gens, epsilon)
    global results = []
    for g in 1:5
        temp = single_variable_solve(My_DC_model, My_DC_model.model[:pg], epsilon, 1, g)
        push!(results, temp)
        optimize!(My_DC_model.model)
    end
    return results
end

function single_variable_solve(power_flow_model::Main.MPOPF.PowerFlowModel, pg, epsilon, i, j)
    # Store current values before modifying the model
    current_pg_values = value.(pg)

    # Update the constraints
    changed_pg = current_pg_values[i, j] + epsilon
    constraint1 = @constraint(power_flow_model.model, pg[i, j] >= changed_pg)
    constraint2 = @constraint(power_flow_model.model, pg[i, j] <= changed_pg)

    # Optimize the model
    optimize!(power_flow_model.model)

    status = termination_status(power_flow_model.model)
    status = string(status)
    obj_value = objective_value(power_flow_model.model)

    # Get the updated pg values
    updated_pg_values = value.(pg)

    # Remove the constraints
    delete(power_flow_model.model, constraint1)
    delete(power_flow_model.model, constraint2)

    return obj_value, updated_pg_values, status
end
