using JuMP, Ipopt, Gurobi, Random
using PowerModels
using Statistics
using Distributions

##############################################################################################
# Factory Structs
# They are used as parameters so that Julias multiple dispatch knows which functions to call
##############################################################################################

    # Abstract type as a base so that we can use this type as a parameter in functions
    """
        AbstractMPOPFModelFactory
    An abstract type serving as a base for all MPOPF model factories.
    """
    abstract type AbstractMPOPFModelFactory end

    # This struct "inherits" from PowerFlowModelFactory
    """
        ACMPOPFModelFactory <: AbstractMPOPFModelFactory
    Factory for creating AC MPOPF models.
    # Fields
    - `file_path::String`: Path to the input data file.
    - `optimizer::Type`: The optimizer to be used (e.g., Ipopt.Optimizer).
    """
    mutable struct ACMPOPFModelFactory <: AbstractMPOPFModelFactory
        file_path::String
        optimizer

        function ACMPOPFModelFactory(file_path::String, optimizer)
            return new(file_path, optimizer)
        end
    end

    # This struct "inherits" from PowerFlowModelFactory
    """
        DCMPOPFModelFactory <: AbstractMPOPFModelFactory
    Factory for creating DC MPOPF models.
    # Fields
    - `file_path::String`: Path to the input data file.
    - `optimizer::Type`: The optimizer to be used.
    """
    mutable struct DCMPOPFModelFactory <: AbstractMPOPFModelFactory
        file_path::String
        optimizer::Type

        function DCMPOPFModelFactory(file_path::String, optimizer::Type)
            return new(file_path, optimizer)
        end
    end

##############################################################################################
# Concrete Model Structs
# They are used as objects, passed around with variables that are specific to each model
##############################################################################################

    # Abstract type as a base so that we can use this type as a parameter in functions
    """
        AbstractMPOPFModel
    An abstract type serving as a base for all MPOPF model types.
    """
    abstract type AbstractMPOPFModel end

    # The actual PowerFlowModel struct that "inherits" from AbstractPowerFlowModel
    """
        MPOPFModel <: AbstractMPOPFModel
    Represents a Multi-Period Optimal Power Flow model.
    # Fields
    - `model::JuMP.Model`: The underlying JuMP model.
    - `data::Dict`: Dictionary containing the power system data.
    - `time_periods::Int64`: Number of time periods in the model.
    - `factors::Vector{Float64}`: Scaling factors for each time period.
    - `ramping_cost::Int64`: Cost associated with generator ramping.
    """
    mutable struct MPOPFModel <: AbstractMPOPFModel
        model::JuMP.Model
        data::Dict
        time_periods::Int64
        factors::Vector{Float64}
        ramping_cost::Int64

        function MPOPFModel(model::JuMP.Model, data::Dict, time_periods::Int64=1, factors::Vector{Float64}=[1.0], ramping_cost::Int64=0)
            return new(model, data, time_periods, factors, ramping_cost)
        end
    end

    # Similar PowerFlowModel object but with an additional scenarios variable for uncertainty
    """
        MPOPFModelUncertainty <: AbstractMPOPFModel
    Represents a Multi-Period Optimal Power Flow model with uncertainty considerations.
    # Fields
    - `model::JuMP.Model`: The underlying JuMP model.
    - `data::Dict`: Dictionary containing the power system data.
    - `scenarios::Dict`: Dictionary of scenarios for uncertainty analysis.
    - `time_periods::Int64`: Number of time periods in the model.
    - `factors::Vector{Float64}`: Scaling factors for each time period.
    - `ramping_cost::Int64`: Cost associated with generator ramping.
    """
    mutable struct MPOPFModelUncertainty <: AbstractMPOPFModel
        model::JuMP.Model
        data::Dict
        scenarios::Dict
        time_periods::Int64
        factors::Vector{Float64}
        ramping_cost::Int64

        function MPOPFModelUncertainty(model::JuMP.Model, data::Dict, scenarios::Dict, time_periods::Int64=1, factors::Vector{Float64}=[1.0], ramping_cost::Int64=0)
            return new(model, data, scenarios, time_periods, factors, ramping_cost)
        end
    end

##############################################################################################
# Factory Functions
# These functions are used to create the models
##############################################################################################

