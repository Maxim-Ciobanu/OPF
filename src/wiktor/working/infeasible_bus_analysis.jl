using JuMP, Ipopt, Gurobi, Serialization, Random
using PowerModels
using MPOPF
using Statistics
using CSV
using DataFrames

#=

This file will compute the quantity of buses that are violated for each case and for each model
=#

# load in the data
function deserialize_failures(filename)
	return deserialize(filename)
end


function add_infeasible_cases(graph::Graph, cases, largest_mismatch)

	# add vertical lines to show infeasible cases
	for case in keys(cases)

		# for each case check if at least one of the models is infeasible
		infeasible = false
		limit = false

		# determine if any of the cases failed
		for model_type in keys(cases[case])

			# get the model and termination criteria
			model = cases[case][model_type].model
			termination = termination_status(model)

			# find if infeasible
			if termination == LOCALLY_INFEASIBLE
				infeasible = true
			end

			if termination == ITERATION_LIMIT
				limit = true
			end
		end

		# if any of the models are infeasible show it
		if infeasible
			add_vertical_line(graph, case, largest_mismatch)
		end

		if limit
			add_vertical_line(graph, case, largest_mismatch) # add colour
		end
	end
end

function populate_bus_quantities(case, model, failures)
	# count how many buses fail here
	count = 0
	
	for items in failures[case][model]
		println(items)
		count += length(items)
	end

	return count
end


# get failures dictionary
failures = deserialize_failures("output/failures/all_case_violations_dictionary.bin")
cases = load_and_compile_models("results") # must be the same as the original executed cases, might add it to the serialized object perhaps

# generate the graphs
failures_graph_bus_quantity = Graph("output/graphs/failures_buses.html")


# for the vertical infeasibility lines
let largest_bus_quantity = -1


# models to look at
models = ["AC", "DC", "Logarithmic", "Quadratic", "Linear"]

let graph_style = 1

# go through models first
for model in models

	# collect the differences for all violations
	bus_quantities = []

	# now iterate through each case
	for case in keys(failures)

		# push calculation made by each model
		push!(bus_quantities, populate_bus_quantities(case, model, failures))
	end

	add_scatter(failures_graph_bus_quantity, collect(keys(failures)), bus_quantities, model, graph_style)

	# find the highest point in the graph for the infeasibility line
	if maximum(bus_quantities) > largest_bus_quantity
		largest_bus_quantity = maximum(bus_quantities)
	end

	# change color for each model
	graph_style += 1

add_infeasible_cases(failures_graph_bus_quantity, cases, largest_bus_quantity)
end
end
end


# create all plots
create_plot(failures_graph_bus_quantity, "Quantity of failing buses per model", "Case Number", "Count")

# save them
save_graph(failures_graph_bus_quantity)
