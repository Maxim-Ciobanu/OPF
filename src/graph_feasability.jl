#############################################################################
# Note: Graphs the feasibility of a variety of models compared to the baseline: AC Model
#############################################################################

using PowerModels, JuMP, Ipopt#, Gurobi
include("MPOPF.jl")
include("misc.jl")
include("search_functions.jl")

using PowerModels, JuMP, Ipopt, Plots#, Gurobi
using .MPOPF

# Path to the case file
file_path = "./Cases/case300.m"

file_strings = [string(i) for i in sort([parse(Int, join(filter(isdigit, collect(s)))) for s in readdir("./Cases")])]
file_paths = map((x) -> join(["./Cases/case", x, ".m"]), file_strings)
costs = []

# create the graph object
graph = Graph("output/graphs/feasibility.html")


#
# Example for AC
# --------------------------------------------------------------------------
for path in file_paths
	ac_factory = ACMPOPFModelFactory(path, Ipopt.Optimizer)
	My_AC_model = create_model(ac_factory)
	optimize_model(My_AC_model)

	# extract pg and qg value
	new_pg_AC = value.(My_AC_model.model[:pg])
	new_qg_AC = value.(My_AC_model.model[:qg])

	# create new model with fixed pg and qg values
	new_factory_AC = NewACMPOPFModelFactory(path, Ipopt.Optimizer)
	New_Model_AC = create_model_check_feasibility(new_factory_AC, new_pg_AC, new_qg_AC)
	optimize_model(New_Model_AC)

	# calculate sum of x over sum of pg from inital model -> result shows feasibility
	sum_x_AC = sum(value.(New_Model_AC.model[:x]))
	sum_pg_AC = sum(new_pg_AC)
	sum_total_AC = sum_x_AC / sum_pg_AC

	# println("x:", value.(New_Model_AC.model[:x])) #sum should be 0.13
	# println("\nsum_x / sum_pg: ", sum_x_AC, " / ", sum_pg_AC, " = ", sum_total_AC)

	# multiply value with cost
	cost_AC = objective_value(New_Model_AC.model)
	total_cost_AC = sum_total_AC * cost_AC
	# println("cost: ", cost_AC)
	# println("Total cost AC: ", total_cost_AC)

	push!(costs, total_cost_AC)
end
#

add_scatter(graph, file_strings , costs, "AC", "black")
output_to_file(string(costs), "feasibility.txt")
costs = []

#
# [0.002135197065975893, 0.010619853065362107, 0.0024629703539908515, 0.6285990253234969]
# Example for DC
# --------------------------------------------------------------------------
for path in file_paths
	dc_factory = DCMPOPFModelFactory(path, Ipopt.Optimizer)
	My_DC_model = create_model(dc_factory)
	optimize_model(My_DC_model)

	# extract pg and qg value
	new_pg_DC = value.(My_DC_model.model[:pg])
	new_qg_DC = 0

	# create new model with fixed pg and qg values
	new_factory_DC = NewACMPOPFModelFactory(path, Ipopt.Optimizer)
	New_Model_DC = create_model_check_feasibility(new_factory_DC, new_pg_DC, new_qg_DC)
	optimize_model(New_Model_DC)

	# calculate sum of x over sum of pg from inital model -> result shows feasibility
	sum_x_DC = sum(value.(New_Model_DC.model[:x]))
	sum_pg_DC = sum(new_pg_DC)
	sum_total_DC = sum_x_DC / sum_pg_DC

	# println("DC x:", value.(New_Model_DC.model[:x])) #sum should be 0.13
	# println("\nsum_x / sum_pg: ", sum_x_DC, " / ", sum_pg_DC, " = ", sum_total_DC)

	# multiply value with cost
	cost_DC = objective_value(New_Model_DC.model)
	total_cost_DC = sum_total_DC * cost_DC
	# println("cost: ", cost_DC)
	# println("Total cost DC: ", total_cost_DC)
	push!(costs, total_cost_DC)
end
#

add_scatter(graph, file_strings , costs, "DC", "blue")
output_to_file(string(costs), "feasibility.txt")
costs = []

# [5.334018480403487e-22, 7.634077829776435e-9, 6.170849831534511e-6, 0.17723335432234452]
# Example for Linearization 
# --------------------------------------------------------------------------
for path in file_paths
	linear_factory = LinMPOPFModelFactory(path, Ipopt.Optimizer)
	My_Linear_model = create_model(linear_factory)
	optimize_model(My_Linear_model)

	# extract pg and qg value
	new_pg_Lin = value.(My_Linear_model.model[:pg])
	new_qg_Lin = value.(My_Linear_model.model[:qg])

	# create new model with fixed pg and qg values
	new_factory_Lin = NewACMPOPFModelFactory(path, Ipopt.Optimizer)
	New_Model_Lin = create_model_check_feasibility(new_factory_Lin, new_pg_Lin, new_qg_Lin)
	optimize_model(New_Model_Lin)

	# Lin1
	#calculate sum of x over sum of pg from inital model -> result shows feasibility
	sum_x_Lin = sum(value.(New_Model_Lin.model[:x]))
	sum_pg_Lin = sum(new_pg_Lin)
	sum_total_Lin = sum_x_Lin / sum_pg_Lin

	# println("x:", value.(New_Model_Lin.model[:x])) #sum should be 0.13
	# println("\nsum_x / sum_pg: ", sum_x_Lin, " / ", sum_pg_Lin, " = ", sum_total_Lin)

	# multiply value with cost
	cost_Lin = objective_value(New_Model_Lin.model)
	total_cost_Lin = sum_total_Lin * cost_Lin
	# println("cost: ", cost_Lin)
	# println("Total cost Lin: ", total_cost_Lin)

	push!(costs, total_cost_Lin)
end
#

output_to_file(string(costs), "feasibility.txt")
add_scatter(graph, file_strings , costs, "Quadratic Lin", "red")
create_plot(graph, "Feasibility of Various Linearized Models", "Cases", "Costs")
save_graph(graph)

