using JuMP, Ipopt, Gurobi, Serialization, Random
using PowerModels
using MPOPF
using Statistics
using CSV
using DataFrames

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


function populate_minmax(case::String, model::String, failures::Dict)

	# store all bus errors for specific case and model
	errors = []

	# get all keys that contain the string minmax ( sorry, python brain )
	keys(failures[case][model]) .|> fail-> if occursin("minmax", fail)
		failed_minmax_equations = failures[case][model][fail]

		# check that there are failed equations
		if length(failed_minmax_equations) > 0

			for equation in failed_minmax_equations

				# required for finding the closest bounding to which the value is to
				difference_lower = 99999999
				difference_upper = 99999999

				# calculate the difference to the lower bound
				if "lower bound" in keys(equation)
					difference_lower = abs(equation["value"] - equation["lower bound"])
				end
				
				# calculate the difference to upper bound
				if "upper bound" in keys(equation)
					difference_upper = abs(equation["value"] - equation["upper bound"])
				end

				# which bus is it closest to?
				push!(errors, min(difference_lower, difference_upper))
			end
		end
    end

	# reporting techniques listed below ( preferred largest as more specific )
	average = sum(errors; init=0) / length(errors) # get the average error over all buses for a specific case and model
	summation = sum(errors; init=0) # get the total of all the errors on the buses
	largest = maximum(errors; init=0) # get the single bus which has the largest error

	return largest
end

function populate_angle(case::String, model::String, failures::Dict)
	# store all bus errors for specific case and model
	errors = []
		
	# get all the keys that are related to active power balance equation
	keys(failures[case][model]) .|> fail->if occursin("powerbalance_va", fail)

		# get the power balance differences
		failed_angle_powerbalance_equation = failures[case][model][fail]

		# check if there are any violations
		if length(failed_angle_powerbalance_equation) > 0

			for item in failed_angle_powerbalance_equation

				# get the lhs
				lhs = item["lhs"]

				# get the rhs
				rhs = item["rhs_1"]
				
				# calculate the difference of the lhs and rhs and add it to the bus error array
				difference = abs(rhs-lhs)

				push!(errors, difference)
			end
		end
	end

	# reporting techniques listed below ( preferred largest as more specific )
	average = sum(errors; init=0) / length(errors)
	summation = sum(errors; init=0)
	largest = maximum(errors; init=0)


	return largest
end

function populate_active_power(case::String, model::String, failures::Dict)
	
	# store all bus errors for specific case and model
	errors = []
	
	# get all the keys that are related to active power balance equation
	keys(failures[case][model]) .|> fail->if occursin("powerbalance_active", fail)

		# get the power balance differences
		failed_active_powerbalance_equation = failures[case][model][fail]

		# check if there are any violations
		if length(failed_active_powerbalance_equation) > 0

			for item in failed_active_powerbalance_equation
				equation = string(item["equation"])

				# get the raw lhs value of the violating equation
				split_equation = split(equation, " == ")[1]
				cleaned_equation = strip(replace(split_equation, r"[\`]" => ""), ['`'])
				lhs = parse(Float64, cleaned_equation)

				# get the raw rhs value of the violating equation
				split_equation = split(equation, " == ")[2]
				cleaned_equation = strip(replace(split_equation, r"[\`]" => ""), ['`'])
				rhs = parse(Float64, cleaned_equation)
				
				# calculate the difference of the lhs and rhs and add it to the bus error array
				difference = abs(rhs-lhs)

				push!(errors, difference)
			end
		end
	end

	# reporting techniques listed below ( preferred largest as more specific )
	average = sum(errors; init=0) / length(errors)
	summation = sum(errors; init=0)
	largest = maximum(errors; init=0)


	return largest
end

