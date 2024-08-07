using JuMP, PowerModels, Ipopt, Random

function create_initial_feasible_solution(data, time_periods, demands, ramping_data)
    solution = []
    for t in 1:time_periods
        pg = Dict()
        if t == 1
            # Initialize generators to their midpoints
            for (i, gen) in data["gen"]
                gen_id = parse(Int, i)
                pg[gen_id] = (gen["pmin"] + gen["pmax"]) / 2
            end
        else
            # For subsequent time periods, respect ramping limits and consider costs
            for (i, gen) in data["gen"]
                gen_id = parse(Int, i)
                prev_output = solution[t-1][gen_id]
                ramp_limit = ramping_data["ramp_limits"][gen_id]
                ramp_cost = ramping_data["costs"][gen_id]
                
                # Bias towards smaller changes for high ramping cost generators
                adjustment_scale = 1 / (1 + ramp_cost)
                adjustment = adjustment_scale * rand(-ramp_limit:0.01:ramp_limit)
                pg[gen_id] = max(gen["pmin"], min(gen["pmax"], prev_output + adjustment))
            end
        end
        # Adjust to meet demand
        pg = adjust_to_meet_demand(Dict(t => pg), data, Dict(t => demands[t]), t, ramping_data)[t]
        push!(solution, pg)
    end
    return solution
end

function adjust_to_meet_demand(solution, data, demands, t, ramping_data)
    total_output = sum(values(solution[t]))
    total_demand = sum(demands[t])
    diff = total_demand - total_output
    
    if abs(diff) < 1e-6  # If difference is negligible, consider it met
        return solution
    end
    
    # Sort generators by their cost efficiency (considering both generation and ramping costs)
    sorted_gens = sort(collect(data["gen"]), 
                       by=x->(x[2]["cost"][2] + ramping_data["costs"][parse(Int, x[1])]),
                       rev=(diff < 0))
    
    for (i, gen) in sorted_gens
        gen_id = parse(Int, i)
        ramp_limit = ramping_data["ramp_limits"][gen_id]
        
        if diff > 0
            max_increase = min(gen["pmax"] - solution[t][gen_id], ramp_limit)
            increase = min(diff, max_increase)
            solution[t][gen_id] += increase
            diff -= increase
        else
            max_decrease = min(solution[t][gen_id] - gen["pmin"], ramp_limit)
            decrease = min(-diff, max_decrease)
            solution[t][gen_id] -= decrease
            diff += decrease
        end
        
        if abs(diff) < 1e-6
            break
        end
    end
    
    return solution
end

function apply_ramping_constraints(solution, ramping_data, t)
    if t > 1
        for (gen_id, current_output) in solution[t]
            prev_output = solution[t-1][gen_id]
            ramp_limit = ramping_data["ramp_limits"][gen_id]
            
            if current_output > prev_output
                solution[t][gen_id] = min(current_output, prev_output + ramp_limit)
            else
                solution[t][gen_id] = max(current_output, prev_output - ramp_limit)
            end
        end
    end
    return solution
end

function optimize_solution(solution, data, ramping_data, demands, factory)
    models = []
    time_periods = length(solution)
    for t in 1:time_periods
        model = create_search_model(factory, 1, ramping_data, [demands[t]])
        
        # Add ramping constraints to the model
        if t > 1
            for (i, _) in data["gen"]
                gen_id = parse(Int, i)
                prev_pg = value(models[t-1].model[:pg][1,gen_id])
                ramp_limit = ramping_data["ramp_limits"][gen_id]
                
                @constraint(model.model, model.model[:pg][1,gen_id] <= prev_pg + ramp_limit)
                @constraint(model.model, model.model[:pg][1,gen_id] >= prev_pg - ramp_limit)
            end
        end

        # Set initial values
        for (i, pg) in solution[t]
            set_start_value(model.model[:pg][1,i], pg)
        end

        optimize_model(model)
        
        # Check if the optimization was solved
        if termination_status(model.model) != MOI.OPTIMAL && termination_status(model.model) != MOI.LOCALLY_SOLVED
            println("Warning: Optimization for time period $t failed with status $(termination_status(model.model))")
            return solution, models  # Return the original solution if optimization fails
        end
        
        push!(models, model)
    end
    
    new_solution = [Dict(i => value(model.model[:pg][1,i]) for i in keys(solution[t])) for (t, model) in enumerate(models)]
    
    return new_solution, models
end

