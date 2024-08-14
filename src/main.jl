using Revise, PowerModels, JuMP, Ipopt, Gurobi
include("MPOPF.jl")
include("misc.jl")
include("search_functions.jl")
using .MPOPF

file_path = "./Cases/case14.m"

#=
# Example for AC
# --------------------------------------------------------------------------
ac_factory = ACMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_AC_model = create_model(ac_factory)
optimize_model(My_AC_model)
# --------------------------------------------------------------------------


# Example for DC
# --------------------------------------------------------------------------
dc_factory = DCMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_DC_model = create_model(dc_factory)
optimize_model(My_DC_model)
# --------------------------------------------------------------------------

# Example for AC with UncertaintyFactory
# --------------------------------------------------------------------------
load_scenarios_factors = load_scenarios_factors = generate_load_scenarios(3, 14)
# Using AC Factory from previous example
My_AC_model_Uncertainty = create_model(ac_factory, load_scenarios_factors)
optimize_model(My_AC_model_Uncertainty)
# --------------------------------------------------------------------------


# Example for DC with UncertaintyFactory
# --------------------------------------------------------------------------
load_scenarios_factors2 = load_scenarios_factors = generate_load_scenarios(3, 14)
# Using DC Factory but with Gurobi
dc_factory_Gurobi = DCMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_DC_model_Uncertainty = create_model(dc_factory_Gurobi, load_scenarios_factors2)
optimize_model(My_DC_model_Uncertainty)
# --------------------------------------------------------------------------
=#
#=
modelToAnalyse = My_DC_model_Uncertainty
display(JuMP.value.(modelToAnalyse.model[:pg]))
display(JuMP.value.(modelToAnalyse.model[:mu_plus]))
display(JuMP.value.(modelToAnalyse.model[:mu_minus]))
=#


# Example usage:
file_path = "./Cases/case14.m"
#= # Case 300, figure out bus id problem
ramp_limits = 0.1 .+ 0.2 .* rand(5)
costs = 20 .+ 80 .* rand(5)
ramping_data = Dict(
    "ramp_limits" => ramp_limits,
    "costs" => costs
)
demands = [0.2 .* rand(300) for _ in 1:3]
=#
ramping_data = Dict(
    #"ramp_limits" => [0.261308, 0.179846, 0.127649, 0.256349, 0.124095], # These ramp limits arent working?
    "ramp_limits" => [0.05, 0.05, 0.05, 0.5, 0.5],
    #"costs" => [27.1089, 59.3871, 79.9998, 27.0244, 48.7984]
    "costs" => [400, 100, 500, 900, 300]
)

demands = [
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149]
]
demands[2] .*= 1.2
demands[3] .*= 1.4
demands[4] .*= 1.8
demands[5] .*= 1.1
demands[6] .*= 0.9


# Total demand for initial case adjusted order=2 is 2.59
search_factory = DCMPOPFSearchFactory(file_path, Ipopt.Optimizer)
search_model = create_search_model(search_factory, 6, ramping_data, demands)


#println(value.(search_model.model[:pg]))
#println(termination_status(search_model.model))
#=
dc_factory = DCMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_DC_model = create_model(dc_factory)
optimize_model(My_DC_model)
=#

# Base cost is the cost of all time periods meeting demand, not
# taking ramping constraints into account


#best_solution1, best_cost1, best_models1, base_cost1 = decomposed_mpopf_local_search(search_factory, 3, ramping_data, demands)
#=
if best_solution !== nothing
    println("Best cost: ", best_cost)
    for (i, model) in enumerate(best_models)
        println("Model $i status: ", termination_status(model.model))
        println("Model $i objective value: ", objective_value(model.model))
    end
else
    println("No feasible solution found.")
end 
=#
best_solution2, best_cost2, best_models2, base_cost2, final_demands, total_iterations = decomposed_mpopf_demand_search(search_factory, 6, ramping_data, demands)

#best_cost = best_cost1 < best_cost2 ? best_cost1 : best_cost2
#best_solution = best_cost1 < best_cost2 ? best_solution1 : best_solution2
optimize_model(search_model)

println()
println("Full model cost:, ", objective_value(search_model.model))
println("Decomposed model cost: $best_cost2")
println("Base cost: $base_cost2")
println("Full model pg values:")
display(value.(search_model.model[:pg]))
println("Decomposed model pg values:")
display(best_solution2)
println("Base cost / best cost: ", base_cost2 / best_cost2)
#println(total_iterations)

#best_solution, best_cost, best_models, base_cost = decomposed_mpopf_downward_search(search_factory, 3, ramping_data, demands)

#= Ramping rates
It seems traditional gas/coal plants can ramp very quickly,
to the point where its not much of a constraint
Nuclear has very low ramping rates, treat as static
(Moder nuclear plants can change up to 5% per minute, but only change once or twice per day)
Renewable (solar/wind) have ramp rates that we cannot control
=#

#= Ramping costs
Solar = N/A
Wind = N/A
Gas/Coal = $2.43 - $4.68 (MWh)

=#
# Modify implementation to work with other cases where ID is not incremented 1 -> n

# Hard to beat the initial solution by any meaningful amount
#=
Tried
- Aggresive step sizes 
- Top down approach (initialize all Ts to largest and work down)
- Accepting worse solutions for n max_iterations
=#

# Output 1 unit of demand for 1 time period and see cost 
# Use a general "cost" for generation and make ramping a % of that 

############
# Read Lethbridge Herald article Aug 7th paper

#=
Full model cost:, 28067.150137891884
Decomposed model cost: 28067.150136635013
Base cost: 28067.150139926704
31981
=#