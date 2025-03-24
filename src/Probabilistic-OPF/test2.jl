using JuMP, Ipopt, Gurobi, Random
using PowerModels
using Statistics
using Distributions

include("probabilistic-OPF.jl")




using JuMP, Ipopt, Gurobi, Random
using PowerModels
using Statistics
using Distributions

##############################################################################################
# New Struct for Probabilistic OPF
##############################################################################################

"""
    MPOPFModelProbabilistic <: AbstractMPOPFModel
Represents a Multi-Period Probabilistic Optimal Power Flow model.
# Fields
- `model::JuMP.Model`: The underlying JuMP model.
- `data::Dict`: Dictionary containing the power system data.
- `demand_distributions::Dict`: Dictionary of demand distributions.
- `confidence_level::Float64`: Confidence level (1-α) for probabilistic constraints.
- `time_periods::Int64`: Number of time periods in the model.
- `factors::Vector{Float64}`: Scaling factors for each time period.
- `ramping_cost::Int64`: Cost associated with generator ramping.
"""
mutable struct MPOPFModelProbabilistic <: AbstractMPOPFModel
    model::JuMP.Model
    data::Dict
    demand_distributions::Dict
    confidence_level::Float64
    time_periods::Int64
    factors::Vector{Float64}
    ramping_cost::Int64

    function MPOPFModelProbabilistic(model::JuMP.Model, data::Dict, demand_distributions::Dict, confidence_level::Float64=0.95, time_periods::Int64=1, factors::Vector{Float64}=[1.0], ramping_cost::Int64=0)
        return new(model, data, demand_distributions, confidence_level, time_periods, factors, ramping_cost)
    end
end

##############################################################################################
# Factory Functions for Probabilistic OPF
##############################################################################################

function set_model_probabilistic_variables!(power_flow_model::MPOPFModelProbabilistic, factory::DCMPOPFModelFactory)
    model = power_flow_model.model
    T = power_flow_model.time_periods
    ref = PowerModels.build_ref(power_flow_model.data)[:it][:pm][:nw][0]
    bus_data = ref[:bus]
    gen_data = ref[:gen]
    
    @variable(model, va[t in 1:T, i in keys(bus_data)])
    @variable(model, gen_data[i]["pmin"] <= pg[t in 1:T, i in keys(gen_data)] <= gen_data[i]["pmax"])
    @variable(model, -ref[:branch][l]["rate_a"] <= p[1:T,(l,i,j) in ref[:arcs_from]] <= ref[:branch][l]["rate_a"])
    @variable(model, ramp_up[t in 2:T, g in keys(gen_data)] >= 0)
    @variable(model, ramp_down[t in 2:T, g in keys(gen_data)] >= 0)
end

function set_model_probabilistic_objective_function!(power_flow_model::MPOPFModelProbabilistic, factory::DCMPOPFModelFactory)
    model = power_flow_model.model
    data = power_flow_model.data
    T = power_flow_model.time_periods
    ramping_cost = power_flow_model.ramping_cost
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
    gen_data = ref[:gen]
    pg = model[:pg]
    ramp_up = model[:ramp_up]
    ramp_down = model[:ramp_down]
    
    @objective(model, Min,
        sum(sum(gen_data[g]["cost"][1]*pg[t,g]^2 + gen_data[g]["cost"][2]*pg[t,g] + gen_data[g]["cost"][3] for g in keys(gen_data)) for t in 1:T) +
        sum(ramping_cost * (ramp_up[t, g] + ramp_down[t, g]) for g in keys(gen_data) for t in 2:T)
    )
end

