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
            # For subsequent time periods, respect ramping limits
            for (i, gen) in data["gen"]
                gen_id = parse(Int, i)
                prev_output = solution[t-1][gen_id]
                ramp_limit = ramping_data["ramp_limits"][gen_id]
                pg[gen_id] = max(gen["pmin"], min(gen["pmax"], prev_output + rand(-ramp_limit:0.01:ramp_limit)))
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
    for t in 1:length(solution)
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
        
        # Check if the optimization was successful
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
    operation_cost = sum(objective_value(model.model) for model in models)
    ramping_cost = sum(
        ramping_data["costs"][gen_id] * abs(solution[t][gen_id] - solution[t-1][gen_id])
        for t in 2:length(solution)
        for gen_id in keys(solution[t])
    )
    return operation_cost + ramping_cost
end

function is_feasible_solution(models)
    return all(termination_status(model.model) in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED] for model in models)
end

function decomposed_mpopf_local_search(factory, time_periods, ramping_data, demands; max_iterations=1000, max_time=300)
    data = PowerModels.parse_file(factory.file_path)
    PowerModels.standardize_cost_terms!(data, order=2)
    PowerModels.calc_thermal_limits!(data)
    
    solution = create_initial_feasible_solution(data, time_periods, demands, ramping_data)
    
    for t in 1:time_periods
        solution = adjust_to_meet_demand(solution, data, demands, t, ramping_data)
    end
    
    best_solution, best_models = optimize_solution(solution, data, ramping_data, demands, factory)
    best_cost = calculate_total_cost(best_solution, best_models, ramping_data)
    
    start_time = time()
    no_improvement_count = 0
    
    for iteration in 1:max_iterations
        if time() - start_time > max_time
            println("Time limit reached. Stopping search.")
            break
        end
        
        new_solution = deepcopy(best_solution)
        
        # Choose a random time period to adjust
        t = rand(1:time_periods)
        
        # Randomly select a subset of generators to adjust
        num_gens = length(new_solution[t])
        gens_to_adjust = shuffle(1:num_gens)[1:rand(1:num_gens)]
        
        for gen in gens_to_adjust
            ramp_limit = ramping_data["ramp_limits"][gen]
            
            # Make a random adjustment within ramping limits
            if t > 1
                prev_output = new_solution[t-1][gen]
                max_down = max(data["gen"]["$gen"]["pmin"], prev_output - ramp_limit) - new_solution[t][gen]
                max_up = min(data["gen"]["$gen"]["pmax"], prev_output + ramp_limit) - new_solution[t][gen]
            else
                max_down = data["gen"]["$gen"]["pmin"] - new_solution[t][gen]
                max_up = data["gen"]["$gen"]["pmax"] - new_solution[t][gen]
            end
            
            adjustment = rand(max_down:0.01:max_up)
            new_solution[t][gen] += adjustment
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
            no_improvement_count = 0
            println("Iteration $iteration: New best cost = $best_cost")
        else
            no_improvement_count += 1
        end
        
        # If no improvement for a while, break the loop
        if no_improvement_count >= 100
            println("No improvement for 100 iterations. Stopping search.")
            break
        end
    end
    
    return best_solution, best_cost, best_models
end