function set_model_variables!(power_flow_model::AbstractMPOPFModel, factory::DCMPOPFModelFactory)
    model = power_flow_model.model
    T = power_flow_model.time_periods
    ref = PowerModels.build_ref(power_flow_model.data)[:it][:pm][:nw][0]
    bus_data = ref[:bus]
    gen_data = ref[:gen]
    
    @variable(model, va[t in 1:T, i in keys(bus_data)])
    @variable(model, gen_data[i]["pmin"] <= pg[t in 1:T, i in keys(gen_data)] <= gen_data[i]["pmax"])
    # @variable(model, -branch_data[l]["rate_a"] <= p[t in 1:T, (l,i,j) in ref[:arcs]] <= branch_data[l]["rate_a"])
    @variable(model, -ref[:branch][l]["rate_a"] <= p[1:T,(l,i,j) in ref[:arcs_from]] <= ref[:branch][l]["rate_a"])
    @variable(model, ramp_up[t in 2:T, g in keys(gen_data)] >= 0)
    @variable(model, ramp_down[t in 2:T, g in keys(gen_data)] >= 0)
end

function set_model_uncertainty_variables!(power_flow_model::MPOPFModelUncertainty)
    model = power_flow_model.model
    T = power_flow_model.time_periods
    ref = PowerModels.build_ref(power_flow_model.data)[:it][:pm][:nw][0]
    scenarios = power_flow_model.scenarios

    @variable(model, mu_plus[t in 1:T, g in keys(ref[:gen]), s in 1:length(scenarios)] >= 0)
    @variable(model, mu_minus[t in 1:T, l in keys(ref[:bus]), s in 1:length(scenarios)] >= 0)
end


function set_model_uncertainty_objective_function!(power_flow_model::MPOPFModelUncertainty, factory::DCMPOPFModelFactory, mu_plus_cost::Float64, mu_minus_cost::Float64)
    model = power_flow_model.model
    data = power_flow_model.data
    T = power_flow_model.time_periods
    ramping_cost = power_flow_model.ramping_cost
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
    gen_data = ref[:gen]
    pg = model[:pg]
    ramp_up = model[:ramp_up]
    ramp_down = model[:ramp_down]
    mu_plus = model[:mu_plus]
    mu_minus = model[:mu_minus]
    scenarios = power_flow_model.scenarios
    
    @objective(model, Min,
        sum(sum(gen_data[g]["cost"][1]*pg[t,g]^2 + gen_data[g]["cost"][2]*pg[t,g] + gen_data[g]["cost"][3] for g in keys(gen_data)) for t in 1:T) +
        sum(ramping_cost * (ramp_up[t, g] + ramp_down[t, g]) for g in keys(gen_data) for t in 2:T)
        # Adding some cost for mu_plus and mu_minus.
        # + sum(10000 * (mu_plus[t, g, s] + mu_minus[t, b, s]) for g in keys(ref[:gen]) for b in keys(ref[:bus]) for t in 1:T for s in 1:length(scenarios))
        + sum(mu_plus_cost * mu_plus[t, g, s] for t in 1:T for s in 1:length(scenarios) for g in keys(ref[:gen]))
        + sum(mu_minus_cost * mu_minus[t, b, s] for t in 1:T for s in 1:length(scenarios) for b in keys(ref[:bus]))
    )
end