function calculate_total_cost(solution, models, ramping_data)
    time_periods = length(solution)
    operation_cost = sum(objective_value(model.model) for model in models)
    ramping_cost = sum(
        ramping_data["costs"][gen_id] * abs(solution[t][gen_id] - solution[t-1][gen_id])
        for t in 2:time_periods
        for gen_id in keys(solution[t])
    )
    return operation_cost + ramping_cost
end

function is_feasible_solution(models)
    return all(termination_status(model.model) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED] for model in models)
end

function decomposed_mpopf_local_search(factory, time_periods, ramping_data, demands; max_iterations=1000, max_time=300, max_escape_attempts=5)
    data = PowerModels.parse_file(factory.file_path)
    PowerModels.standardize_cost_terms!(data, order=2)
    PowerModels.calc_thermal_limits!(data)
    
    solution = create_initial_feasible_solution(data, time_periods, demands, ramping_data)
    best_solution, best_models = optimize_solution(solution, data, ramping_data, demands, factory)
    best_cost = calculate_total_cost(best_solution, best_models, ramping_data)
    base_cost = best_cost

    current_solution = best_solution
    current_cost = best_cost
    current_models = best_models

    start_time = time()
    no_improvement_count = 0
    escape_mode = false
    escape_iterations = 0
    escape_attempts = 0

    for iteration in 1:max_iterations
        if time() - start_time > max_time
            println("Time limit reached. Stopping search.")
            break
        end
        
        # Choose a random time period to adjust
        t = rand(1:time_periods)
        
        # Make a random adjustment
        new_solution = deepcopy(current_solution)
        for (i, gen) in data["gen"]
            gen_id = parse(Int, i)
            ramp_limit = ramping_data["ramp_limits"][gen_id]
            
            if t > 1
                prev_output = new_solution[t-1][gen_id]
                max_down = max(data["gen"]["$gen_id"]["pmin"], prev_output - ramp_limit) - new_solution[t][gen_id]
                max_up = min(data["gen"]["$gen_id"]["pmax"], prev_output + ramp_limit) - new_solution[t][gen_id]
            else
                max_down = data["gen"]["$gen_id"]["pmin"] - new_solution[t][gen_id]
                max_up = data["gen"]["$gen_id"]["pmax"] - new_solution[t][gen_id]
            end
            
            adjustment = rand(max_down:0.01:max_up)
            new_solution[t][gen_id] += adjustment
        end
        
        # Adjust demand for affected time periods
        for i in t:time_periods
            new_solution = adjust_to_meet_demand(new_solution, data, demands, i, ramping_data)
        end
        
        new_solution, new_models = optimize_solution(new_solution, data, ramping_data, demands, factory)
        new_cost = calculate_total_cost(new_solution, new_models, ramping_data)
        
        if new_cost < best_cost && is_feasible_solution(new_models)
            best_solution = new_solution
            best_models = new_models
            best_cost = new_cost
            current_solution = new_solution
            current_cost = new_cost
            current_models = new_models
            no_improvement_count = 0
            escape_mode = false
            escape_iterations = 0
        elseif escape_mode || (new_cost <= current_cost && is_feasible_solution(new_models))
            current_solution = new_solution
            current_cost = new_cost
            current_models = new_models
            if escape_mode
                escape_iterations += 1
                if escape_iterations >= 5
                    escape_mode = false
                    escape_iterations = 0
                    escape_attempts += 1
                end
            end
        else
            no_improvement_count += 1
        end
        
        if no_improvement_count >= 5 && !escape_mode && escape_attempts < max_escape_attempts
            escape_mode = true
            no_improvement_count = 0
        end
        
        if escape_attempts >= max_escape_attempts
            println("Max escape attempts reached. Stopping search.")
            break
        end
    end
    
    return best_solution, best_cost, best_models, base_cost
end

