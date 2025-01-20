using JuMP, Ipopt, Gurobi, Serialization, Random
using PowerModels
using MPOPF
using Statistics
using CSV
using DataFrames

cases = load_and_compile_models("results/")

failures = Dict{String, Dict{String, Any}}()

total_cases = length(cases)
let count = 1


# go over every case
for case_name in keys(cases) 	
	println("performing - $case_name \t $count / $total_cases")
	count += 1

	# initialise case names failures
	failures[case_name] = Dict{String, Any}()

	# go over every model per case
	for model_name in keys(cases[case_name])

		# initialise case names failures
		failures[case_name][model_name] = Dict{String, Any}()

		# get model data that applies to all models regardless of type
		power_flow_model = cases[case_name][model_name]
		model = power_flow_model.model

		data = power_flow_model.data
		T = power_flow_model.time_periods

		ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]

		gen_data = ref[:gen]
		bus_data = ref[:bus]

		branch_data = ref[:branch]
		load_data = ref[:load]

		# DC model
		if model_name == "DC"

			# extract model variables
			va = model[:va]
			p = model[:p]
			pg = model[:pg]
			factors = power_flow_model.factors
			ramp_up = model[:ramp_up]
			ramp_down = model[:ramp_down]

			# do something here
			p_expr = Dict()
	
			for t in 1:T
				p_expr[t] = Dict()
			end

			for t in 1:T
				p_expr[t] = Dict([((l, i, j), 1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs_from]])
				p_expr[t] = merge(p_expr[t], Dict([((l, j, i), -1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs_from]]))
			end

			

			for t in 1:T

				power_failures = []
				reactive_failures = []

				for (i, bus) in ref[:bus]
					bus_loads = [load_data[l] for l in ref[:bus_loads][i]]
            		bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]

					# @constraint(model,
					# sum(p_expr[t][a] for a in ref[:bus_arcs][i]) ==
					# sum(pg[t, g] for g in ref[:bus_gens][i]) -
					# sum(load["pd"] * factors[t] for load in bus_loads) -
					# sum(shunt["gs"] for shunt in bus_shunts)*1.0^2
					lhs = sum(value(p_expr[t][a]) for a in ref[:bus_arcs][i]; init=0)
					rhs_1 = sum(value(pg[t, g]) for g in ref[:bus_gens][i]; init=0)
					rhs_2 = sum(load["pd"] * factors[t] for load in bus_loads; init=0)
					rhs_3 = sum(shunt["gs"] for shunt in bus_shunts; init=0)*1.0^2

					if lhs == rhs_1 - rhs_2 - rhs_3
						continue
					else
						failure = Dict{String, Any}("t" => t,
							"i" => i,
							"bus" => bus,
							"lhs" => lhs,
							"rhs_1" => rhs_1,
							"rhs_2" => rhs_2,
							"rhs_3" => rhs_3,
							"equation_expanded" => `$lhs == $rhs_1 - $rhs_2 - $rhs_3`,
							"equation" => `$lhs == $(rhs_1 - rhs_2 - rhs_3)`
						)
						
						push!(power_failures, failure)
					end
				end

				failures[case_name][model_name]["Power-Balance-Equation"] = power_failures
			end
		end

		# all other models
		if model_name == "AC" || model_name == "Quadratic" || model_name == "Logarithmic" || model_name == "Linear" 

			# get model data necessary for checking
			va = model[:va]
			p = model[:p]
			q = model[:q]
			pg = model[:pg]
			qg = model[:qg]
			vm = model[:vm]
			ramp_up = model[:ramp_up]
			ramp_down = model[:ramp_down]
			
			factors = power_flow_model.factors

			# perform power balance equation checks
			for t in 1:T # REMEMBER IF T IS MORE THIS CODE WILL OVERWRITE

				# a list to keep track of failures
				power_failures = []
				reactive_failures = []

				for (i, bus) in ref[:bus]
					bus_loads = [load_data[l] for l in ref[:bus_loads][i]]
            		bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]

					# @constraint(model,
					#     sum(p[t,a] for a in ref[:bus_arcs][i]) ==
					#     sum(pg[t, g] for g in ref[:bus_gens][i]) -
					#     sum(load["pd"] * factors[t] for load in bus_loads) -
					#     sum(shunt["gs"] for shunt in bus_shunts)*vm[t,i]^2
					# )
					lhs = sum(value(p[t,a]) for a in ref[:bus_arcs][i]; init=0)
					rhs_1 = sum(value(pg[t, g]) for g in ref[:bus_gens][i]; init=0)
					rhs_2 = sum(load["pd"] * factors[t] for load in bus_loads; init=0)
					rhs_3 = sum(shunt["gs"] for shunt in bus_shunts; init=0)*(value(vm[t,i])^2)

					if lhs == rhs_1 - rhs_2 - rhs_3
						continue
					else
						failure = Dict{String, Any}("t" => t,
							"i" => i,
							"bus" => bus,
							"lhs" => lhs,
							"rhs_1" => rhs_1,
							"rhs_2" => rhs_2,
							"rhs_3" => rhs_3,
							"equation_expanded" => `$lhs == $rhs_1 - $rhs_2 + $rhs_3`,
							"equation" => `$lhs == $(rhs_1 - rhs_2 + rhs_3)`
						)
						
						push!(power_failures, failure)
					end

					# @constraint(model,
					#     sum(q[t,a] for a in ref[:bus_arcs][i]) ==
					#     sum(qg[t, g] for g in ref[:bus_gens][i]) -
					#     sum(load["qd"] * factors[t] for load in bus_loads) +
					#     sum(shunt["bs"] for shunt in bus_shunts)*vm[t,i]^2
					# )
					lhs = sum(value(q[t,a]) for a in ref[:bus_arcs][i]; init=0)
					rhs_1 = sum(value(qg[t, g]) for g in ref[:bus_gens][i]; init=0)
					rhs_2 = sum(load["pd"] * factors[t] for load in bus_loads; init=0)
					rhs_3 = sum(shunt["bs"] for shunt in bus_shunts; init=0)*(value(vm[t,i])^2)

					if lhs == rhs_1 - rhs_2 + rhs_3
						continue
					else
						failure = Dict{String, Any}("t" => t,
							"i" => i,
							"bus" => bus,
							"lhs" => lhs,
							"rhs_1" => rhs_1,
							"rhs_2" => rhs_2,
							"rhs_3" => rhs_3,
							"equation_expanded" => `$lhs == $rhs_1 - $rhs_2 + $rhs_3`,
							"equation" => `$lhs == $(rhs_1 - rhs_2 + rhs_3)`
						)
						
						push!(reactive_failures, failure)
					end
				end

				failures[case_name][model_name]["Power-Balance-Equation"] = power_failures
				failures[case_name][model_name]["Reactive-Power-Balance-Equation"] = reactive_failures
			end
		end
	end