function set_model_uncertainty_constraints!(power_flow_model::MPOPFModelUncertainty, factory::DCMPOPFModelFactory)
    model = power_flow_model.model
    data = power_flow_model.data
    T = power_flow_model.time_periods
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
    gen_data = ref[:gen]
    va = model[:va]
    p = model[:p]
    pg = model[:pg]
    ramp_up = model[:ramp_up]
    ramp_down = model[:ramp_down]
    mu_plus = model[:mu_plus]
    mu_minus = model[:mu_minus]
    scenarios = power_flow_model.scenarios
    num_scenarios = length(scenarios)

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

        for s in 1:num_scenarios
            scenario = scenarios[s]
            for (b, bus) in ref[:bus]
                
                # Active power balance at node i for scenario s
                # This is the original bus_loads calculation
                # bus_loads = [ref[:load][l] for l in ref[:bus_loads][b]]
                bus_loads = ref[:bus_loads][b]
                bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][b]]

                # This is the original constraint
                # @constraint(model,
                #     sum(p_expr[t][a] for a in ref[:bus_arcs][b]) ==
                #     sum(pg[t, g] + mu_plus[t, g, s] for g in ref[:bus_gens][b]) - 
                #     sum(load["pd"] for load in bus_loads) - 
                #     sum(shunt["gs"] for shunt in bus_shunts)*1.0^2 - mu_minus[t, b, s]
                # )

                @constraint(model,
                    sum(p_expr[t][a] for a in ref[:bus_arcs][b]) ==
                    sum(pg[t, g] + mu_plus[t, g, s] for g in ref[:bus_gens][b]) - 
                    sum(scenario[l] for l in bus_loads) - 
                    sum(shunt["gs"] for shunt in bus_shunts)*1.0^2 - mu_minus[t, b, s]
                )

            end
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

# This function simply optimizes any model given as a parameter
# It prints the Optimial cost
"""
    optimize_model(model::AbstractMPOPFModel)
Optimize the given MPOPF model and print the optimal cost.

!!! note
    If the model being optimized is of type `MPOPFModelUncertainty`
    then extra computation will be executed to determine if there are
    any unbalaced power at each bus for every scenario
    when consitering mu_plus and mu_minus.
    That is if `sum_of_mu_plus` and `mu_minus` are both > 0.01
    at any given bus then an error message is printed.
# Arguments
- `model`: The MPOPF model to optimize.
"""
function optimize_model(model::AbstractMPOPFModel)
    optimize!(model.model)
    optimal_cost = objective_value(model.model)
    println("Optimal Cost: ", optimal_cost)
    println()

    if isa(model, MPOPFModelUncertainty)
        data = model.data
        T = model.time_periods
        S = length(model.scenarios)
        ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
        error_check = 0

        for t in 1:T    
            for s in 1:S
                for b in keys(ref[:bus])
                    sum_of_mu_plus = 0
                    mu_minus = 0
                    sum_of_mu_plus = sum(value(model.model[:mu_plus][t, g, s]) for g in ref[:bus_gens][b]; init = 0)
                    mu_minus = value(model.model[:mu_minus][t, b, s])
                    if sum_of_mu_plus >= 0.01 && mu_minus >= 0.01
                        error_check = error_check + 1
                        println("###############")
                        println("#### Error ####")
                        println("###############")

                        println("Scenario: $s Bus: $b")
                        println("mu_plus: $sum_of_mu_plus")
                        println("mu_minus: $mu_minus")
                        println()
                    end
                end
            end
        end
        if error_check == 0
            println("No mu_plus and mu_minus errors found")
            println()
        else
            println("Found $error_check error(s)")
            println()
        end
    end
end

function create_model(factory::AbstractMPOPFModelFactory, scenarios::Dict, mismatch_costs::Tuple{Float64,Float64}=(10000.0, 10000.0), time_periods::Int64=1, factors::Vector{Float64}=[1.0], ramping_cost::Int64=0)::MPOPFModelUncertainty
    data = PowerModels.parse_file(factory.file_path)
    PowerModels.standardize_cost_terms!(data, order=2)
    PowerModels.calc_thermal_limits!(data)

    mu_plus_cost = mismatch_costs[1]
    mu_minus_cost = mismatch_costs[2]

    model = JuMP.Model(factory.optimizer)

    power_flow_model = MPOPFModelUncertainty(model, data, scenarios, time_periods, factors, ramping_cost)

    set_model_variables!(power_flow_model, factory)
    set_model_uncertainty_variables!(power_flow_model)
    set_model_uncertainty_objective_function!(power_flow_model, factory, mu_plus_cost, mu_minus_cost)
    set_model_uncertainty_constraints!(power_flow_model, factory)

    return power_flow_model
end


##############################################################################################
# Helper Functions
# These functions are used for the first method of distributions
##############################################################################################