function set_model_probabilistic_constraints!(power_flow_model::MPOPFModelProbabilistic, factory::DCMPOPFModelFactory)
    model = power_flow_model.model
    data = power_flow_model.data
    T = power_flow_model.time_periods
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
    gen_data = ref[:gen]
    demand_distributions = power_flow_model.demand_distributions
    confidence_level = power_flow_model.confidence_level
    
    va = model[:va]
    p = model[:p]
    pg = model[:pg]
    ramp_up = model[:ramp_up]
    ramp_down = model[:ramp_down]
    
    # Calculate the z-score for the given confidence level
    # Use the correct direction for the confidence interval
    # We want to ensure we have enough generation, so we need the upper bound
    z_score = quantile(Normal(0,1), confidence_level)
    
    # Also add slack variables for emergencies, but with very high cost
    @variable(model, mu_plus[t in 1:T, g in keys(ref[:gen])] >= 0)
    @variable(model, mu_minus[t in 1:T, b in keys(ref[:bus])] >= 0)
    
    # Update objective to include penalty for slack variables
    slack_penalty = 1e6  # High penalty
    current_obj = objective_function(model)
    @objective(model, Min, 
        current_obj + 
        slack_penalty * sum(mu_plus[t, g] for t in 1:T for g in keys(ref[:gen])) +
        slack_penalty * sum(mu_minus[t, b] for t in 1:T for b in keys(ref[:bus]))
    )
    
    p_expr = Dict()
    for t in 1:T
        p_expr[t] = Dict()
    end
    
    # Iterate over each time period
    for t in 1:T
        p_expr[t] = Dict([((l, i, j), 1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs_from]])
        p_expr[t] = merge(p_expr[t], Dict([((l, j, i), -1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs_from]]))
    end

    for t in 1:T
        for (i, bus) in ref[:ref_buses]
            @constraint(model, va[t,i] == 0)
        end

        for (b, bus) in ref[:bus]
            # Get loads at this bus
            bus_loads = ref[:bus_loads][b]
            bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][b]]
            
            # Calculate mean and standard deviation of total demand at this bus
            mean_total_demand = 0.0
            var_total_demand = 0.0
            
            for l in bus_loads
                if haskey(demand_distributions, l)
                    dist = demand_distributions[l]
                    mean_total_demand += mean(dist)
                    var_total_demand += Statistics.var(dist)  # Explicitly use Statistics.var
                else
                    # If no distribution, use the deterministic value
                    mean_total_demand += ref[:load][l]["pd"]
                end
            end
            
            # Calculate standard deviation from variance
            std_total_demand = sqrt(var_total_demand)
            
            # Probabilistic power balance constraint with slack variables
            @constraint(model,
                sum(p_expr[t][a] for a in ref[:bus_arcs][b]) ==
                sum(pg[t, g] + mu_plus[t, g] for g in ref[:bus_gens][b]) - 
                (mean_total_demand + z_score * std_total_demand) - 
                sum(shunt["gs"] for shunt in bus_shunts)*1.0^2 - mu_minus[t, b]
            )
        end

        for (i,branch) in ref[:branch]
            f_idx = (i, branch["f_bus"], branch["t_bus"])
            
            p_fr = p[t,f_idx]
            
            va_fr = va[t,branch["f_bus"]]
            va_to = va[t,branch["t_bus"]]
            
            g, b = PowerModels.calc_branch_y(branch)
            
            @constraint(model, p_fr == -b*(va_fr - va_to))
            @constraint(model, va_fr - va_to <= branch["angmax"])
            @constraint(model, va_fr - va_to >= branch["angmin"])
        end
    end

    for g in keys(gen_data)
        for t in 2:T
            @constraint(model, ramp_up[t, g] >= pg[t, g] - pg[t-1, g])
            @constraint(model, ramp_down[t, g] >= pg[t-1, g] - pg[t, g])
        end
    end
    
    # Add a global power balance constraint to ensure we have enough total generation
    for t in 1:T
        total_mean_demand = 0.0
        total_var_demand = 0.0
        
        # Calculate total system demand statistics
        for (l, dist) in demand_distributions
            total_mean_demand += mean(dist)
            total_var_demand += Statistics.var(dist)
        end
        
        # Add deterministic loads (if any)
        for (l, load) in ref[:load]
            if !haskey(demand_distributions, l)
                total_mean_demand += load["pd"]
            end
        end
        
        total_std_demand = sqrt(total_var_demand)
        
        # System-wide generation >= system-wide demand with confidence margin
        @constraint(model, 
            sum(pg[t, g] for g in keys(ref[:gen])) >= 
            total_mean_demand + z_score * total_std_demand
        )
    end
end

function create_probabilistic_model(
    factory::AbstractMPOPFModelFactory, 
    demand_distributions::Dict, 
    confidence_level::Float64=0.95,
    time_periods::Int64=1, 
    factors::Vector{Float64}=[1.0], 
    ramping_cost::Int64=0
)::MPOPFModelProbabilistic
    
    data = PowerModels.parse_file(factory.file_path)
    PowerModels.standardize_cost_terms!(data, order=2)
    PowerModels.calc_thermal_limits!(data)

    model = JuMP.Model(factory.optimizer)

    power_flow_model = MPOPFModelProbabilistic(model, data, demand_distributions, confidence_level, time_periods, factors, ramping_cost)

    set_model_probabilistic_variables!(power_flow_model, factory)
    set_model_probabilistic_objective_function!(power_flow_model, factory)
    set_model_probabilistic_constraints!(power_flow_model, factory)

    return power_flow_model
