function compute_and_save_feasibility(factory::Union{ACMPOPFModelFactory, DCMPOPFModelFactory, LinMPOPFModelFactory}, path::String, model_type=false)

	# start the time
	start_time = time()

	factory_type = "error"

	if factory isa ACMPOPFModelFactory
		factory_type = "AC"

	elseif factory isa DCMPOPFModelFactory
		factory_type = "DC"

	elseif factory isa LinMPOPFModelFactory
		if model_type == Lin1
			factory_type = "Linear"

		elseif model_type == Lin2
			factory_type = "Quadratic"

		elseif model_type == Lin3
			factory_type = "Logarithmic"
		end
	end

    # Create directory structure
    case_name = replace(basename(path), ".m" => "")
    base_dir = "results"
    case_dir = joinpath(base_dir, case_name)
    factory_dir = joinpath(case_dir, factory_type)
    mkpath(factory_dir)

	# initiate the data
	costs = Dict()
	v_error = Dict()
	o_error = Dict()
	times = Dict()

	# initiate and optimize the model
	model_type !== false ? model = create_model(factory; model_type=model_type) : model = create_model(factory)

	optimize_model(model)

	termination_status = JuMP.termination_status(model.model)
	statusString = string(termination_status)
	if statusString != "LOCALLY_SOLVED"
		file = joinpath(factory_dir, "status.jls")
		open(file, "w") do io
			serialize(io, termination_status)
		end
	end

	# Serialize the optimized model
	model_file = joinpath(factory_dir, "optimized_model.jls")
	open(model_file, "w") do io
		serialize(io, model)
	end

	# get the length of the buses
	ref = get_ref(model.data)
	bus_len = length(ref[:bus])

	# extract the pg and qg values
	pg = value.(model.model[:pg])
	qg = factory isa DCMPOPFModelFactory ? 0 : value.(model.model[:qg])

	# create ac model with fixed pg and qg values
	ac_factory = NewACMPOPFModelFactory(path, Ipopt.Optimizer)
	ac_model = create_model_check_feasibility(ac_factory, pg, qg)
	optimize_model(ac_model)

	termination_status_AC = JuMP.termination_status(ac_model.model)
	statusString_AC = string(termination_status_AC)
	if statusString_AC != "LOCALLY_SOLVED"
		file = joinpath(factory_dir, "status_AC.jls")
		open(file, "w") do io
			serialize(io, termination_status_AC)
		end
	end

	# get va values from the model ( it is horrible as bus indices are not always linearly increasing )
	val1 = value.(getindex.((pairs(cat(model.model[:va], dims=1)) |> collect)[1:length(model.model[:va])], 2))
	val2 = value.(getindex.((pairs(cat(ac_model.model[:va], dims=1)) |> collect)[1:length(ac_model.model[:va])], 2))
	new_o_error = abs(sum((val1 - val2) / val2) / bus_len) 

	# get vm values from the model, dc models do not have vm values, so default to 1
	val3 = factory isa DCMPOPFModelFactory ? 0 : value.(getindex.((pairs(cat(model.model[:vm], dims=1)) |> collect)[1:length(model.model[:va])], 2))
	val4 = factory isa DCMPOPFModelFactory ? 0 : value.(getindex.((pairs(cat(ac_model.model[:vm], dims=1)) |> collect)[1:length(ac_model.model[:va])], 2))
	new_v_error = factory isa DCMPOPFModelFactory ? 1 : abs(sum((val3 - val4) / val4) / bus_len)

	# calculate sum of x over sum of pg from inital model to show feasibility
	sum_x = sum(value.(ac_model.model[:x]))
	sum_pg = sum(pg)
	sum_total = sum_x / sum_pg

	# multiply value with cost
	cost_Lin = objective_value(ac_model.model)
	total_cost = sum_total * cost_Lin

	# push the calculate values
	costs[path] = total_cost
	v_error[path] = new_v_error
	o_error[path] = new_o_error
	times[path] = time() - start_time

	# output the v values from the optimized model
	vm = ac_model.model[:vm]
	for (i, branch) in ref[:branch]
		vm_fr = vm[1,branch["f_bus"]]
		vm_to = vm[1,branch["t_bus"]]

		for (vi, vj) in zip(values.(vm_fr), values.(vm_to))
			println(value(vi), " -> ", value(vj))
			output_to_file("$(path) -> $(log(value(vi)) - log(value(vj)))", "v_values/vm_diff.txt")
		end
	end

    # Create a dictionary with all the results
    results = Dict(
        "costs" => costs,
        "v_error" => v_error,
        "o_error" => o_error,
        "times" => times
    )

    # Serialize the results
    output_file = joinpath(factory_dir, "results.jls")
    open(output_file, "w") do io
        serialize(io, results)
    end

    return results
