using JuMP, Ipopt, Gurobi, Random
using PowerModels
using Statistics
using Distributions

include("probabilistic-OPF.jl")

function create_probabilistic_model(factory::AbstractMPOPFModelFactory, 
                                  distributions::Dict, 
                                  confidence_level::Float64=0.95,
                                  epsilon::Float64=0.1,
                                  time_periods::Int64=1, 
                                  factors::Vector{Float64}=[1.0], 
                                  ramping_cost::Int64=0)::MPOPFModel
    
    data = PowerModels.parse_file(factory.file_path)
    PowerModels.standardize_cost_terms!(data, order=2)
    PowerModels.calc_thermal_limits!(data)
    
    model = JuMP.Model(factory.optimizer)
    power_flow_model = MPOPFModel(model, data, time_periods, factors, ramping_cost)
    
    # Setup variables
    set_model_variables!(power_flow_model, factory)
    
    # Set objective function
    set_probabilistic_objective_function!(power_flow_model, factory)
    
    # Set probabilistic constraints
    set_probabilistic_constraints!(power_flow_model, factory, distributions, confidence_level, epsilon)
    
    return power_flow_model
end

function set_probabilistic_objective_function!(power_flow_model::MPOPFModel, factory::DCMPOPFModelFactory)
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

function set_probabilistic_constraints!(power_flow_model::MPOPFModel, factory::DCMPOPFModelFactory, distributions::Dict, confidence_level::Float64, epsilon::Float64)
    model = power_flow_model.model
    data = power_flow_model.data
    T = power_flow_model.time_periods
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
    va = model[:va]
    p = model[:p]
    pg = model[:pg]
    ramp_up = model[:ramp_up]
    ramp_down = model[:ramp_down]
    
    # Calculate z-score for the confidence level
    alpha = 1 - confidence_level
    z = quantile(Normal(0, 1), 1 - alpha/2)  # e.g., for 95% confidence, z = 1.96
    
    p_expr = Dict()
    for t in 1:T
        p_expr[t] = Dict()
    end
    
    # Set up p_expr
    for t in 1:T
        p_expr[t] = Dict([((l, i, j), 1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs_from]])
        p_expr[t] = merge(p_expr[t], Dict([((l, j, i), -1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs_from]]))
    end
    
    for t in 1:T
        # Set reference bus angle
        for (i, bus) in ref[:ref_buses]
            @constraint(model, va[t,i] == 0)
        end
        
        # Apply power balance constraints at each bus
        for (b, bus) in ref[:bus]
            bus_loads = ref[:bus_loads][b]
            bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][b]]
            
            # Calculate the left and right quantiles for loads at this bus
            sum_left_quantiles = 0.0
            sum_right_quantiles = 0.0
            mean_load_sum = 0.0
            
            for l in bus_loads
                if haskey(distributions, l)
                    dist = distributions[l]
                    mu = mean(dist)
                    sigma = std(dist)
                    # Calculate left and right quantiles as per professor's explanation
                    sum_left_quantiles += mu - z * sigma
                    sum_right_quantiles += mu + z * sigma
                    mean_load_sum += mu
                else
                    # If no distribution, use the fixed load value
                    pd_value = ref[:load][l]["pd"]
                    sum_left_quantiles += pd_value
                    sum_right_quantiles += pd_value
                    mean_load_sum += pd_value
                end
            end
            
            # Generation at this bus
            gen_sum = sum(pg[t, g] for g in ref[:bus_gens][b]; init=0.0)
            shunt_sum = sum(shunt["gs"] for shunt in bus_shunts; init=0.0) * 1.0^2
            
            # The constant C is the expected power balance
            C = gen_sum - mean_load_sum - shunt_sum
            
            # Probabilistic constraints based on professor's formulation
            # P(-epsilon - C <= sum(di) <= epsilon - C) >= 1-alpha
            # Which becomes:
            # -epsilon - C <= sum_left_quantiles
            # epsilon - C >= sum_right_quantiles
            
            @constraint(model, -epsilon - C <= sum_left_quantiles)
            @constraint(model, epsilon - C >= sum_right_quantiles)
            
            # Standard power balance constraint with expected values
            @constraint(model,
                sum(p_expr[t][a] for a in ref[:bus_arcs][b]) ==
                gen_sum - mean_load_sum - shunt_sum
            )
        end
        
        # Branch flow constraints
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
    
    # Ramping constraints
    for g in keys(ref[:gen])
        for t in 2:T
            @constraint(model, ramp_up[t, g] >= pg[t, g] - pg[t-1, g])
            @constraint(model, ramp_down[t, g] >= pg[t-1, g] - pg[t, g])
        end
    end
