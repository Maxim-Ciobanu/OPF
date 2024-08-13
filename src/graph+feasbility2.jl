using PowerModels, JuMP, Ipopt, Plots#, Gurobi
include("MPOPF.jl")
include("misc.jl")
include("search_functions.jl")
include("graphing_class.jl")
using .MPOPF

# create enum for linear models
@enum MODEL_TYPE begin
	Undef=0
	Lin1=1
	Lin2=2
	Lin3=3
end

# extract the raw file names from cases folder, then add the path to file_paths array
file_strings = [string(i) for i in sort([parse(Int, join(filter(isdigit, collect(s)))) for s in readdir("./Cases")])]
file_paths = map((x) -> join(["./Cases/case", x, ".m"]), file_strings)

# create the graph object
feasability_graph = Graph("output/graphs/feasibility.html")
v_error_graph = Graph("output/graphs/v_error.html")
o_error_graph = Graph("output/graphs/o_error.html")



# a general function for executing a specific model and checking its feasability
# dc models have no vm values, so default to 1 and qg values are 0
# 
# factory: Union{ACMPOPFModelFactory, DCMPOPFModelFactory, LinMPOPFModelFactory} - the model factory to use
# model_type: MODEL_TYPE - the type of model to use
function generalised(factory::Union{ACMPOPFModelFactory, DCMPOPFModelFactory, LinMPOPFModelFactory}, path::String, model_type=false)

	costs = Dict()
	v_error = Dict()
	o_error = Dict()

	# check if the cost and error already exists


	# initiate and optimize the model
	model_type !== false ? model = create_model(factory; model_type=model_type) : model = create_model(factory)
	optimize_model(model)

	# extract the pg and qg values
	pg = value.(model.model[:pg])
	qg = factory isa DCMPOPFModelFactory ? 0 : value.(model.model[:qg])

	# create ac model with fixed pg and qg values
	ac_factory = NewACMPOPFModelFactory(path, Ipopt.Optimizer)
	ac_model = create_model_check_feasibility(ac_factory, pg, qg)
	optimize_model(ac_model)

	# get va values from the model ( it is horrible as bus indices are not always linearly increasing )
	val1 = value.(getindex.((pairs(cat(model.model[:va], dims=1)) |> collect)[1:length(model.model[:va])], 2))
	val2 = value.(getindex.((pairs(cat(ac_model.model[:va], dims=1)) |> collect)[1:length(ac_model.model[:va])], 2))
	new_o_error = abs(sum((val1 - val2) / val2))

	# get vm values from the model, dc models do not have vm values, so default to 1
	val3 = factory isa DCMPOPFModelFactory ? 0 : value.(getindex.((pairs(cat(model.model[:vm], dims=1)) |> collect)[1:length(model.model[:va])], 2))
	val4 = factory isa DCMPOPFModelFactory ? 0 : value.(getindex.((pairs(cat(ac_model.model[:vm], dims=1)) |> collect)[1:length(ac_model.model[:va])], 2))
	new_v_error = factory isa DCMPOPFModelFactory ? 1 : abs(sum((val3 - val4) / val4))

	# calculate sum of x over sum of pg from inital model to show feasibility
	sum_x = sum(value.(ac_model.model[:x]))
	sum_pg = sum(pg)
	sum_total = sum_x / sum_pg

	# multiply value with cost
	cost_Lin = objective_value(ac_model.model)
	total_cost = sum_total * cost_Lin

	# push the calculate values
	costs[path] = total_cost
	v_error[path] = new_v_error
	o_error[path] = new_o_error

	return costs, v_error, o_error
end


# initiate the different models arrays
ac_models = [[], [], []]
dc_models = [[], [], []]
lin1_models = [[], [], []]
lin2_models = [[], [], []]
lin3_models = [[], [], []]


