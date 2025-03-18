using Graphs, MetaGraphs

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

    for t in 1:scenarios_to_generate
        random_dict = Dict()
        pos_or_neg = rand([0.35, 0.5, 0.65]) # randomly select, < will decrease, > will increase
        for (gen_num, gen_output) in pg_values
            max_variation = gen_output * (variation_percent/100)
            variation = rand() * max_variation
            if rand() >= pos_or_neg
                random_dict[gen_num] = gen_output + variation
            else
                random_dict[gen_num] = gen_output - variation
            end
        end

        random_scenarios[t] = random_dict

        variation_percent += 1
    end
    return random_scenarios
end

function generate_new_loads(current_outputs; scenarios_to_generate = 30, variation_percent = 1)

    random_scenarios = Vector{Dict{Int64, Float64}}(undef, scenarios_to_generate)
    for i in 1:scenarios_to_generate
        random_dict = Dict()
        pos_or_neg = rand([0.35, 0.5, 0.65])
        for (gen, val) in current_outputs
            max_variation = gen_output * (variation_percent/100)
            variation = rand() * max_variation
            if rand() >= pos_or_neg
                random_dict[gen] = val + variation
            else
                random_dict[gen] = val - variation
            end
        end
        random_scenarios[i] = random_dict
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
        push!(feasible_scenarios, (values, objective_value(model.model)))
    end
    return feasible_scenarios
end

function build_initial_graph(scenarios::Vector{Any}, time_periods)
    graph = MetaDiGraph()
    defaultweight!(graph, 1.0)
    
    # add first node
    add_vertex!(graph)
    first_node = nv(graph)
    set_prop!(graph, first_node, :time_period, 0)
    set_prop!(graph, first_node, :generator_values, 0)
    set_prop!(graph, first_node, :cost, 0)

    for p in 1:time_periods
        for (t, scenario) in enumerate(scenarios)
            add_vertex!(graph)
            current_node = nv(graph)
            
            set_prop!(graph, current_node, :time_period, p) # time period
            set_prop!(graph, current_node, :generator_values, scenario[1]) # generator values
            set_prop!(graph, current_node, :cost, scenario[2]) # sum of values
        end
    end

    # add last node and corresponding edges
    add_vertex!(graph)
    last_node = nv(graph)
    set_prop!(graph, last_node, :time_period, time_periods + 1)
    set_prop!(graph, last_node, :generator_values, 0)
    set_prop!(graph, last_node, :cost, 0)

    first_nodes = collect(filter_vertices(graph, :time_period, 1))
    for n in first_nodes
        add_edge!(graph, first_node, n)
        edge = Edge(first_node, n)
        set_prop!(graph, edge, :weight, 0)
    end

    last_nodes = collect(filter_vertices(graph, :time_period, time_periods))
    for n in last_nodes
        add_edge!(graph, n, last_node)
        edge = Edge(n, last_node)
        set_prop!(graph, edge, :weight, 0)
    end

    return graph
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
                    edge = Edge(node_n, node_n1)
                    set_prop!(graph, edge, :weight, total_edge_cost)
                end
            end
        end
    end
end

function shortest_path(graph)
    # find the source node (time period 0)
    source_node = first(filter_vertices(graph, :time_period, 0))
    
    # find the sink node (time period n+1)
    sink_node = first(filter_vertices(graph, :time_period, maximum(get_prop(graph, v, :time_period) for v in vertices(graph))))
    
    # run Dijkstra's algorithm using MetaGraphs weights
    state = Graphs.dijkstra_shortest_paths(graph, source_node, MetaGraphs.weights(graph))
    
    # reconstruct path
    full_path = Int[]
    current = sink_node
    
    # start from sink  and work backward to source
    while current != source_node
        push!(full_path, current)
        current = state.parents[current]
    end
    push!(full_path, source_node)
    
    # reverse path
    reverse!(full_path)
    
    # calculate cost
    total_cost = 0.0
    for i in 1:(length(full_path)-1)
        src_node = full_path[i]
        dst_node = full_path[i+1]
        if has_edge(graph, src_node, dst_node)
            total_cost += get_prop(graph, src_node, dst_node, :weight) + get_prop(graph, src_node, :cost)
        end
    end
    
    return full_path, total_cost
end

function extract_solution(graph, path)
    solution = Dict{Int, Dict{Symbol, Any}}()  # Dictionary to store node properties

    for node in path
        time_period = get_prop(graph, node, :time_period)
        solution[time_period] = Dict(
            :generator_values => get_prop(graph, node, :generator_values),
            :cost => get_prop(graph, node, :cost)
        )
    end

    return solution
end


function iter_search(factory, demands, ramping_data, time_periods)

    highest_demand = find_largest_time_period(time_periods, demands)
    largest_model = build_and_optimize_largest_period(factory, demands[highest_demand], ramping_data)

    loads = generate_random_loads(largest_model)

    scenarios = test_scenarios(factory, demands[highest_demand], ramping_data, loads)

    graph = build_initial_graph(scenarios, time_periods)
    add_weighted_edges(graph, time_periods, ramping_data)

    path, cost = shortest_path(graph)

    best_graph = graph
    best_path = path[2:end - 1]
    best_cost = cost
    solution = extract_solution(graph, best_path)

    cost_history = [best_cost]

    generator_values_dict = Dict()
    for (time_period, data) in solution
        generator_values_dict[time_period] = data[:generator_values]
    end

    for (t, vals) in generator_values_dict
        generate_new_loads(vals)
    end


    return graph, scenarios, best_path, best_cost, solution