"""
    setup_demand_distributions(file_path::String, variation_type::Symbol=:absolute, variation_value::Float64=0.15)

Setup demand distributions for a given case file.

# Arguments
- `file_path::String`: The path to the case file.
- `variation_type::Symbol`: The type of variation to apply (:absolute, :relative).
- `variation_value::Float64`: The value of the variation to apply (ex: 0.15).

# Returns
- `Dict()`: A dictionary where each key is a load number to a normal distribution.
"""
function setup_demand_distributions(file_path, variation_type::Symbol=:absolute, variation_value::Float64 = 0.15)
    data = PowerModels.parse_file(file_path)
    PowerModels.standardize_cost_terms!(data, order=2)
    PowerModels.calc_thermal_limits!(data)

    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
    distributions = Dict()
    
    for (i, load) in ref[:load]
        mu = load["pd"]
        if variation_type == :relative
            sigma = abs(mu) * variation_value
        elseif variation_type == :absolute
            sigma = variation_value
        else
            error("Invalid variation_type. Use :relative or :absolute")
        end
        distributions[i] = Normal(mu, sigma)
    end
    
    return distributions
end

"""
    sample_demand_scenarios(distributions::Dict{Any, Any}, num_scenarios::Int64=1, debug::Bool=false)

Sample demand scenarios for a given set of distributions.

# Arguments
- `distributions::Dict{Any, Any}`: A dictionary where each key is a load number to a normal distribution.
- `num_scenarios::Int64`: The number of scenarios to sample.
- `debug::Bool`: A flag to print debug information.

# Returns
- `Dict{Int, Dict{Int, Float64}}`: A dictionary where each key is a scenario number and the value is another dictionary
mapping load numbers to sampled demand values.
"""
function sample_demand_scenarios(distributions::Dict{Any, Any}, num_scenarios::Int64=1, debug::Bool=false)
    scenarios = Dict()
    
    if debug
        println("Sampling diagnostics:")
        for (i, dist) in distributions
            println("Load $i: μ = $(mean(dist)), σ = $(std(dist))")
        end
        println()
    end
    
    for s in 1:num_scenarios
        scenario = Dict()
        for (i, dist) in distributions
            sampled_value = rand(dist)

            # Ensure non-negative demand
            # However it will in the long run shift the mean of the distribution
            # upwards. This is because the distribution is truncated at 0.
            # scenario[i] = max(0, sampled_value)
            # Here we will allow negative demand values.
            scenario[i] = sampled_value


            
            if debug
                println("Scenario $s, Load $i:")
                println("  Original Value: $(mean(dist))")
                println("  Original sample: $sampled_value")
                println("  After max(0, x): $(scenario[i])")
                println("  Z-score: $((sampled_value - mean(dist)) / std(dist))")
                println()
            end
        end
        scenarios[s] = scenario
    end
    
    if debug
        for (i, dist) in distributions
            samples = [scenarios[s][i] for s in 1:num_scenarios]
            println("Load $i statistics across all scenarios:")
            println("  Original Value: $(mean(dist))")
            println("  Mean: $(mean(samples))")
            println("  Std Dev: $(std(samples))")
            println("  Min: $(minimum(samples))")
            println("  Max: $(maximum(samples))")
            println()
        end
    end
    
    return scenarios
end


##############################################################################################
# Main
# This is the main code that is run
##############################################################################################

function run_first_method()
    file_path = "././Cases/case_ACTIVSg500.m"
    num_scenarios = 10
    variation_value = 0.15
    mismatch_costs::Tuple{Float64,Float64}=(10000000.0, 10000000.0)

    # Get initial PG solution from first method
    distributions = setup_demand_distributions(file_path, :relative, variation_value)
    training_scenarios = sample_demand_scenarios(distributions, num_scenarios)

    dc_factory_Gurobi = DCMPOPFModelFactory(file_path, Gurobi.Optimizer)
    My_DC_model_Uncertainty = create_model(dc_factory_Gurobi, training_scenarios, mismatch_costs)
    optimize_model(My_DC_model_Uncertainty)
    # Output the final Pg Values
    println("Final Pg values:")
    println()
    PgValues = JuMP.value.(My_DC_model_Uncertainty.model[:pg])
    display(PgValues)
    println()
    display(value.(My_DC_model_Uncertainty.model[:mu_plus]))
    println()
    display(value.(My_DC_model_Uncertainty.model[:mu_minus]))
end

# run_first_method()