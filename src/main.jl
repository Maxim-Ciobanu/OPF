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

ramping_data = Dict(
    "ramp_limits" => [0.02, 0.01, 50, 50, 50],
    "costs" => [5, 1, 3, 4, 7]
)

demands = [
    [0.0, 0.217, 0.942, 0.478, 0.076, 0.112, 0.0, 0.0, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.0, 0.217, 0.942, 0.478, 0.076, 0.112, 0.0, 0.0, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.0, 0.217, 0.942, 0.478, 0.076, 0.112, 0.0, 0.0, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149]
]
demands[2] .*= 1.03
demands[3] .*= 0.96
# Total demand for initial case adjusted order=2 is 2.59
search_factory = DCMPOPFSearchFactory(file_path, Ipopt.Optimizer)
search_model = create_search_model(search_factory, 3, ramping_data, demands)
optimize_model(search_model)

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