function make_big_step_change(solution, data, ramping_data, demands, t)
    new_solution = deepcopy(solution)
    
    # Choose a random generator to make a big change
    gen_to_change = rand(keys(new_solution[t]))
    
    # Make a big change to this generator
    gen_min = data["gen"]["$gen_to_change"]["pmin"]
    gen_max = data["gen"]["$gen_to_change"]["pmax"]
    new_solution[t][gen_to_change] = gen_min + rand() * (gen_max - gen_min)
    
    # Adjust other generators to meet ramping constraints
    for (i, gen) in data["gen"]
        gen_id = parse(Int, i)
        if gen_id != gen_to_change
            ramp_limit = ramping_data["ramp_limits"][gen_id]
            if t > 1
                min_output = max(gen["pmin"], new_solution[t-1][gen_id] - ramp_limit)
                max_output = min(gen["pmax"], new_solution[t-1][gen_id] + ramp_limit)
                new_solution[t][gen_id] = min_output + rand() * (max_output - min_output)
            end
            if t < length(new_solution)
                min_output = max(gen["pmin"], new_solution[t+1][gen_id] - ramp_limit)
                max_output = min(gen["pmax"], new_solution[t+1][gen_id] + ramp_limit)
                new_solution[t][gen_id] = max(min_output, min(max_output, new_solution[t][gen_id]))
            end
        end
    end
    
    # Adjust to meet demand
    new_solution = adjust_to_meet_demand(new_solution, data, demands, t, ramping_data)
    
    return new_solution
end

function decomposed_mpopf_demand_search(factory, time_periods, ramping_data, demands; max_iterations=1000, max_time=300, max_escape_attempts=5, demand_step=0.01)
    data = PowerModels.parse_file(factory.file_path)
    PowerModels.standardize_cost_terms!(data, order=2)
    PowerModels.calc_thermal_limits!(data)
    
    solution = create_initial_feasible_solution(data, time_periods, demands, ramping_data)
    best_solution, best_models = optimize_solution(solution, data, ramping_data, demands, factory)
    best_cost = calculate_total_cost(best_solution, best_models, ramping_data)
    base_cost = best_cost

    current_solution = best_solution
    current_cost = best_cost
    current_models = best_models
    current_demands = deepcopy(demands)

    start_time = time()
    no_improvement_count = 0
    escape_mode = false
    escape_iterations = 0
    escape_attempts = 0

    # Find the time period with maximum total demand
    max_demand_period = argmax([sum(d) for d in demands])
    max_total_demand = sum(demands[max_demand_period])

    for iteration in 1:max_iterations
        if time() - start_time > max_time
            println("Time limit reached. Stopping search.")
            break
        end
        
        # Choose a random time period to adjust, excluding the max demand period
        available_periods = setdiff(1:time_periods, max_demand_period)
        t = rand(available_periods)
        
        # Slightly increase the demand for the chosen time period
        new_demands = deepcopy(current_demands)
        for (i, load) in enumerate(new_demands[t])
            new_load = min(load + demand_step, demands[max_demand_period][i])
            new_demands[t][i] = new_load
        end
        
        # Ensure we don't exceed the maximum total demand
        if sum(new_demands[t]) > max_total_demand
            scale_factor = max_total_demand / sum(new_demands[t])
            new_demands[t] = new_demands[t] .* scale_factor
        end
        
        # Create a new solution based on the adjusted demand
        new_solution = adjust_to_meet_demand(current_solution, data, new_demands, t, ramping_data)
        new_solution, new_models = optimize_solution(new_solution, data, ramping_data, new_demands, factory)
        new_cost = calculate_total_cost(new_solution, new_models, ramping_data)
        
        if new_cost < best_cost && is_feasible_solution(new_models)
            best_solution = new_solution
            best_models = new_models
            best_cost = new_cost
            current_solution = new_solution
            current_cost = new_cost
            current_models = new_models
            current_demands = new_demands
            no_improvement_count = 0
            escape_mode = false
            escape_iterations = 0
        elseif escape_mode || (new_cost <= current_cost && is_feasible_solution(new_models))
            current_solution = new_solution
            current_cost = new_cost
            current_models = new_models
            current_demands = new_demands
            if escape_mode
                escape_iterations += 1
                if escape_iterations >= 10
                    escape_mode = false
                    escape_iterations = 0
                    escape_attempts += 1
                end
            end
        else
            no_improvement_count += 1
        end
        
        if no_improvement_count >= 10 && !escape_mode && escape_attempts < max_escape_attempts
            escape_mode = true
            no_improvement_count = 0
        end
        
        if escape_attempts >= max_escape_attempts
            println("Max escape attempts reached. Stopping search.")
            break
        end
    end
    
    return best_solution, best_cost, best_models, base_cost, current_demands
end

















########
########
########

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




















#################
# Downward search 
#################

function initialize_max_demand_solution(data, time_periods, demands, ramping_data)
    max_demand_period = argmax([sum(demands[t]) for t in 1:time_periods])
    max_demand = demands[max_demand_period]
    
    # Create a solution for the max demand period
    max_demand_solution = create_initial_feasible_solution(data, 1, [max_demand], ramping_data)[1]
    
    # Replicate this solution for all time periods
    solution = [deepcopy(max_demand_solution) for _ in 1:time_periods]
    
    return solution