end


function load_and_graph_results(results_directory::String, save_to_file::Bool=false)
    # Define model types and their corresponding colors
    model_types = ["AC", "DC", "Linear", "Logarithmic", "Quadratic"]
    style_indexes = [1, 2, 3, 4, 5]

    # Initialize graphs
    feasibility_graph = Graph("Feasibility_Graphs/feasibility.pdf")
    v_error_graph = Graph("Feasibility_Graphs/v_error.pdf")
    o_error_graph = Graph("Feasibility_Graphs/o_error.pdf")
    time_graph = Graph("Feasibility_Graphs/computation_time.pdf")

    # Get all case directories
    case_dirs = sort(filter(isdir, readdir(results_directory, join=true)))
    
    # Create a list to store case information and results
    case_data = []

    for case_dir in case_dirs
        case_name = basename(case_dir)
		bus_count = nothing
        case_results = Dict()

        for model in model_types
            results_file = joinpath(case_dir, model, "results.jls")
            if isfile(results_file)
                data = open(deserialize, results_file)
                case_results[model] = data

                # Get bus count from the first available model
                if isnothing(bus_count)
                    optimized_model_file = joinpath(case_dir, model, "optimized_model.jls")
                    if isfile(optimized_model_file)
                        optimized_model = open(deserialize, optimized_model_file)
                        ref = get_ref(optimized_model.data)
                        bus_count = length(ref[:bus])
                    end
                end
            end
        end

        # Only add cases where we have both results and bus count
        if !isempty(case_results) && !isnothing(bus_count)
            push!(case_data, (case_name, bus_count, case_results))
        end
    end

    # Sort case_data based on the number of buses
    sort!(case_data, by = x -> x[2])

    # Extract sorted case names
    case_names = [x[1] for x in case_data]

    for (i, model) in enumerate(model_types)
        costs = Float64[]
        v_errors = Float64[]
        o_errors = Float64[]
        times = Float64[]

        for (_, _, case_results) in case_data
            if haskey(case_results, model)
                data = case_results[model]
                push!(costs, first(values(data["costs"])))
                push!(v_errors, first(values(data["v_error"])))
                push!(o_errors, first(values(data["o_error"])))
                push!(times, first(values(data["times"])))
            else
                push!(costs, NaN)
                push!(v_errors, NaN)
                push!(o_errors, NaN)
                push!(times, NaN)
            end
        end

        # Add data to graphs
        add_scatter(feasibility_graph, case_names, costs, model, style_indexes[i])
        # Only add non-DC models to v_error_graph
		if model != "DC"
			add_scatter(v_error_graph, case_names, v_errors, model, style_indexes[i])
		end
        add_scatter(o_error_graph, case_names, o_errors, model, style_indexes[i])
        add_scatter(time_graph, case_names, times, model, style_indexes[i])
    end

    # Create plots *** Has Titles ***
    # create_plot(feasibility_graph, "Feasibility of Various Models", "Cases (sorted by number of buses)", "Cost Error")
    # create_plot(v_error_graph, "Voltage Magnitude (Vm) Error of Various Models", "Cases (sorted by number of buses)", "Magnitude Error", (0.8025, 0.98))
    # create_plot(o_error_graph, "Voltage Angle (Va) Error of Various Models", "Cases (sorted by number of buses)", "Angle Error")
    # create_plot(time_graph, "Computation Time of Various Models", "Cases (sorted by number of buses)", "Time (s)")

    # Create plots *** No Titles ***
    create_plot(feasibility_graph, "", "Cases (sorted by number of buses)", "Cost Error")
    create_plot(v_error_graph, "", "Cases (sorted by number of buses)", "Magnitude Error", (0.8025, 0.98))
    create_plot(o_error_graph, "", "Cases (sorted by number of buses)", "Angle Error")
    create_plot(time_graph, "", "Cases (sorted by number of buses)", "Time (s)")


    # Save graphs if save_to_file is true
    if save_to_file
        save_graph(feasibility_graph)
        save_graph(v_error_graph)
        save_graph(o_error_graph)
        save_graph(time_graph)
    end

    return feasibility_graph, v_error_graph, o_error_graph, time_graph
