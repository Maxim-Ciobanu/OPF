#############################################################################
# Note: Graphs the feasibility of a variety of models compared to the baseline: AC Model
#############################################################################

using PowerModels, JuMP, Ipopt#, Gurobi
include("MPOPF.jl")
include("misc.jl")
include("search_functions.jl")

using PowerModels, JuMP, Ipopt, Plots#, Gurobi
using .MPOPF

@enum MODEL_TYPE begin
	Undef=0
	Lin1=1
	Lin2=2
	Lin3=3
end

# Path to the case file
# file_path = "./Cases/case300.m"

file_strings = [string(i) for i in sort([parse(Int, join(filter(isdigit, collect(s)))) for s in readdir("./Cases")])]
file_paths = map((x) -> join(["./Cases/case", x, ".m"]), file_strings)

costs = Dict()
v_error = Dict()
o_error = Dict()

# create the graph object
feasability_graph = Graph("output/graphs/feasibility.html")
v_error_graph = Graph("output/graphs/v_error.html")
o_error_graph = Graph("output/graphs/o_error.html")


#=
# Example for AC
# --------------------------------------------------------------------------
for path in file_paths
	println(path)
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

	# calculate the error for va ( uses accurate indeces, fix for larger cases )
	val1 = value.(getindex.((pairs(cat(My_AC_model.model[:va], dims=1)) |> collect)[1:length(My_AC_model.model[:va])], 2))
	val2 = value.(getindex.((pairs(cat(New_Model_AC.model[:va], dims=1)) |> collect)[1:length(New_Model_AC.model[:va])], 2))

	val3 = value.(getindex.((pairs(cat(My_AC_model.model[:vm], dims=1)) |> collect)[1:length(My_AC_model.model[:va])], 2))
	val4 = value.(getindex.((pairs(cat(New_Model_AC.model[:vm], dims=1)) |> collect)[1:length(New_Model_AC.model[:va])], 2))

	o_error_AC = abs(sum((val1 - val2) / val2))
	v_error_AC = abs(sum((val3 - val4) / val4))

	# calculate sum of x over sum of pg from inital model -> result shows feasibility
	sum_x_AC = sum(value.(New_Model_AC.model[:x]))
	sum_pg_AC = sum(new_pg_AC)
	sum_total_AC = sum_x_AC / sum_pg_AC

	# multiply value with cost
	cost_AC = objective_value(New_Model_AC.model)
	total_cost_AC = sum_total_AC * cost_AC

	# push the calculate values
	push!(costs, total_cost_AC)
	push!(v_error, v_error_AC)
	push!(o_error, o_error_AC)
end
#


add_scatter(feasability_graph, file_strings , costs, "AC", "black")
add_scatter(v_error_graph, file_strings , v_error, "Va Error AC", "black")
add_scatter(o_error_graph, file_strings , o_error, "Vm Error AC", "black")

output_to_file(join([string(costs), string(v_error), string(o_error)], "\n"), "feasibility.txt")

costs = []
v_error = []
o_error = []



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

	# create new model with fixed pg and qg values and optimize
	new_factory_DC = NewACMPOPFModelFactory(path, Ipopt.Optimizer)
	New_Model_DC = create_model_check_feasibility(new_factory_DC, new_pg_DC, new_qg_DC)
	optimize_model(New_Model_DC)

	# calculate the error for va ( uses accurate indeces, fix for larger cases )
	val1 = value.(getindex.((pairs(cat(My_DC_model.model[:va], dims=1)) |> collect)[1:length(My_DC_model.model[:va])], 2))
	val2 = value.(getindex.((pairs(cat(New_Model_DC.model[:va], dims=1)) |> collect)[1:length(New_Model_DC.model[:va])], 2))

	# val3 = value.(getindex.((pairs(cat(My_DC_model.model[:vm], dims=1)) |> collect)[1:length(My_DC_model.model[:va])], 2))
	# val4 = value.(getindex.((pairs(cat(New_Model_DC.model[:vm], dims=1)) |> collect)[1:length(New_Model_DC.model[:va])], 2))

	o_error_DC = abs(sum((val1 - val2) / val2))
	v_error_DC = 1

	# calculate sum of x over sum of pg from inital model -> result shows feasibility
	sum_x_DC = sum(value.(New_Model_DC.model[:x]))
	sum_pg_DC = sum(new_pg_DC)
	sum_total_DC = sum_x_DC / sum_pg_DC

	# multiply value with cost
	cost_DC = objective_value(New_Model_DC.model)
	total_cost_DC = sum_total_DC * cost_DC
	
	# push the calculate values
	push!(costs, total_cost_DC)
	push!(v_error, v_error_DC)
	push!(o_error, o_error_DC)
end


add_scatter(feasability_graph, file_strings , costs, "DC", "blue")
add_scatter(v_error_graph, file_strings , v_error, "Va Error DC", "blue")
add_scatter(o_error_graph, file_strings , o_error, "Vm Error DC", "blue")

output_to_file(join([string(costs), string(v_error), string(o_error)], "\n"), "feasibility.txt")

costs = []
v_error = []
o_error = []
=#

