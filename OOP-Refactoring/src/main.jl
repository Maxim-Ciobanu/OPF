using PowerModels, JuMP, Ipopt, Gurobi
include("classes.jl")
using .MPOPF

file_path = "./Cases/case5.m"

ac_factory = MPOPF.ACPowerFlowModelFactory(file_path, Ipopt.Optimizer)

My_AC_model = create_model(ac_factory)

optimize_model(My_AC_model)


dc_factory = MPOPF.DCPowerFlowModelFactory(file_path, Ipopt.Optimizer)

My_DC_model = create_model(dc_factory)

optimize_model(My_DC_model)