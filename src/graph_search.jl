"""
    find_largest_time_period(time_periods::Int64, demands::Vector{Vector{Float64}})

Find the time period with the greatest overall demand
# Arguments
- `time_periods:Int64`: Number of time periods in the model
- `demands:Vector{Vector{Float64}}`: 2D vector containing demands of each time period
# Returns
- 'largestIndex:int64': Index of the time period with greatest demand
"""

function find_largest_time_period(time_periods, demands)

    largestIndex = -1
    largest = 0

    for d in 1:time_periods
        if sum(demands[d]) > largest
            largest = sum(demands[d])
            largestIndex = d
        end
    end

    return largestIndex
end

"""
    build_and_optimize_largest_period(factory:DCMPOPFSearchFactory, demand:Vector{Float64}, ramping_data:Dict{String, Vector{Float64}})

Find the time period with the greatest overall demand
# Arguments
- `factory:DCMPOPFSearchFactory`: Factory used to create model
- `demand:Vector{Float64}`: Vector containing demands for model
- `ramping_data:Dict{String, Vector{Float64}}`: Ramping data for model (Model is single time period, ramping data not used)
# Returns
- 'model': Created model of largest time period
"""

function build_and_optimize_largest_period(factory, demand, ramping_data)

    model = create_search_model(factory, 1, ramping_data, [demand])
    optimize!(model.model)

    return model
end

# TODO revisit method for biasing values higher or lower
function generate_random_loads(largest_model; scenarios_to_generate = 30, variation_percent = 1)
    # Used to check that conversion to Dict did not upset order
    #pg_values = value.(largest_model.model[:pg])

    # Extract largest values
    largest_values = [value(largest_model.model[:pg][key]) for key in keys(largest_model.model[:pg])]
    sum_of_largest = sum(largest_values)
    # Pair values with corresponding generator number
    pg_values = Dict(zip(largest_model.model[:pg].axes[2], largest_values))

    random_scenarios = Vector{Dict{Int64, Float64}}(undef, scenarios_to_generate)

    pos_or_neg = 0.5
    # Generate scenarios where new load deviates by some percent of original load
    for t in 1:scenarios_to_generate
        random_dict = Dict()
        for (gen_num, gen_output) in pg_values
            # Calculate how much variation we want
            max_variation = gen_output * (variation_percent/100)
            variation = (rand() * 2 - 1) * max_variation

            if rand() <= pos_or_neg
                random_dict[gen_num] = gen_output + variation
            else
                random_dict[gen_num] = gen_output - variation
            end
        end

        if sum(random_dict[2]) < sum_of_largest
            pos_or_neg += 0.05
        else
            pos_or_neg -= 0.05
        end
        random_scenarios[t] = random_dict
        # Increase variation for next iteration to generate a wider range of values
        variation_percent += 1
    end
    return random_scenarios
end

function power_flow(factory, demand, ramping_data, load)

    model = create_search_model(factory, 1, ramping_data, [demand])
    for (gen_id, value) in load
        fix(model.model[:pg][1,gen_id], value, force=true)
    end
    optimize!(model.model)

    return model
end

function build_graph(random_scenarios) 



end

#= TODO: 
build function to iterate over scenarios, push feasible models into vector
implement build_graph() to create acyclic directed graph from feasible models
=#