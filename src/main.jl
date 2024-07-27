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

# initial optimal value: 7642.591774313989
# initial pg values:  -8.95979e-9  -8.95981e-9  0.380323  -8.95969e-9  2.20968

# Example usage:
file_path = "./Cases/case14.m"
#= Case 300, figure out bus id problem
ramp_limits = 0.1 .+ 0.2 .* rand(79)
costs = 20 .+ 80 .* rand(79)
ramping_data = Dict(
    "ramp_limits" => ramp_limits,
    "costs" => costs
)
demands = [0.2 .* rand(300) for _ in 1:3]
=#
ramping_data = Dict(
    "ramp_limits" => [0.5, 0.5, 0.5, 0.5, 0.5],
    "costs" => [5000, 5000, 5000, 5000, 5000]
)

demands = [
    [0.0, 0.217, 0.942, 0.478, 0.076, 0.112, 0.0, 0.0, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.0, 0.217, 0.942, 0.478, 0.076, 0.112, 0.0, 0.0, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.0, 0.217, 0.942, 0.478, 0.076, 0.112, 0.0, 0.0, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149]
]
demands[2] .*= 1.53
demands[3] .*= 0.96

# Total demand for initial case adjusted order=2 is 2.59
search_factory = DCMPOPFSearchFactory(file_path, Ipopt.Optimizer)
search_model = create_search_model(search_factory, 3, ramping_data, demands)
optimize_model(search_model)

#println(value.(search_model.model[:pg]))
#println(termination_status(search_model.model))
#=
dc_factory = DCMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_DC_model = create_model(dc_factory)
optimize_model(My_DC_model)
=#

#base_cost = build_search_model(search_factory, 3, ramping_data, demands)
#println()


#test_factory = DCMPOPFModelFactory(file_path, Ipopt.Optimizer)
#test_model = create_model(test_factory, 3, [1.0, 1.03, 0.96], 7)
#optimize_model(test_model)

#7642.591774313989
#7947.963615260874
#7242.324576718763

# Result of calculate base cost: 22834.022837074648

best_solution, best_cost, best_models = decomposed_mpopf_local_search(search_factory, 3, ramping_data, demands)

if best_solution !== nothing
    println("Best cost: ", best_cost)
    for (i, model) in enumerate(best_models)
        println("Model $i status: ", termination_status(model.model))
        println("Model $i objective value: ", objective_value(model.model))
    end
else
    println("No feasible solution found.")
end
#=
Best solution found:
JuMP.Containers.DenseAxisArray{Float64, 2, Tuple{Base.OneTo{Int64}, Vector{Int64}}, Tuple{JuMP.Containers._AxisLookup{Base.OneTo{Int64}}, JuMP.Containers._AxisLookup{Dict{Int64, Int64}}}}[2-dimensional DenseAxisArray{Float64,2,...} with index sets:
    Dimension 1, Base.OneTo(1)
    Dimension 2, [5, 4, 2, 3, 1]
And data, a 1×5 Matrix{Float64}:
 -9.027553214591143e-9  -9.655743229410181e-9  0.3803230378347274  -8.95983976567728e-9  2.2096768494044303, 2-dimensional DenseAxisArray{Float64,2,...} with index sets:
    Dimension 1, Base.OneTo(1)
    Dimension 2, [5, 4, 2, 3, 1]
And data, a 1×5 Matrix{Float64}:
 -4.407706988873817e-9  -4.406015594435673e-9  0.391732727459049  -4.410630067551864e-9  2.2759671461187474, 2-dimensional DenseAxisArray{Float64,2,...} with index sets:
    Dimension 1, Base.OneTo(1)
    Dimension 2, [5, 4, 2, 3, 1]
And data, a 1×5 Matrix{Float64}:
 -1.2479344408017945e-8  -1.1066063151395185e-8  0.3651101158636349  -1.1570981241030826e-8  2.1212897727547033]
Best cost: 21613.064587807243
=#

#= 
We are allowed to generate more power than necassary
But not less than neccassary
This can be cheaper if ramping is particularly expensive
=#