end

function load_and_compile_results(results_directory::String, save_to_file::Bool=false)
    # Define model types and their corresponding colors
    model_types = ["AC", "DC", "Linear", "Logarithmic", "Quadratic"]

    # Get all case directories
    case_dirs = sort(filter(isdir, readdir(results_directory, join=true)))
    
    # Create a list to store case information and results
    case_data = []

    for case_dir in case_dirs
        case_name = basename(case_dir)
		bus_count = nothing
        case_results = Dict()

        for model in model_types
            results_file = joinpath(case_dir, model, "results.jls")
            if isfile(results_file)
                data = open(deserialize, results_file)
                case_results[model] = data

                # Get bus count from the first available model
                if isnothing(bus_count)
                    optimized_model_file = joinpath(case_dir, model, "optimized_model.jls")
                    if isfile(optimized_model_file)
                        optimized_model = open(deserialize, optimized_model_file)
                        ref = get_ref(optimized_model.data)
                        bus_count = length(ref[:bus])
                    end
                end
            end
        end

        # Only add cases where we have both results and bus count
        if !isempty(case_results) && !isnothing(bus_count)
            push!(case_data, (case_name, bus_count, case_results))
        end
    end

    # Initialize nested dictionary to store results for each model and case
    model_results = Dict{String, Dict{String, Dict{String, Float64}}}()
    for model in model_types
        model_results[model] = Dict(
            "costs" => Dict{String, Float64}(),
            "v_errors" => Dict{String, Float64}(),
            "o_errors" => Dict{String, Float64}(),
            "times" => Dict{String, Float64}()
        )
    end

    # Collect results for each model and case
    for (case_name, _, case_results) in case_data
        for model in model_types
            if haskey(case_results, model)
                data = case_results[model]
                model_results[model]["costs"][case_name] = first(values(data["costs"]))
                model_results[model]["v_errors"][case_name] = first(values(data["v_error"]))
                model_results[model]["o_errors"][case_name] = first(values(data["o_error"]))
                model_results[model]["times"][case_name] = first(values(data["times"]))
            else
                model_results[model]["costs"][case_name] = NaN
                model_results[model]["v_errors"][case_name] = NaN
                model_results[model]["o_errors"][case_name] = NaN
                model_results[model]["times"][case_name] = NaN
            end
        end
    end

    # TODO: Add code here to save graphs if save_to_file is true

    return model_results
end

function calculate_model_averages(model_results::Dict{String, Dict{String, Dict{String, Float64}}})
    # Initialize a dictionary to store the averages for each model
    model_averages = Dict{String, Dict{String, Float64}}()

    # List of metrics we're interested in
    metrics = ["costs", "v_errors", "o_errors", "times"]

    # Calculate averages for each model and metric
    for (model, results) in model_results
        model_averages[model] = Dict{String, Float64}()
        
        for metric in metrics
            # Filter out NaN values before calculating the mean
            valid_values = filter(!isnan, collect(values(results[metric])))
            
            if !isempty(valid_values)
                model_averages[model][metric] = mean(valid_values)
            else
                model_averages[model][metric] = NaN
            end
        end
    end

    return model_averages
end

function find_infeasible_constraints(model::Model)
    if termination_status(model) != MOI.LOCALLY_INFEASIBLE
        error("The model must be optimized and locally infeasible")
    end

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

    for (con, val) in infeasible_constraints
        println("")
        println("Infeasible constraint: ", con)
        println("Current value: ", val)
        println("")
    end
end