# loop through all the cases
for path in file_paths
	println("Case: ", path)
	
	# create the model factories
	ac_factory = ACMPOPFModelFactory(path, Ipopt.Optimizer)
	dc_factory = DCMPOPFModelFactory(path, Ipopt.Optimizer)
	lin1_factory = LinMPOPFModelFactory(path, Ipopt.Optimizer)
	lin2_factory = LinMPOPFModelFactory(path, Ipopt.Optimizer)
	lin3_factory = LinMPOPFModelFactory(path, Ipopt.Optimizer)

	# get the cost of each model
	cost_ac, v_error_ac, o_error_ac = generalised(ac_factory, path)
	cost_dc, v_error_dc, o_error_dc = generalised(dc_factory, path)
	cost_lin_regular, v_error_lin_regular, o_error_lin_regular = generalised(lin1_factory, path, Lin1)
	cost_lin_quadratic, v_error_lin_quadratic, o_error_lin_quadratic = generalised(lin2_factory, path, Lin2)
	cost_lin_log, v_error_lin_log, o_error_lin_log = generalised(lin3_factory, path, Lin3)

	# add the nodes to the graph
	push!(ac_models[1], cost_ac); push!(ac_models[2], v_error_ac); push!(ac_models[3], o_error_ac)
	push!(dc_models[1], cost_dc); push!(dc_models[2], v_error_dc); push!(dc_models[3], o_error_dc)
	push!(lin1_models[1], cost_lin_regular); push!(lin1_models[2], v_error_lin_regular); push!(lin1_models[3], o_error_lin_regular)
	push!(lin2_models[1], cost_lin_quadratic); push!(lin2_models[2], v_error_lin_quadratic); push!(lin2_models[3], o_error_lin_quadratic)
	push!(lin3_models[1], cost_lin_log); push!(lin3_models[2], v_error_lin_log); push!(lin3_models[3], o_error_lin_log)
end

# save the data to the output folder
save("output/feasability_saved/ac/feasability", cost_ac); save("output/feasability_saved/ac/v_error", v_error_ac); save("output/feasability_saved/ac/o_error", o_error_ac)
save("output/feasability_saved/dc/feasability", cost_dc); save("output/feasability_saved/dc/v_error", v_error_dc); save("output/feasability_saved/dc/o_error", o_error_dc)
save("output/feasability_saved/lin1/feasability", cost_lin_regular); save("output/feasability_saved/lin1/v_error", v_error_lin_regular); save("output/feasability_saved/lin1/o_error", o_error_lin_regular)
save("output/feasability_saved/lin2/feasability", cost_lin_quadratic); save("output/feasability_saved/lin2/v_error", v_error_lin_quadratic); save("output/feasability_saved/lin2/o_error", o_error_lin_quadratic)
save("output/feasability_saved/lin3/feasability", cost_lin_log); save("output/feasability_saved/lin3/v_error", v_error_lin_log); save("output/feasability_saved/lin3/o_error", o_error_lin_log)
# TODO: write code here to save the computed error values to the file using this function

# add the traces to the feasability graph
add_scatter(feasability_graph, file_strings, [collect(values(i))[1] for i in ac_models[1]], "AC", "blue")
add_scatter(feasability_graph, file_strings, [collect(values(i))[1] for i in dc_models[1]], "DC", "red")
add_scatter(feasability_graph, file_strings, [collect(values(i))[1] for i in lin1_models[1]], "Lin1", "green")
add_scatter(feasability_graph, file_strings, [collect(values(i))[1] for i in lin2_models[1]], "Lin2", "yellow")
add_scatter(feasability_graph, file_strings, [collect(values(i))[1] for i in lin3_models[1]], "Lin3", "purple")

# add the traces to the v_error graph
add_scatter(v_error_graph, file_strings, [collect(values(i))[1] for i in ac_models[2]], "AC", "blue")
add_scatter(v_error_graph, file_strings, [collect(values(i))[1] for i in dc_models[2]], "DC", "red")
add_scatter(v_error_graph, file_strings, [collect(values(i))[1] for i in lin1_models[2]], "Lin1", "green")
add_scatter(v_error_graph, file_strings, [collect(values(i))[1] for i in lin2_models[2]], "Lin2", "yellow")
add_scatter(v_error_graph, file_strings, [collect(values(i))[1] for i in lin3_models[2]], "Lin3", "purple")

# add the traces to the o_error graph
add_scatter(o_error_graph, file_strings, [collect(values(i))[1] for i in ac_models[3]], "AC", "blue")
add_scatter(o_error_graph, file_strings, [collect(values(i))[1] for i in dc_models[3]], "DC", "red")
add_scatter(o_error_graph, file_strings, [collect(values(i))[1] for i in lin1_models[3]], "Lin1", "green")
add_scatter(o_error_graph, file_strings, [collect(values(i))[1] for i in lin2_models[3]], "Lin2", "yellow")
add_scatter(o_error_graph, file_strings, [collect(values(i))[1] for i in lin3_models[3]], "Lin3", "purple")

# create layouts
create_plot(feasability_graph, "Feasibility of Various Linearized Models", "Cases", "Costs")
create_plot(v_error_graph, "Voltage Magnitude ( Vm ) Error of Various Models", "Cases", "Magnitude Error")
create_plot(o_error_graph, "Voltage Angle ( Va ) Error of Various Models", "Cases", "Angle Error")

# save the graphs
save_graph(feasability_graph)
save_graph(v_error_graph)
save_graph(o_error_graph)