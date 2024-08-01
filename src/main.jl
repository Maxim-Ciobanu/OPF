#############################################################################
# Note: This file is curently being used for examples, nothing is permanent
#############################################################################

using PowerModels, JuMP, Ipopt#, Gurobi
include("MPOPF.jl")
include("misc.jl")
include("search_functions.jl")

using PowerModels, JuMP, Ipopt, Plots#, Gurobi
using .MPOPF

# Path to the case file
file_path = "./Cases/case300.m"

# Single Period Graphing Example for AC
# --------------------------------------------------------------------------
ac_factory = ACMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_AC_model_Graphing_single_period = create_model(ac_factory)
optimize_model_with_plot(My_AC_model_Graphing_single_period)
# --------------------------------------------------------------------------

# Multi Period Graphing Example for AC
ac_factory = ACMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_AC_model_Graphing_multi_period = create_model(ac_factory, 24, [1.0, 1.05, 0.98, 1.03, 0.96, 0.97, 0.99, 1.0, 1.05, 1.03, 1.01, 0.95, 1.04, 1.02, 0.99, 0.99, 0.99, 0.95, 1.04, 1.02, 0.98, 1.0, 1.02, 0.97], 2000)
optimize_model_with_plot(My_AC_model_Graphing_multi_period)
# --------------------------------------------------------------------------

# Example for DC with UncertaintyFactory
# --------------------------------------------------------------------------
load_scenarios_factors = generate_load_scenarios(1000, 14)
# Using DC Factory with Gurobi
dc_factory_Gurobi = DCMPOPFModelFactory(file_path, Gurobi.Optimizer)
My_DC_model_Uncertainty = create_model(dc_factory_Gurobi, load_scenarios_factors)
optimize_model(My_DC_model_Uncertainty)
# Output the final Pg Values
display(JuMP.value.(My_DC_model_Uncertainty.model[:pg]))
# --------------------------------------------------------------------------\

#
# Example for AC with feasibility check
# --------------------------------------------------------------------------
ac_factory = ACMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_AC_model = create_model(ac_factory)
optimize_model(My_AC_model)

# extract pg and qg value
new_pg_AC = value.(My_AC_model.model[:pg])
new_qg_AC = value.(My_AC_model.model[:qg])

# create new model with fixed pg and qg values
new_factory_AC = NewACMPOPFModelFactory(file_path, Ipopt.Optimizer)
New_Model_AC = create_model_check_feasibility(new_factory_AC, new_pg_AC, new_qg_AC)
optimize_model(New_Model_AC)


#
# Example for DC with feasibility check
# --------------------------------------------------------------------------
dc_factory = DCMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_DC_model = create_model(dc_factory)
optimize_model(My_DC_model)

# extract pg and qg value
new_pg_DC = value.(My_DC_model.model[:pg])
new_qg_DC = 0

# create new model with fixed pg and qg values
new_factory_DC = NewACMPOPFModelFactory(file_path, Ipopt.Optimizer)
New_Model_DC = create_model_check_feasibility(new_factory_DC, new_pg_DC, new_qg_DC)
optimize_model(New_Model_DC)


#
# Example for Linearization with feasibility check
# --------------------------------------------------------------------------
linear_factory = LinMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_Linear_model = create_model(linear_factory)
optimize_model(My_Linear_model)

# extract pg and qg value
new_pg_Lin = value.(My_Linear_model.model[:pg])
new_qg_Lin = value.(My_Linear_model.model[:qg])

# create new model with fixed pg and qg values
new_factory_Lin = NewACMPOPFModelFactory(file_path, Ipopt.Optimizer)
New_Model_Lin = create_model_check_feasibility(new_factory_Lin, new_pg_Lin, new_qg_Lin)
optimize_model(New_Model_Lin)



# --------------------------------------------------------------------------
# Check cost of each set_model_objective_function
# --------------------------------------------------------------------------


# AC
# calculate sum of x over sum of pg from inital model -> result shows feasibility
sum_x_AC = sum(value.(New_Model_AC.model[:x]))
sum_pg_AC = sum(new_pg_AC)
sum_total_AC = sum_x_AC / sum_pg_AC

# println("x:", value.(New_Model_AC.model[:x])) #sum should be 0.13
println("\nsum_x / sum_pg: ", sum_x_AC, " / ", sum_pg_AC, " = ", sum_total_AC)

# multiply value with cost
cost_AC = objective_value(New_Model_AC.model)
total_cost_AC = sum_total_AC * cost_AC
println("cost: ", cost_AC)
println("Total cost AC: ", total_cost_AC)



#DC
# calculate sum of x over sum of pg from inital model -> result shows feasibility
sum_x_DC = sum(value.(New_Model_DC.model[:x]))
sum_pg_DC = sum(new_pg_DC)
sum_total_DC = sum_x_DC / sum_pg_DC

# println("DC x:", value.(New_Model_DC.model[:x])) #sum should be 0.13
println("\nsum_x / sum_pg: ", sum_x_DC, " / ", sum_pg_DC, " = ", sum_total_DC)

# multiply value with cost
cost_DC = objective_value(New_Model_DC.model)
total_cost_DC = sum_total_DC * cost_DC
println("cost: ", cost_DC)
println("Total cost DC: ", total_cost_DC)



# Lin1
#calculate sum of x over sum of pg from inital model -> result shows feasibility
sum_x_Lin = sum(value.(New_Model_Lin.model[:x]))
sum_pg_Lin = sum(new_pg_Lin)
sum_total_Lin = sum_x_Lin / sum_pg_Lin

# println("x:", value.(New_Model_Lin.model[:x])) #sum should be 0.13
println("\nsum_x / sum_pg: ", sum_x_Lin, " / ", sum_pg_Lin, " = ", sum_total_Lin)

# multiply value with cost
cost_Lin = objective_value(New_Model_Lin.model)
total_cost_Lin = sum_total_Lin * cost_Lin
println("cost: ", cost_Lin)
println("Total cost Lin: ", total_cost_Lin)