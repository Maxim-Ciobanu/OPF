function build_search_model(factory, T, ramping_data, demands)
    models = []
    costs = []

    for i in 1:T
        demand_vec = Vector{Vector{Float64}}(undef, 1)
        demand_vec[1] = demands[i]
        model = create_search_model(factory, 1, ramping_data, demand_vec)
        optimize_model(model)
        cost = objective_value(model.model)
        push!(models, model)
        push!(costs, cost)
    end

    base_cost = calculate_cost(models, costs, ramping_data)

    return base_cost
end

function calculate_cost(models, costs, ramping_data)
    sum_of_each_model = sum(costs)
    T = length(models)
    num_of_gens = length(models[1].data["gen"])
    sum_of_ramping = 0

    for i in 1:T-1
        ramping_cost = 0
        for j in 1:num_of_gens
            ramping_cost += abs(value(models[i].model[:pg][1,j]) - value(models[i+1].model[:pg][1,j])) * ramping_data["costs"][j]
        end
        sum_of_ramping += ramping_cost
    end
    return sum_of_each_model + sum_of_ramping
end

function check_slack(factory, T, models, ramping_data, demands, cost)
    slack = 0.1
    

end