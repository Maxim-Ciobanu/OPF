using PowerModels, JuMP, Ipopt, Gurobi
include("classes.jl")
using .MPOPF

file_path = "./Cases/case5.m"


# Example for AC
# --------------------------------------------------------------------------
ac_factory = ACPowerFlowModelFactory(file_path, Ipopt.Optimizer)
My_AC_model = create_model(ac_factory)
optimize_model(My_AC_model)
# --------------------------------------------------------------------------


# Example for DC
# --------------------------------------------------------------------------
dc_factory = DCPowerFlowModelFactory(file_path, Ipopt.Optimizer)
My_DC_model = create_model(dc_factory)
optimize_model(My_DC_model)
# --------------------------------------------------------------------------


# Example for AC with UncertaintyFactory
# --------------------------------------------------------------------------
load_scenarios_factors = Dict(
    1 => Dict(1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1),
    2 => Dict(1 => 1.001, 2 => 1.001, 3 => 1.003, 4 => 1.002, 5 => 1.001),
    3 => Dict(1 => 0.98, 2 => 0.99, 3 => 0.997, 4 => 0.998, 5 => 0.99)
)
# Using AC Factory from previous example
My_AC_model_Uncertainty = create_model(ac_factory, load_scenarios_factors)
optimize_model(My_AC_model_Uncertainty)
# --------------------------------------------------------------------------


# Example for DC with UncertaintyFactory
# --------------------------------------------------------------------------
load_scenarios_factors2 = Dict(
    1 => Dict(1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1),
    2 => Dict(1 => 1.03, 2 => 1.03, 3 => 1.03, 4 => 1.03, 5 => 1.03),
    3 => Dict(1 => 0.95, 2 => 0.95, 3 => 0.95, 4 => 0.95, 5 => 0.95)
)
# Using DC Factory but with Gurobi
dc_factory_Gurobi = DCPowerFlowModelFactory(file_path, Gurobi.Optimizer)
My_DC_model_Uncertainty = create_model(dc_factory_Gurobi, load_scenarios_factors2)
optimize_model(My_DC_model_Uncertainty)
# --------------------------------------------------------------------------
display(JuMP.value.(mu_minus))