#
# Example for Linearization 1
# --------------------------------------------------------------------------
for path in file_paths

	# select the model type to use ( Lin1, Lin2, Lin3 )
	model_type::MODEL_TYPE = Lin1 

	# initiate and optimize the linear model
	linear_factory = LinMPOPFModelFactory(path, Ipopt.Optimizer)
	My_Linear_model = create_model(linear_factory; model_type=model_type)
	optimize_model(My_Linear_model)

	# extract pg and qg value
	new_pg_Lin = value.(My_Linear_model.model[:pg])
	new_qg_Lin = value.(My_Linear_model.model[:qg])

	# create new model with fixed pg and qg values
	new_factory_Lin = NewACMPOPFModelFactory(path, Ipopt.Optimizer)
	New_Model_Lin = create_model_check_feasibility(new_factory_Lin, new_pg_Lin, new_qg_Lin)
	optimize_model(New_Model_Lin)


	# calculate the error for va, vm ( uses accurate indices to fix for larger cases )
	val1 = value.(getindex.((pairs(cat(My_Linear_model.model[:va], dims=1)) |> collect)[1:length(My_Linear_model.model[:va])], 2))
	val2 = value.(getindex.((pairs(cat(New_Model_Lin.model[:va], dims=1)) |> collect)[1:length(New_Model_Lin.model[:va])], 2))

	val3 = value.(getindex.((pairs(cat(My_Linear_model.model[:vm], dims=1)) |> collect)[1:length(My_Linear_model.model[:va])], 2))
	val4 = value.(getindex.((pairs(cat(New_Model_Lin.model[:vm], dims=1)) |> collect)[1:length(New_Model_Lin.model[:va])], 2))

	o_error_Lin = abs(sum((val1 - val2) / val2))
	v_error_Lin = abs(sum((val3 - val4) / val4))

	#calculate sum of x over sum of pg from inital model -> result shows feasibility
	sum_x_Lin = sum(value.(New_Model_Lin.model[:x]))
	sum_pg_Lin = sum(new_pg_Lin)
	sum_total_Lin = sum_x_Lin / sum_pg_Lin

	# multiply value with cost
	cost_Lin = objective_value(New_Model_Lin.model)
	total_cost_Lin = sum_total_Lin * cost_Lin

	# push the calculate values
	costs[path] = total_cost_Lin
	v_error[path] = v_error_Lin
	o_error[path] = o_error_Lin
end

# save calculated values
output_to_file(join([string(costs), string(v_error), string(o_error)], "\n"), "output.txt", true)
save("output/feasability_saved/lin1/feasability", costs)
save("output/feasability_saved/lin1/v_error", v_error)
save("output/feasability_saved/lin1/o_error", o_error)

# convert dictionary values to arrays
costs = [costs[i] for i in keys(costs)]
v_error = [v_error[i] for i in keys(v_error)]
o_error = [o_error[i] for i in keys(o_error)]

add_scatter(feasability_graph, file_strings , costs, "Lin1", "green")
add_scatter(v_error_graph, file_strings , v_error, "Vm Error Lin1", "green")
add_scatter(o_error_graph, file_strings , o_error, "Va Error Lin1", "green")

costs = Dict()
v_error = Dict()
o_error = Dict()


# Example for Linearization 2
# --------------------------------------------------------------------------
for path in file_paths

	# select the model type to use ( Lin1, Lin2, Lin3 )
	model_type::MODEL_TYPE = Lin2

	# initiate and optimize the linear model
	linear_factory = LinMPOPFModelFactory(path, Ipopt.Optimizer)
	My_Linear_model = create_model(linear_factory; model_type=model_type)
	optimize_model(My_Linear_model)

	# extract pg and qg value
	new_pg_Lin = value.(My_Linear_model.model[:pg])
	new_qg_Lin = value.(My_Linear_model.model[:qg])

	# create new model with fixed pg and qg values
	new_factory_Lin = NewACMPOPFModelFactory(path, Ipopt.Optimizer)
	New_Model_Lin = create_model_check_feasibility(new_factory_Lin, new_pg_Lin, new_qg_Lin)
	optimize_model(New_Model_Lin)


	# calculate the error for va, vm ( uses accurate indices to fix for larger cases )
	val1 = value.(getindex.((pairs(cat(My_Linear_model.model[:va], dims=1)) |> collect)[1:length(My_Linear_model.model[:va])], 2))
	val2 = value.(getindex.((pairs(cat(New_Model_Lin.model[:va], dims=1)) |> collect)[1:length(New_Model_Lin.model[:va])], 2))

	val3 = value.(getindex.((pairs(cat(My_Linear_model.model[:vm], dims=1)) |> collect)[1:length(My_Linear_model.model[:va])], 2))
	val4 = value.(getindex.((pairs(cat(New_Model_Lin.model[:vm], dims=1)) |> collect)[1:length(New_Model_Lin.model[:va])], 2))

	o_error_Lin = abs(sum((val1 - val2) / val2))
	v_error_Lin = abs(sum((val3 - val4) / val4))

	#calculate sum of x over sum of pg from inital model -> result shows feasibility
	sum_x_Lin = sum(value.(New_Model_Lin.model[:x]))
	sum_pg_Lin = sum(new_pg_Lin)
	sum_total_Lin = sum_x_Lin / sum_pg_Lin

	# multiply value with cost
	cost_Lin = objective_value(New_Model_Lin.model)
	total_cost_Lin = sum_total_Lin * cost_Lin

	# push the calculate values
	costs[path] = total_cost_Lin
	v_error[path] = v_error_Lin
	o_error[path] = o_error_Lin
