using Graphs, MetaGraphs

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

function generate_random_loads(largest_model; scenarios_to_generate = 30, variation_percent = 1)
    # Used to check that conversion to Dict did not upset order
    #pg_values = value.(largest_model.model[:pg])

    # Extract largest values
    if termination_status(largest_model.model) == MOI.INFEASIBLE
        error("Largest model is infeasible. Cannot generate random loads.")
    end
    
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
            if variation < 0
                variation = 0
            end
            if rand() <= pos_or_neg
                random_dict[gen_num] = gen_output + variation
            else
                random_dict[gen_num] = gen_output - variation
            end
        end

        if sum(values(random_dict)) < sum_of_largest
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

function extract_power_flow_data(model)
    
    m = value.(model.model[:pg])
    values = [value(m[key]) for key in keys(m)]
    return Dict(zip(m.axes[2], values'))
end

function test_scenarios(factory, demand, ramping_data, random_scenarios)
    feasible_scenarios = []
    for scenario in random_scenarios
        model = power_flow(factory, demand, ramping_data, scenario)
        status = termination_status(model.model)

        if status == MOI.LOCALLY_INFEASIBLE || status == MOI.INFEASIBLE || status != MOI.LOCALLY_SOLVED
            println("Skipping infeasible scenario")
            continue  # Skip extracting values from an infeasible model
        end

        values = extract_power_flow_data(model)
        push!(feasible_scenarios, values)
    end
    return feasible_scenarios
end

function build_initial_graph(scenarios::Vector{Any}, time_periods)
    # Create a directed graph
    g = MetaDiGraph()
    defaultweight!(g, 1.0)
        
    # Create nodes for each scenario
    for p in 1:time_periods
        for (t, scenario) in enumerate(scenarios)
            # Add node to graph
            add_vertex!(g)
            current_node = nv(g)
            
            # Store node metadata
            set_prop!(g, current_node, :time_period, p) # time period
            set_prop!(g, current_node, :generator_values, scenario) # generator values
            set_prop!(g, current_node, :total_generation, sum(values(scenario))) # sum of values
        end
    end

    # add first and last node
    add_vertex!(g)
    first_node = nv(g)
    set_prop!(g, first_node, :time_period, 0)
    set_prop!(g, first_node, :generator_values, 0)
    set_prop!(g, first_node, :total_generation, 0)
    add_vertex!(g)
    last_node = nv(g)
    set_prop!(g, last_node, :time_period, time_periods + 1)
    set_prop!(g, last_node, :generator_values, 0)
    set_prop!(g, last_node, :total_generation, 0)

    first_nodes = collect(filter_vertices(g, :time_period, 1))
    for n in first_nodes
        add_edge!(g, first_node, n)
        edge = Edge(first_node, n)
        set_prop!(g, edge, :weight, 0)
    end

    last_nodes = collect(filter_vertices(g, :time_period, time_periods))
    for n in last_nodes
        add_edge!(g, n, last_node)
        edge = Edge(n, last_node)
        set_prop!(g, edge, :weight, 0)
    end

    return g
end

function add_edges_to_initial_graph(graph, time_periods, ramping_data)

    ramp_limits = ramping_data["ramp_limits"]
    ramp_costs = ramping_data["costs"]
    for n in 1:(time_periods - 1)
        nodes_n = collect(filter_vertices(graph, :time_period, n))
        nodes_n1 = collect(filter_vertices(graph, :time_period, n + 1))

        for node_n in nodes_n
            for node_n1 in nodes_n1
               add_edge!(graph, node_n, node_n1) 
            end
        end
    end
end

function add_weighted_edges(graph, time_periods, ramping_data)
    ramp_costs = ramping_data["costs"]
    ramp_limits = ramping_data["ramp_limits"]
    for n in 1:(time_periods - 1)
        nodes_n = collect(filter_vertices(graph, :time_period, n))
        nodes_n1 = collect(filter_vertices(graph, :time_period, n + 1))

        for node_n in nodes_n
            gen_values_n = get_prop(graph, node_n, :generator_values)
            for node_n1 in nodes_n1
                gen_values_n1 = get_prop(graph, node_n1, :generator_values)
                total_edge_cost = 0
                violates = false
                for gen_id in keys(gen_values_n)
                    difference = abs(gen_values_n[gen_id] - gen_values_n1[gen_id])
                    if difference <= ramp_limits[gen_id]
                        total_edge_cost += difference * ramp_costs[gen_id]
                    else
                        violates = true
                        break
                    end
                end
                if !violates
                    add_edge!(graph, node_n, node_n1)
                    edge = Edge(node_n, node_n1)  # Create an edge reference
                    set_prop!(graph, edge, :weight, total_edge_cost)

                end
            end
        end
    end
end

function shortest_path(graph)
    # Find the source node (time period 0)
    source_node = first(filter_vertices(graph, :time_period, 0))
    
    # Find the sink node (time period n+1)
    sink_node = first(filter_vertices(graph, :time_period, maximum(get_prop(graph, v, :time_period) for v in vertices(graph))))
    
    # Run Dijkstra's algorithm using MetaGraphs weights
    state = Graphs.dijkstra_shortest_paths(graph, source_node, MetaGraphs.weights(graph))
    
    # Reconstruct the path from source to sink
    full_path = Int[]
    current = sink_node
    
    # Start from the sink and work backward to the source
    while current != source_node
        push!(full_path, current)
        current = state.parents[current]
    end
    push!(full_path, source_node)
    
    # Reverse to get path from source to sink
    reverse!(full_path)
    
    # Calculate the total cost manually
    total_cost = 0.0
    for i in 1:(length(full_path)-1)
        src_node = full_path[i]
        dst_node = full_path[i+1]
        if has_edge(graph, src_node, dst_node)
            total_cost += get_prop(graph, src_node, dst_node, :weight)
        end
    end
    
    return full_path, total_cost
end

function search(factory, demands, ramping_data, time_periods)

    highest_demand = find_largest_time_period(time_periods, demands)
    largest_model = build_and_optimize_largest_period(factory, demands[highest_demand], ramping_data)

    loads = generate_random_loads(largest_model)

    scenarios = test_scenarios(factory, demands[highest_demand], ramping_data, loads)

    g = build_initial_graph(scenarios, time_periods)
    add_weighted_edges(g, time_periods, ramping_data)

    full_path, total_cost = shortest_path(g)

    return g, scenarios, full_path, total_cost
end