end
end

#=
# variable dictionary 
map_variables_DC = Dict{String, Any}(
	"Power-Balance-Equation" => ["p", "pg"],
)

map_variables_AC = Dict{String, Any}(
	"Power-Balance-Equation" => ["p", "pg", "vm"],
	"Reactive-Power-Balance-Equation" => ["q", "qg", "vm"],
)

counts = Dict{String, Dict{String, Int64}}(
	"DC" => Dict{String, Int64}(
		"p" => 0,
		"q" => 0,
		"pg" => 0,
		"qg" => 0,
		"vm" => 0,
	),
	"AC" => Dict{String, Int64}(
		"p" => 0,
		"q" => 0,
		"pg" => 0,
		"qg" => 0,
		"vm" => 0,
	),
	"Logarithmic" => Dict{String, Int64}(
		"p" => 0,
		"q" => 0,
		"pg" => 0,
		"qg" => 0,
		"vm" => 0,
	),
	"Quadratic" => Dict{String, Int64}(
		"p" => 0,
		"q" => 0,
		"pg" => 0,
		"qg" => 0,
		"vm" => 0,
	),
	"Linear" => Dict{String, Int64}(
		"p" => 0,
		"q" => 0,
		"pg" => 0,
		"qg" => 0,
		"vm" => 0,
	),
)

# Find the variables which cause the most mismatches
for case in keys(failures)
	for model in keys(failures[case])
		

		# go through each min max failure and ammend the counts
		for failure in keys(failures[case][model])
			fail = failures[case][model][failure]

			# only look when data is available
			if length(fail) > 0
				if model == "DC"
					for variable in map_variables_DC[failure]
						counts["DC"][variable] += length(fail)
					end
				else
					for variable in map_variables_AC[failure]
						counts[model][variable] += length(fail)
					end
				end
			end
		end
	end
