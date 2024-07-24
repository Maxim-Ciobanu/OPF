#############################################################################
# Note: This file is curently being used for testing, nothing is permanent
#############################################################################

using PowerModels, JuMP, Ipopt#, Gurobi
include("MPOPF.jl")
include("misc.jl")
include("search_functions.jl")
using .MPOPF

file_path = "./Cases/case14.m"


# Example for AC with feasibility check
# --------------------------------------------------------------------------
ac_factory = ACMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_AC_model = create_model(ac_factory)
optimize_model(My_AC_model)
#store pg value
new_pg = value.(My_AC_model.model[:pg])
#new factory
new_factory = NewACMPOPFModelFactory(file_path, Ipopt.Optimizer)
#new create model and pass through pg -> vectory of floats
New_Model = create_model_check_feasibility(new_pg, new_factory)
#optimize
optimize_model(New_Model)
# --------------------------------------------------------------------------


#=
# Example for DC
# --------------------------------------------------------------------------
dc_factory = DCMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_DC_model = create_model(dc_factory)
optimize_model(My_DC_model)
# --------------------------------------------------------------------------
=#

#=
# Example for Linearization
# --------------------------------------------------------------------------
linear_factory = LinMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_Linear_model = create_model(linear_factory)
optimize_model(My_Linear_model)
# --------------------------------------------------------------------------
=#

#=
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