end

function downward_search(solution, data, ramping_data, demands, factory; max_iterations=1000, max_time=300)
    best_solution = deepcopy(solution)
    best_models = []
    best_cost = Inf
    
    start_time = time()
    
    for iteration in 1:max_iterations
        if time() - start_time > max_time
            println("Time limit reached. Stopping search.")
            break
        end
        
        new_solution = deepcopy(best_solution)
        
        # Choose a random time period and generator to adjust downward
        t = rand(1:length(new_solution))
        gen = rand(keys(new_solution[t]))
        
        # Calculate the maximum possible downward adjustment
        min_output = max(
            data["gen"]["$gen"]["pmin"],
            t > 1 ? new_solution[t-1][gen] - ramping_data["ramp_limits"][gen] : 0,
            t < length(new_solution) ? new_solution[t+1][gen] - ramping_data["ramp_limits"][gen] : 0
        )
        
        max_adjustment = new_solution[t][gen] - min_output
        
        # Make a random downward adjustment
        adjustment = rand() * max_adjustment
        new_solution[t][gen] -= adjustment
        
        # Adjust to meet demand
        new_solution = adjust_to_meet_demand(new_solution, data, demands, t, ramping_data)
        
        # Optimize and evaluate the new solution
        optimized_solution, models = optimize_solution(new_solution, data, ramping_data, demands, factory)
        new_cost = calculate_total_cost(optimized_solution, models, ramping_data)
        
        if new_cost < best_cost && is_feasible_solution(models)
            best_solution = optimized_solution
            best_models = models
            best_cost = new_cost
            println("Iteration $iteration: New best cost = $best_cost")
        end
    end
    
    return best_solution, best_cost, best_models
end

function decomposed_mpopf_downward_search(factory, time_periods, ramping_data, demands; max_iterations=1000, max_time=300)
    data = PowerModels.parse_file(factory.file_path)
    PowerModels.standardize_cost_terms!(data, order=2)
    PowerModels.calc_thermal_limits!(data)

    # Initialize solution at max demand
    initial_solution = initialize_max_demand_solution(data, time_periods, demands, ramping_data)
    
    # Perform downward search
    best_solution, best_cost, best_models = downward_search(initial_solution, data, ramping_data, demands, factory, max_iterations=max_iterations, max_time=max_time)
    
    # Calculate base cost for comparison
    base_cost = build_search_model(factory, time_periods, ramping_data, demands)
    
    return best_solution, best_cost, best_models, base_cost
end

####################
# Aggressive search
####################

function aggressive_local_search(initial_solution, data, ramping_data, demands, factory; max_iterations=10000, max_time=600)
    best_solution = initial_solution
    best_cost = calculate_total_cost(best_solution, optimize_solution(best_solution, data, ramping_data, demands, factory)[1], ramping_data)
    
    start_time = time()
    for iteration in 1:max_iterations
        if time() - start_time > max_time
            println("Time limit reached. Stopping search.")
            break
        end
        
        t = rand(1:length(initial_solution))
        new_solution = local_search_move(best_solution, data, ramping_data, t)
        new_solution = adjust_to_meet_demand(new_solution, data, demands, t, ramping_data)
        
        optimized_solution, models = optimize_solution(new_solution, data, ramping_data, demands, factory)
        new_cost = calculate_total_cost(optimized_solution, models, ramping_data)
        
        if new_cost < best_cost && is_feasible_solution(models)
            best_solution = optimized_solution
            best_cost = new_cost
            println("Iteration $iteration: New best cost = $best_cost")
        end
    end
    
    return best_solution, best_cost
end

function decomposed_mpopf_improved_search(factory, time_periods, ramping_data, demands; max_iterations=10000, max_time=600)
    data = PowerModels.parse_file(factory.file_path)
    PowerModels.standardize_cost_terms!(data, order=2)
    PowerModels.calc_thermal_limits!(data)

    initial_solution = create_initial_feasible_solution(data, time_periods, demands, ramping_data)
    best_solution, best_cost = aggressive_local_search(initial_solution, data, ramping_data, demands, factory, max_iterations=max_iterations, max_time=max_time)
    
    base_cost = build_search_model(factory, time_periods, ramping_data, demands)
    
    return best_solution, best_cost, base_cost
end