end

##############################################################################################
# Helper Functions for Probabilistic OPF
##############################################################################################

"""
    evaluate_probabilistic_solution(model::MPOPFModelProbabilistic, num_samples::Int64=1000)

Evaluate the reliability of a probabilistic OPF solution by sampling from the demand distributions
and checking how often the solution satisfies the power balance constraints.

# Arguments
- `model::MPOPFModelProbabilistic`: The probabilistic OPF model to evaluate.
- `num_samples::Int64`: Number of demand samples to generate for testing.

# Returns
- `Dict`: A dictionary containing reliability metrics.
"""
function evaluate_probabilistic_solution(model::MPOPFModelProbabilistic, num_samples::Int64=1000)
    data = model.data
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
    demand_distributions = model.demand_distributions
    pg_values = value.(model.model[:pg])
    p_values = value.(model.model[:p])
    va_values = value.(model.model[:va])
    
    # Initialize metrics
    total_violations = 0
    bus_violations = Dict([(b, 0) for b in keys(ref[:bus])])
    
    for sample in 1:num_samples
        # Sample demands from distributions
        sampled_demands = Dict()
        for (l, dist) in demand_distributions
            sampled_demands[l] = rand(dist)
        end
        
        # Create a new model to check power flow feasibility with fixed generation
        check_model = JuMP.Model(Gurobi.Optimizer)
        # set_optimizer_attribute(check_model, "print_level", 0)  # Suppress solver output
        
        # Variables
        @variable(check_model, va[i in keys(ref[:bus])])
        @variable(check_model, -ref[:branch][l]["rate_a"] <= p[(l,i,j) in ref[:arcs_from]] <= ref[:branch][l]["rate_a"])
        
        # Fix reference bus angle
        for (i, bus) in ref[:ref_buses]
            @constraint(check_model, va[i] == 0)
        end
        
        # Power flow equations
        p_expr = Dict()
        p_expr = Dict([((l, i, j), 1.0 * p[(l, i, j)]) for (l, i, j) in ref[:arcs_from]])
        p_expr = merge(p_expr, Dict([((l, j, i), -1.0 * p[(l, i, j)]) for (l, i, j) in ref[:arcs_from]]))
        
        # Power balance with sampled demands
        for (b, bus) in ref[:bus]
            bus_loads = ref[:bus_loads][b]
            bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][b]]
            
            # Calculate total load at this bus with sampled demands
            total_load = 0.0
            for l in bus_loads
                if haskey(sampled_demands, l)
                    total_load += sampled_demands[l]
                else
                    total_load += ref[:load][l]["pd"]
                end
            end
            
            # Fixed generation from probabilistic OPF solution
            total_gen = sum(pg_values[1, g] for g in ref[:bus_gens][b]; init=0.0)
            
            # Power balance constraint with fixed generation
            @constraint(check_model,
                sum(p_expr[a] for a in ref[:bus_arcs][b]) ==
                total_gen - total_load - sum(shunt["gs"] for shunt in bus_shunts)*1.0^2
            )
        end
        
        # Branch flow constraints
        for (i,branch) in ref[:branch]
            f_idx = (i, branch["f_bus"], branch["t_bus"])
            
            p_fr = p[f_idx]
            
            va_fr = va[branch["f_bus"]]
            va_to = va[branch["t_bus"]]
            
            g, b = PowerModels.calc_branch_y(branch)
            
            @constraint(check_model, p_fr == -b*(va_fr - va_to))
            @constraint(check_model, va_fr - va_to <= branch["angmax"])
            @constraint(check_model, va_fr - va_to >= branch["angmin"])
        end
        
        # Try to solve the power flow with fixed generation
        JuMP.optimize!(check_model)
        
        # Check if the power flow is feasible
        if termination_status(check_model) != MOI.OPTIMAL && termination_status(check_model) != MOI.LOCALLY_SOLVED
            total_violations += 1
        end
    end
    
    reliability = 1.0 - (total_violations / num_samples)
    
    return Dict(
        "reliability" => reliability,
        "violations" => total_violations,
        "bus_violations" => bus_violations,
        "total_samples" => num_samples
    )