end
=#



# Take the powerbalance dictionary of failures created above and then process the mismatches into a graph
# options include ( on a model by case basis ) for the buses
# 	- average ( plot the average mismatch over the buses )
#	- summation ( plot the sum of all the mismatches )
#	- maximum ( find the largest mismatch on a bus and plot it )
#
failures_graph_power = Graph("output/graphs/failures_power.html")
failures_graph_reactive = Graph("output/graphs/failures_reactive.html")

models = ["AC", "DC", "Logarithmic", "Quadratic", "Linear"]
let graph_style = 1
let largest_mismatch_reactive = -1
let largest_mismatch_power = -1

for model in models

	# collect the differences for all power balance equation
	differences_power = []
	differences_reactive = []

	for case in keys(failures)

		# get the power balance differences
		fail = failures[case][model]

		if length(keys(fail)) > 0
			total_difference = []

			for item in fail["Power-Balance-Equation"]
				equation = string(item["equation"])

				split_equation = split(equation, " == ")[1]
				cleaned_equation = strip(replace(split_equation, r"[\`]" => ""), ['`'])
				lhs = parse(Float64, cleaned_equation)

				split_equation = split(equation, " == ")[2]
				cleaned_equation = strip(replace(split_equation, r"[\`]" => ""), ['`'])
				rhs = parse(Float64, cleaned_equation)
				
				difference = abs(rhs-lhs)
				push!(total_difference, difference)
			end

			average = sum(total_difference) / length(total_difference)
			summation = sum(total_difference)
			largest = maximum(total_difference)
			push!(differences_power, largest)

			if largest > largest_mismatch_power
				largest_mismatch_power = largest
			end
		end

		if (length(keys(fail)) > 0) && ("Reactive-Power-Balance-Equation" in keys(fail))
			total_difference = []

			for item in fail["Reactive-Power-Balance-Equation"]
				equation = string(item["equation"])

				split_equation = split(equation, " == ")[1]
				cleaned_equation = strip(replace(split_equation, r"[\`]" => ""), ['`'])
				lhs = parse(Float64, cleaned_equation)

				split_equation = split(equation, " == ")[2]
				cleaned_equation = strip(replace(split_equation, r"[\`]" => ""), ['`'])
				rhs = parse(Float64, cleaned_equation)
				
				difference = abs(rhs-lhs)
				push!(total_difference, difference)
			end

			average = sum(total_difference) / length(total_difference)
			summation = sum(total_difference)
			largest = maximum(total_difference)

			push!(differences_reactive, largest)

			if largest > largest_mismatch_reactive
				largest_mismatch_reactive = largest
			end
		end
	end

	# update the scatter graph
	add_scatter(failures_graph_power, collect(keys(failures)), differences_power, model, graph_style)
	add_scatter(failures_graph_reactive, collect(keys(failures)), differences_reactive, model, graph_style)
	
	# change the colour
	graph_style += 1
end


# add vertical lines to show infeasible cases
for case in keys(cases)

	# for each case check if at least one of the models is infeasible
	infeasible = false
	limit = false

	for model_type in keys(cases[case])
		model = cases[case][model_type].model
		termination = termination_status(model)
		if termination == LOCALLY_INFEASIBLE
			infeasible = true
		end

		if termination == ITERATION_LIMIT
			limit = true
		end
	end

	# if any of the models are infeasible show it
	if infeasible
		add_vertical_line(failures_graph_power, case, largest_mismatch_power)
		add_vertical_line(failures_graph_reactive, case, largest_mismatch_reactive)
	end

	if limit
		add_vertical_line(failures_graph_power, case, largest_mismatch_power) # add colour
		add_vertical_line(failures_graph_reactive, case, largest_mismatch_reactive) # add colour
	end
end



create_plot(failures_graph_power, "absolute difference in power balance equation of failed cases", "Case Number", "Abs Difference")
create_plot(failures_graph_reactive, "absolute difference in reactive power balance equation of failed cases", "Case Number", "Abs Difference")

save_graph(failures_graph_power)
save_graph(failures_graph_reactive)

end
end
end
#