function populate_reactive_power(case::String, model::String, failures::Dict)

	# store all bus errors for specific case and model
	errors = []

	# get all the keys that are related to active power balance equation
	keys(failures[case][model]) .|> fail->if occursin("powerbalance_reactive", fail)

		# get the power balance differences
		failed_active_powerbalance_equation = failures[case][model][fail]

		# check if there are any violations
		if length(failed_active_powerbalance_equation) > 0

			for item in failed_active_powerbalance_equation
				equation = string(item["equation"])

				# get the raw lhs value of the violating equation
				split_equation = split(equation, " == ")[1]
				cleaned_equation = strip(replace(split_equation, r"[\`]" => ""), ['`'])
				lhs = parse(Float64, cleaned_equation)

				# get the raw rhs value of the violating equation
				split_equation = split(equation, " == ")[2]
				cleaned_equation = strip(replace(split_equation, r"[\`]" => ""), ['`'])
				rhs = parse(Float64, cleaned_equation)
				
				# calculate the difference of the lhs and rhs and add it to the bus error array
				difference = abs(rhs-lhs)
				push!(errors, difference)
			end
		end
	end

	# reporting techniques listed below ( preferred largest as more specific )
	average = sum(errors; init=0) / length(errors)
	summation = sum(errors; init=0)
	largest = maximum(errors; init=0)

	return largest
end


# get failures dictionary
failures = deserialize_failures("output/failures/all_case_violations_dictionary.bin")
cases = load_and_compile_models("results")

# generate the graphs
failures_graph_power = Graph("output/graphs/failures_power.html")
failures_graph_reactive = Graph("output/graphs/failures_reactive.html")
failures_graph_minmax = Graph("output/graphs/failures_minmax.html")
failures_graph_angle = Graph("output/graphs/failures_angle.html")

# for the vertical infeasibility lines
let largest_mismatch_reactive = -1
let largest_mismatch_power = -1
let largest_mismatch_minmax = -1
let largest_mismatch_angle = -1

# models to look at
models = ["AC", "DC", "Logarithmic", "Quadratic", "Linear"]

let graph_style = 1

# go through models first
for model in models

	# collect the differences for all violations
	differences_minmax = []
	differences_power = []
	differences_reactive = []
	differences_angle = []

	# now iterate through each case
	for case in keys(failures)

		# push calculation made by each model
		push!(differences_power, populate_active_power(case, model, failures))
		push!(differences_reactive, populate_reactive_power(case, model, failures))
		push!(differences_minmax, populate_minmax(case, model, failures))
		push!(differences_angle, populate_angle(case, model, failures))
	end

	add_scatter(failures_graph_power, collect(keys(failures)), differences_power, model, graph_style)
	add_scatter(failures_graph_reactive, collect(keys(failures)), differences_reactive, model, graph_style)
	add_scatter(failures_graph_minmax, collect(keys(failures)), differences_minmax, model, graph_style)
	add_scatter(failures_graph_angle, collect(keys(failures)), differences_angle, model, graph_style)

	if maximum(differences_minmax) > largest_mismatch_minmax
		largest_mismatch_minmax = maximum(differences_minmax)
	end

	if maximum(differences_power) > largest_mismatch_power
		largest_mismatch_power = maximum(differences_power)
	end

	if maximum(differences_reactive) > largest_mismatch_reactive
		largest_mismatch_reactive = maximum(differences_reactive)
	end

	if maximum(differences_angle) > largest_mismatch_angle
		largest_mismatch_angle = maximum(differences_angle)
	end

	graph_style += 1

add_infeasible_cases(failures_graph_power, cases, largest_mismatch_power)
add_infeasible_cases(failures_graph_reactive, cases, largest_mismatch_reactive)
add_infeasible_cases(failures_graph_minmax, cases, largest_mismatch_minmax)
add_infeasible_cases(failures_graph_angle, cases, largest_mismatch_angle)
end
end
end
end
end
end


# create all plots
create_plot(failures_graph_power, "absolute difference in power balance equation of failed cases", "Case Number", "Abs Difference")
create_plot(failures_graph_reactive, "absolute difference in reactive power balance equation of failed cases", "Case Number", "Abs Difference")
create_plot(failures_graph_minmax, "absolute difference in minmax equation of failed cases", "Case Number", "Abs Difference ( average )")
create_plot(failures_graph_angle, "absolute difference in angle equation of failed cases", "Case Number", "Abs Difference ( average )")

# save them
save_graph(failures_graph_power)
save_graph(failures_graph_reactive)
save_graph(failures_graph_minmax)
save_graph(failures_graph_angle)