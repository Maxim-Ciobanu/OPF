#############################################################################
# Note: This file is curently being used for testing, nothing is permanent
#############################################################################

using PowerModels, JuMP, Ipopt#, Gurobi
include("MPOPF.jl")
include("misc.jl")
include("search_functions.jl")
using .MPOPF

file_path = "./Cases/case300.m"


# Example for AC with feasibility check
# --------------------------------------------------------------------------
ac_factory = ACMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_AC_model = create_model(ac_factory)
optimize_model(My_AC_model)
#store pg and qg value
new_pg_AC = value.(My_AC_model.model[:pg])
new_qg_AC = value.(My_AC_model.model[:qg])

#new factory
new_factory_AC = NewACMPOPFModelFactory(file_path, Ipopt.Optimizer)
#new create model and pass through pg
New_Model_AC = create_model_check_feasibility(new_pg_AC, new_qg_AC, new_factory_AC)
#optimize
optimize_model(New_Model_AC)
# --------------------------------------------------------------------------



# Example for DC
# --------------------------------------------------------------------------
dc_factory = DCMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_DC_model = create_model(dc_factory)
optimize_model(My_DC_model)
#store pg and qg value
new_pg_DC = value.(My_DC_model.model[:pg])
new_qg_DC = 0

#new factory
new_factory_DC = NewACMPOPFModelFactory(file_path, Ipopt.Optimizer)
#new create model and pass through pg
New_Model_DC = create_model_check_feasibility(new_pg_DC, new_qg_DC, new_factory_DC)
#optimize
optimize_model(New_Model_DC)

# --------------------------------------------------------------------------



#
# Example for Linearization
# --------------------------------------------------------------------------
linear_factory = LinMPOPFModelFactory(file_path, Ipopt.Optimizer)
My_Linear_model = create_model(linear_factory)
optimize_model(My_Linear_model)
#store pg and qg value
new_pg_Lin = value.(My_Linear_model.model[:pg])
new_qg_Lin = value.(My_Linear_model.model[:qg])

#new factory
new_factory = NewACMPOPFModelFactory(file_path, Ipopt.Optimizer)
#new create model and pass through pg -> vectory of floats
New_Model = create_model_check_feasibility(new_factory, new_pg, new_qg)
new_factory_Lin = NewACMPOPFModelFactory(file_path, Ipopt.Optimizer)
#new create model and pass through pg
New_Model_Lin = create_model_check_feasibility(new_pg_Lin, new_qg_Lin, new_factory_Lin)
#optimize
optimize_model(New_Model_Lin)

# --------------------------------------------------------------------------
#

#=
# Example for AC with UncertaintyFactory
# --------------------------------------------------------------------------
ac_factory = ACMPOPFModelFactory(file_path, Ipopt.Optimizer)
load_scenarios_factors = load_scenarios_factors = generate_load_scenarios(3, 14)
# Using AC Factory from previous example
My_AC_model_Uncertainty = create_model(ac_factory, load_scenarios_factors)
optimize_model(My_AC_model_Uncertainty)
# -------------------------------------------------------------------------- 
=#

#=
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



### Check cost of each set_model_objective_function

# AC

#calculate sum of x over sum of pg from inital model -> result shows feasibility
sum_x_AC = sum(value.(New_Model_AC.model[:x]))
sum_pg_AC = sum(new_pg_AC)
sum_total_AC = sum_x_AC / sum_pg_AC
println("x:", value.(New_Model_AC.model[:x])) #sum should be 0.13
println("\nsum_x / sum_pg: ", sum_x_AC, " / ", sum_pg_AC, " = ", sum_total_AC)

#multiply value with cost
cost_AC = objective_value(New_Model_AC.model)
println("cost: ", cost_AC)
total_cost_AC = sum_total_AC * cost_AC
println("Total cost AC: ", total_cost_AC)

#DC

#calculate sum of x over sum of pg from inital model -> result shows feasibility
sum_x_DC = sum(value.(New_Model_DC.model[:x]))
sum_pg_DC = sum(new_pg_DC)
sum_total_DC = sum_x_DC / sum_pg_DC
println("DC x:", value.(New_Model_DC.model[:x])) #sum should be 0.13
println("\nsum_x / sum_pg: ", sum_x_DC, " / ", sum_pg_DC, " = ", sum_total_DC)

#multiply value with cost
cost_DC = objective_value(New_Model_DC.model)
println("cost: ", cost_DC)
total_cost_DC = sum_total_DC * cost_DC
println("Total cost DC: ", total_cost_DC)

#Lin1
#calculate sum of x over sum of pg from inital model -> result shows feasibility
sum_x_Lin = sum(value.(New_Model_Lin.model[:x]))
sum_pg_Lin = sum(new_pg_Lin)
sum_total_Lin = sum_x_Lin / sum_pg_Lin
println("x:", value.(New_Model_Lin.model[:x])) #sum should be 0.13
println("\nsum_x / sum_pg: ", sum_x_Lin, " / ", sum_pg_Lin, " = ", sum_total_Lin)

#multiply value with cost
cost_Lin = objective_value(New_Model_Lin.model)
println("cost: ", cost_Lin)