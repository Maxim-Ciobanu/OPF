using JuMP, Ipopt, Gurobi, Random
using PowerModels
using Statistics
using Distributions

include("probabilistic-OPF.jl")

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
    z_score = quantile(Normal(0,1), confidence_level)
    
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
                    var_total_demand += Statistics.var(dist)
                else
                    # If no distribution, use the deterministic value
                    mean_total_demand += ref[:load][l]["pd"]
                end
            end
            
            # Calculate standard deviation from variance
            std_total_demand = sqrt(var_total_demand)
            
            # Probabilistic power balance constraint
            # The z_score * std_total_demand term creates a margin based on the confidence level
            @constraint(model,
                sum(p_expr[t][a] for a in ref[:bus_arcs][b]) ==
                sum(pg[t, g] for g in ref[:bus_gens][b]) - 
                (mean_total_demand + z_score * std_total_demand) - 
                sum(shunt["gs"] for shunt in bus_shunts)*1.0^2
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
    
    # Initialize metrics
    total_violations = 0
    bus_violations = Dict([(b, 0) for b in keys(ref[:bus])])
    
    for sample in 1:num_samples
        # Sample demands from distributions
        sampled_demands = Dict()
        for (l, dist) in demand_distributions
            sampled_demands[l] = rand(dist)
        end
        
        # Check power balance at each bus
        for (b, bus) in ref[:bus]
            bus_loads = ref[:bus_loads][b]
            total_load = sum(haskey(sampled_demands, l) ? sampled_demands[l] : ref[:load][l]["pd"] for l in bus_loads)
            total_gen = sum(pg_values[1, g] for g in ref[:bus_gens][b]; init=0.0)
            
            # Calculate power imbalance (simplification: ignoring line flows)
            imbalance = total_gen - total_load
            
            # If imbalance is negative, we have a violation (not enough generation)
            if imbalance < 0
                total_violations += 1
                bus_violations[b] += 1
                break  # One violation per sample is enough
            end
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
    file_path = "././Cases/case_ACTIVSg500.m"
    confidence_level = 0.95  # 95% confidence
    variation_value = 0.0   # 15% variation in demand
    
    # Set up demand distributions
    demand_distributions = setup_demand_distributions(file_path, :relative, variation_value)
    
    # Create and solve the probabilistic model
    dc_factory = DCMPOPFModelFactory(file_path, Gurobi.Optimizer)
    prob_model = create_probabilistic_model(dc_factory, demand_distributions, confidence_level)
    
    optimize!(prob_model.model)
    # optimal_cost = objective_value(prob_model.model)
    # println("Probabilistic OPF Optimal Cost: ", optimal_cost)
    
    # Get generation values
    # pg_values = value.(prob_model.model[:pg])
    # println("\nGeneration values:")
    # display(pg_values)
    
    # Evaluate the solution reliability
    # reliability_metrics = evaluate_probabilistic_solution(prob_model)
    # println("\nSolution Reliability: $(reliability_metrics["reliability"] * 100)%")
    # println("Violations: $(reliability_metrics["violations"]) out of $(reliability_metrics["total_samples"]) samples")
    
    return prob_model
end


# run_first_method()




solved = run_probabilistic_opf_example()
pg_values = value.(solved.model[:pg])
# serialize the pg values
using Serialization
serialize("src/Probabilistic-OPF/pg_values_500.jld2", pg_values)

# Load the pg values
using Serialization
using JuMP
pg_values = deserialize("src/Probabilistic-OPF/pg_values_500.jld2")

using MPOPF

file_path = "././Cases/case_ACTIVSg500.m"
variation_value = 0.15   # 15% variation in demand
num_scenarios = 100

# Set up demand distributions
demand_distributions = setup_demand_distributions(file_path, :absolute, variation_value)
testing_scenarios = sample_demand_scenarios(demand_distributions, num_scenarios)
# Create and solve the probabilistic model
using Gurobi
dc_factory = DCMPOPFModelFactory(file_path, Gurobi.Optimizer)

MPOPF.test_concrete_solution(pg_values, testing_scenarios, dc_factory)