end

function run_probabilistic_method(file_path::String; 
                                 confidence_level::Float64=0.95,
                                 epsilon::Float64=0.1,
                                 variation_type::Symbol=:relative,
                                 variation_value::Float64=0.15)
    
    # Setup distributions for loads
    distributions = setup_demand_distributions(file_path, variation_type, variation_value)
    
    # Create and solve the probabilistic model
    dc_factory = DCMPOPFModelFactory(file_path, Gurobi.Optimizer)
    probabilistic_model = create_probabilistic_model(dc_factory, distributions, confidence_level, epsilon)
    
    optimize!(probabilistic_model.model)
    optimal_cost = objective_value(probabilistic_model.model)
    
    println("Optimal Cost: ", optimal_cost)
    println()
    
    # Display optimal generation values
    pg_values = JuMP.value.(probabilistic_model.model[:pg])
    println("Optimal Generation Values:")
    display(pg_values)
    
    return probabilistic_model
end



# Run the probabilistic method on the case14.m file
# probabilistic_model = run_probabilistic_method("././Cases/case14.m", confidence_level=0.95, epsilon=10.0, variation_type=:relative, variation_value=0.15)

# pg_vals = JuMP.value.(probabilistic_model.model[:pg])
# test= objective_value(probabilistic_model.model)


















#=
User-callback calls 113, time in user-callback 0.00 sec
Optimal Cost: 9018.434259237594

Optimal Generation Values:
2-dimensional DenseAxisArray{Float64,2,...} with index sets:
    Dimension 1, Base.OneTo(1)
    Dimension 2, [5, 4, 2, 3, 1]
And data, a 1×5 Matrix{Float64}:
 0.6  0.567073  0.49987  0.323057  0.6
=#

# using JuMP, Ipopt, Gurobi, Serialization, Random
# using PowerModels
# using MPOPF
# using Statistics
# using CSV
# using DataFrames

# # Run basic case 14 model to see the answer
# dc_factory = DCMPOPFModelFactory("././Cases/case14.m", Gurobi.Optimizer)
# dc_model = create_model(dc_factory)
# optimize_model(dc_model)
# println(JuMP.value.(dc_model.model[:pg]))

#=
User-callback calls 114, time in user-callback 0.00 sec
Optimal Cost: 7642.59182158622
2-dimensional DenseAxisArray{Float64,2,...} with index sets:
    Dimension 1, Base.OneTo(1)
    Dimension 2, [5, 4, 2, 3, 1]
And data, a 1×5 Matrix{Float64}:
 3.61960921440392e-8  3.8661457543687997e-7  0.3803229829153641  6.323358966704804e-8  2.2096765302223296
=#

# run uncertainty method with one scenario
# file_path = "././Cases/case14.m"
# num_scenarios = 1
# variation_value = 0.0
# mismatch_costs::Tuple{Float64,Float64}=(10000.0, 10000.0)


# Get initial PG solution from first method
# distributions = setup_demand_distributions(file_path, :relative, variation_value)
# training_scenarios = sample_demand_scenarios(distributions, num_scenarios)

# dc_factory_Gurobi = DCMPOPFModelFactory(file_path, Gurobi.Optimizer)
# My_DC_model_Uncertainty = create_model(dc_factory_Gurobi, training_scenarios, mismatch_costs)
# optimize_model(My_DC_model_Uncertainty)
# # Output the final Pg Values
# println("Final Pg values:")
# println()
# PgValues = JuMP.value.(My_DC_model_Uncertainty.model[:pg])
# display(value.(My_DC_model_Uncertainty.model[:mu_plus]))
# display(value.(My_DC_model_Uncertainty.model[:mu_minus]))

#=
User-callback calls 105, time in user-callback 0.00 sec
Optimal Cost: 7642.591746053908

No mu_plus and mu_minus errors found


2-dimensional DenseAxisArray{Float64,2,...} with index sets:
    Dimension 1, Base.OneTo(1)
    Dimension 2, [5, 4, 2, 3, 1]
And data, a 1×5 Matrix{Float64}:
 2.5323e-10  3.49652e-10  0.380323  3.64969e-10  2.20968
=#