end

function iterative_search(factory, demands, ramping_data, time_periods; max_iterations=5, convergence_threshold=0.01)
    # First iteration using the existing search function
    g, scenarios, path, total_cost = search(factory, demands, ramping_data, time_periods)
    
    println("Iteration 1: Total Cost = $total_cost")
    
    # Store the best solution so far
    best_path = path
    best_cost = total_cost
    best_g = g
    
    # Store history for analysis
    cost_history = [total_cost]
    path_history = [path]
    
    # Remove first and last nodes (virtual source/sink)
    actual_path = path[2:end-1]
    
    # Iterative refinement
    for iter in 2:max_iterations
        # Extract generator values from the current best path to use as centers for new scenarios
        path_generator_values = []
        for node in actual_path
            if node == 0 || get_prop(best_g, node, :time_period) == time_periods + 1
                continue  # Skip source/sink nodes
            end
            push!(path_generator_values, get_prop(best_g, node, :generator_values))
        end
        
        # Generate new scenarios focused around the current best solution
        # with decreasing variation as iterations progress
        variation_percent = max(10.0 / iter, 1.0)  # Decrease variation over iterations
        
        new_scenarios = []
        
        # For each time period, generate new scenarios
        for t in 1:time_periods
            # If we have a valid generator value for this time period in our path
            if t <= length(path_generator_values)
                base_values = path_generator_values[t]
                
                # Generate random variations around this point
                scenarios_per_period = max(10, 30 ÷ iter)  # Fewer scenarios in later iterations
                
                for s in 1:scenarios_per_period
                    random_dict = Dict{Int64, Float64}()
                    for (gen_id, gen_output) in base_values
                        # Calculate how much variation we want (decreasing with iterations)
                        max_variation = gen_output * (variation_percent/100)
                        variation = (rand() * 2 - 1) * max_variation  # Between -max_var and +max_var
                        random_dict[gen_id] = max(0.0, gen_output + variation)
                    end
                    
                    # Test if this scenario is feasible
                    model = power_flow(factory, demands[t], ramping_data, random_dict)
                    status = termination_status(model.model)
                    
                    if status == MOI.LOCALLY_SOLVED || status == MOI.OPTIMAL
                        values = extract_power_flow_data(model)
                        push!(new_scenarios, (values, objective_value(model.model)))
                    end
                end
            end
        end
        
        # Build a new graph with the refined scenarios
        new_g = build_initial_graph(new_scenarios, time_periods)
        add_weighted_edges(new_g, time_periods, ramping_data)
        
        # Find shortest path in the new graph
        new_path, new_cost = shortest_path(new_g)
        
        println("Iteration $iter: Total Cost = $new_cost")
        push!(cost_history, new_cost)
        push!(path_history, new_path)
        
        # Check if we've improved
        if new_cost < best_cost
            improvement = (best_cost - new_cost) / best_cost
            println("Improvement: $(improvement * 100)%")
            
            # Update best solution
            best_path = new_path
            best_cost = new_cost
            best_g = new_g
            
            # Check for convergence
            if improvement < convergence_threshold
                println("Converged after $iter iterations (improvement below threshold)")
                break
            end
        else
            println("No improvement in this iteration")
        end
    end
    
    return best_g, path_history, best_path, best_cost, cost_history
end

function find_infeasible_constraints(model::Model)
    #if termination_status(model) != MOI.LOCALLY_INFEASIBLE
     #   println("The model must be optimized and locally infeasible")
	#	return []
    #end

    infeasible_constraints = []
    
    for (f, s) in list_of_constraint_types(model)
        for con in all_constraints(model, f, s)
            func = constraint_object(con).func
            set = constraint_object(con).set
            constraint_value = JuMP.value(func)
            
            is_satisfied = false
            if set isa MOI.EqualTo
                is_satisfied = isapprox(constraint_value, MOI.constant(set), atol=1e-6)
            elseif set isa MOI.LessThan
                is_satisfied = constraint_value <= MOI.constant(set) + 1e-6
            elseif set isa MOI.GreaterThan
                is_satisfied = constraint_value >= MOI.constant(set) - 1e-6
            elseif set isa MOI.Interval
                is_satisfied = MOI.lower(set) - 1e-6 <= constraint_value <= MOI.upper(set) + 1e-6
            else
                @warn "Unsupported constraint type: $set"
                continue
            end
            
            if !is_satisfied
                push!(infeasible_constraints, (con, constraint_value))
            end
        end
    end

    return infeasible_constraints
end

function find_bound_violations(model::Model)

	# if termination_status(model) != MOI.LOCALLY_INFEASIBLE
    #     error("The model must be optimized and locally infeasible")
    # end

	# Get the variable names
	variable_names = all_variables(model)

	violations = Dict{VariableRef, Tuple{Float64, Float64, Float64, Float64}}()

	# iterate over all variables
	for (_, var) in enumerate(variable_names)

		# check if the variable has a lower and upper bound
		if !has_lower_bound(var) || !has_upper_bound(var)
			continue
		end

		# get the bounds and value of the variable
		upper = upper_bound(var)
		lower = lower_bound(var)
		value = JuMP.value(var)

		# check for violation
		if value < lower 
			
			# add it to the violations dictionary
			violations[var] = (value, lower, upper, lower - value)
		elseif value > upper

			# add it to the violations dictionary
			violations[var] = (value, lower, upper, value - upper)
		end
	end
    	# return the violations
	return violations
end