end

##############################################################################################
# Example Usage
##############################################################################################

# Example usage
function run_probabilistic_opf_example()
    file_path = "././Cases/case14.m"
    confidence_level = 0.95  # 95% confidence
    variation_value = 0.15   # 15% variation in demand
    
    # Set up demand distributions
    demand_distributions = setup_demand_distributions(file_path, :relative, variation_value)
    
    # Create and solve the probabilistic model
    dc_factory = DCMPOPFModelFactory(file_path, Gurobi.Optimizer)
    prob_model = create_probabilistic_model(dc_factory, demand_distributions, confidence_level)
    
    # Set solver options for better convergence
    # set_optimizer_attribute(prob_model.model, "max_iter", 5000)
    # set_optimizer_attribute(prob_model.model, "tol", 1e-6)
    
    optimize!(prob_model.model)
    optimal_cost = objective_value(prob_model.model)
    println("Probabilistic OPF Optimal Cost: ", optimal_cost)
    
    # Get generation values
    pg_values = value.(prob_model.model[:pg])
    println("\nGeneration values:")
    display(pg_values)
    
    # Check slack variables usage
    mu_plus_values = value.(prob_model.model[:mu_plus])
    mu_minus_values = value.(prob_model.model[:mu_minus])
    
    # Sum all mu_plus and mu_minus values
    total_mu_plus = sum(mu_plus_values)
    total_mu_minus = sum(mu_minus_values)
    
    println("\nSlack Variables:")
    println("Total mu_plus: $total_mu_plus")
    println("Total mu_minus: $total_mu_minus")
    
    # Print statistical information about the problem
    ref = PowerModels.build_ref(prob_model.data)[:it][:pm][:nw][0]
    total_mean_demand = 0.0
    total_std_demand = 0.0
    
    for (l, dist) in demand_distributions
        total_mean_demand += mean(dist)
        total_std_demand += sqrt(Statistics.var(dist))
    end
    
    println("\nProblem Statistics:")
    println("Total mean demand: $total_mean_demand")
    println("Z-score for $(confidence_level*100)% confidence: $(quantile(Normal(0,1), confidence_level))")
    println("Safety margin: $(quantile(Normal(0,1), confidence_level) * total_std_demand)")
    println("Total generation capacity: $(sum(ref[:gen][g]["pmax"] for g in keys(ref[:gen])))")
    
    # Evaluate the solution reliability with a smaller sample size initially
    println("\nEvaluating solution reliability with 100 samples...")
    reliability_metrics = evaluate_probabilistic_solution(prob_model, 100)
    println("Solution Reliability: $(reliability_metrics["reliability"] * 100)%")
    println("Violations: $(reliability_metrics["violations"]) out of $(reliability_metrics["total_samples"]) samples")
    
    # If reliability looks promising, run a larger test
    if reliability_metrics["reliability"] > 0.5
        println("\nRunning full reliability test with 1000 samples...")
        reliability_metrics = evaluate_probabilistic_solution(prob_model, 1000)
        println("Solution Reliability: $(reliability_metrics["reliability"] * 100)%")
        println("Violations: $(reliability_metrics["violations"]) out of $(reliability_metrics["total_samples"]) samples")
    end
    
    return prob_model
end






# run_first_method()




run_probabilistic_opf_example()






# First Method

# 2-dimensional DenseAxisArray{Float64,2,...} with index sets:
#     Dimension 1, Base.OneTo(1)
#     Dimension 2, [5, 4, 2, 3, 1]
# And data, a 1×5 Matrix{Float64}:
#  0.00445793  0.00414112  0.400163  0.00454936  2.32495


# Second Method

# 2-dimensional DenseAxisArray{Float64,2,...} with index sets:
#     Dimension 1, Base.OneTo(1)
#     Dimension 2, [5, 4, 2, 3, 1]
# And data, a 1×5 Matrix{Float64}:
#  0.154329  0.154329  0.406173  0.154329  2.35987


# Third Method

# 2-dimensional DenseAxisArray{Float64,2,...} with index sets:
#     Dimension 1, Base.OneTo(1)
#     Dimension 2, [5, 4, 2, 3, 1]
# And data, a 1×5 Matrix{Float64}:
#  0.154329  0.154329  0.406173  0.154329  2.35987