end

# save calculated values
output_to_file(join([string(costs), string(v_error), string(o_error)], "\n"), "output.txt")
save("output/feasability_saved/lin2/feasability", costs)
save("output/feasability_saved/lin2/v_error", v_error)
save("output/feasability_saved/lin2/o_error", o_error)

# convert dictionary values to arrays
costs = [costs[i] for i in keys(costs)]
v_error = [v_error[i] for i in keys(v_error)]
o_error = [o_error[i] for i in keys(o_error)]

add_scatter(feasability_graph, file_strings , costs, "Quadratic Linearization", "blue")
add_scatter(v_error_graph, file_strings , v_error, "Vm Error Quadratic Linearization", "blue")
add_scatter(o_error_graph, file_strings , o_error, "Va Error Quadratic Linearization", "blue")

costs = Dict()
v_error = Dict()
o_error = Dict()


# Example for Linearization 3
# --------------------------------------------------------------------------
for path in file_paths

	# select the model type to use ( Lin1, Lin2, Lin3 )
	model_type::MODEL_TYPE = Lin3

	# initiate and optimize the linear model
	linear_factory = LinMPOPFModelFactory(path, Ipopt.Optimizer)
	My_Linear_model = create_model(linear_factory; model_type=model_type)
	optimize_model(My_Linear_model)

	# extract pg and qg value
	new_pg_Lin = value.(My_Linear_model.model[:pg])
	new_qg_Lin = value.(My_Linear_model.model[:qg])

	# create new model with fixed pg and qg values
	new_factory_Lin = NewACMPOPFModelFactory(path, Ipopt.Optimizer)
	New_Model_Lin = create_model_check_feasibility(new_factory_Lin, new_pg_Lin, new_qg_Lin)
	optimize_model(New_Model_Lin)


	# calculate the error for va, vm ( uses accurate indices to fix for larger cases )
	val1 = value.(getindex.((pairs(cat(My_Linear_model.model[:va], dims=1)) |> collect)[1:length(My_Linear_model.model[:va])], 2))
	val2 = value.(getindex.((pairs(cat(New_Model_Lin.model[:va], dims=1)) |> collect)[1:length(New_Model_Lin.model[:va])], 2))

	val3 = value.(getindex.((pairs(cat(My_Linear_model.model[:vm], dims=1)) |> collect)[1:length(My_Linear_model.model[:va])], 2))
	val4 = value.(getindex.((pairs(cat(New_Model_Lin.model[:vm], dims=1)) |> collect)[1:length(New_Model_Lin.model[:va])], 2))

	o_error_Lin = abs(sum((val1 - val2) / val2))
	v_error_Lin = abs(sum((val3 - val4) / val4))

	#calculate sum of x over sum of pg from inital model -> result shows feasibility
	sum_x_Lin = sum(value.(New_Model_Lin.model[:x]))
	sum_pg_Lin = sum(new_pg_Lin)
	sum_total_Lin = sum_x_Lin / sum_pg_Lin

	# multiply value with cost
	cost_Lin = objective_value(New_Model_Lin.model)
	total_cost_Lin = sum_total_Lin * cost_Lin

	# push the calculate values
	costs[path] = total_cost_Lin
	v_error[path] = v_error_Lin
	o_error[path] = o_error_Lin
end


# save calculated values
output_to_file(join([string(costs), string(v_error), string(o_error)], "\n"), "output.txt")
save("output/feasability_saved/lin3/feasability", costs)
save("output/feasability_saved/lin3/v_error", v_error)
save("output/feasability_saved/lin3/o_error", o_error)

# convert dictionary values to arrays
costs = [costs[i] for i in keys(costs)]
v_error = [v_error[i] for i in keys(v_error)]
o_error = [o_error[i] for i in keys(o_error)]

# add and create the feasability graph
add_scatter(feasability_graph, file_strings , costs, "Quadratic Logarithmic Linearization", "red")
create_plot(feasability_graph, "Feasibility of Various Linearized Models", "Cases", "Costs")
save_graph(feasability_graph)

# add and create the v_error graph
add_scatter(v_error_graph, file_strings , v_error, "Va Error Logarithmic Linearization", "red")
create_plot(v_error_graph, "Error of Voltage Magnitude ( vm ) for Various Linearized Models", "Cases", "Error")
save_graph(v_error_graph)

# add and create the o_error graph
add_scatter(o_error_graph, file_strings , o_error, "Vm Error Logarithmic Linearization", "red")
create_plot(o_error_graph, "Error of Voltage Angle ( va ) for Various Linearized Models", "Cases", "Error")
save_graph(o_error_graph)
#