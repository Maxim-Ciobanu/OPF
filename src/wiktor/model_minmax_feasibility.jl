using JuMP, Ipopt, Gurobi, Serialization, Random
using PowerModels
using MPOPF
using Statistics
using CSV
using DataFrames

cases = load_and_compile_models("results/")
failures = Dict{String, Dict{String, Any}}()


# go over every case
for case_name in keys(cases) 	

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

			println("\t- Performing minmax checks on $model_name")


			# @variable(model, bus_data[i]["vmin"] <= vm[t in 1:T, i in keys(bus_data)] <= bus_data[i]["vmax"], start=1.0)
			for t in 1:T

				# collect all failures
				minmax_failures = []

				for i in keys(bus_data)
					if bus_data[i]["vmin"] <= value(vm[t, i]) <= bus_data[i]["vmax"]
						continue
					else
						failure = Dict{String, Any}(
							"t" => t,
							"i" => i,
							"lower bound" => bus_data[i]["vmin"],
							"upper bound" => bus_data[i]["vmax"],
							"value" => Float64(value(vm[t, i])),
							"equation" => `$(bus_data[i]["vmin"]) ≤ $(value(vm[t, i])) ≤ $(bus_data[i]["vmax"])`
						)

						push!(minmax_failures, failure)
					end
				end

				# add filled array to the failures dictionary
				failures[case_name][model_name]["Min-Max-Failure-1"] = minmax_failures
			end
			

			# @variable(model, gen_data[i]["pmin"] <= pg[t in 1:T, i in keys(gen_data)] <= gen_data[i]["pmax"])
			for t in 1:T

				# collect all failures
				minmax_failures = []

				for i in keys(gen_data)
					if gen_data[i]["pmin"] <= value(pg[t, i]) <= gen_data[i]["pmax"]
						continue
					else
						failure = Dict{String, Any}(
							"t" => t,
							"i" => i,
							"lower bound" => gen_data[i]["pmin"],
							"upper bound" => gen_data[i]["pmax"],
							"value" => Float64(value(pg[t, i])),
							"equation" => `$(gen_data[i]["pmin"]) ≤ $(value(pg[t, i])) ≤ $(gen_data[i]["pmax"])`
						)

						push!(minmax_failures, failure)
					end
				end

				# add filled array to the failures dictionary
				failures[case_name][model_name]["Min-Max-Failure-2"] = minmax_failures
			end


			# @variable(model, gen_data[i]["qmin"] <= qg[t in 1:T, i in keys(gen_data)] <= gen_data[i]["qmax"])
			for t in 1:T

				# collect all failures
				minmax_failures = []

				for i in keys(gen_data)
					if gen_data[i]["qmin"] <= value(qg[t, i]) <= gen_data[i]["qmax"]
						continue
					else
						failure = Dict{String, Any}(
							"t" => t,
							"i" => i,
							"lower bound" => gen_data[i]["qmin"],
							"upper bound" => gen_data[i]["qmax"],
							"value" => Float64(value(qg[t, i])),
							"equation" => `$(gen_data[i]["qmin"]) ≤ $(value(qg[t, i])) ≤ $(gen_data[i]["qmax"])`
						)

						push!(minmax_failures, failure)
					end
				end

				# add filled array to the failures dictionary
				failures[case_name][model_name]["Min-Max-Failure-3"] = minmax_failures
			end


			# @variable(model, -branch_data[l]["rate_a"] <= p[t in 1:T, (l,i,j) in ref[:arcs]] <= branch_data[l]["rate_a"])
			for t in 1:T

				# collect all failures
				minmax_failures = []

				for (l,i,j) in ref[:arcs]
					if -branch_data[l]["rate_a"] <= value(p[t, (l,i,j)]) <= branch_data[l]["rate_a"]
						continue
					else
						failure = Dict{String, Any}(
							"t" => t,
							"l" => l,
							"i" => i,
							"j" => j,
							"lower bound" => -branch_data[l]["rate_a"],
							"upper bound" => branch_data[l]["rate_a"],
							"value" => Float64(value(p[t, (l,i,j)])),
							"equation" => `$(-branch_data[l]["rate_a"]) ≤ $(value(p[t, (l,i,j)])) ≤ $(branch_data[l]["rate_a"])`
						)

						push!(minmax_failures, failure)
					end
				end

				# add filled array to the failures dictionary
				failures[case_name][model_name]["Min-Max-Failure-4"] = minmax_failures
			end


			# @variable(model, -branch_data[l]["rate_a"] <= q[t in 1:T, (l,i,j) in ref[:arcs]] <= branch_data[l]["rate_a"])
			for t in 1:T

				# collect all failures
				minmax_failures = []

				for (l,i,j) in ref[:arcs]
					if -branch_data[l]["rate_a"] <= value(q[t, (l,i,j)]) <= branch_data[l]["rate_a"]
						continue
					else

						failure = Dict{String, Any}(
							"t" => t,
							"l" => l,
							"i" => i,
							"j" => j,
							"lower bound" => -branch_data[l]["rate_a"],
							"upper bound" => branch_data[l]["rate_a"],
							"value" => Float64(value(q[t, (l,i,j)])),
							"equation" => `$(-branch_data[l]["rate_a"]) ≤ $(value(q[t, (l,i,j)])) ≤ $(branch_data[l]["rate_a"])`
						)

						push!(minmax_failures, failure)
					end
				end

				# add filled array to the failures dictionary
				failures[case_name][model_name]["Min-Max-Failure-5"] = minmax_failures
			end

			# @variable(model, ramp_up[t in 2:T, g in keys(gen_data)] >= 0)
			for t in 2:T

				# collect all failures
				minmax_failures = []

				for g in keys(gen_data)
					if ramp_up[t, g] >= 0
						continue
					else
						failure = Dict{String, Any}(
							"t" => t,
							"g" => g,
							"lower bound" => 0,
							"value" => ramp_up[t, g],
							"equation" => `$(ramp_up[t, g]) ≥ 0`
						)

						push!(minmax_failures, failure)
					end
				end

				# add filled array to the failures dictionary
				failures[case_name][model_name]["Min-Max-Failure-6"] = minmax_failures
			end

			# @variable(model, ramp_down[t in 2:T, g in keys(gen_data)] >= 0)
			for t in 2:T

				# collect all failures
				minmax_failures = []

				for g in keys(gen_data)
					if ramp_down[t, g] >= 0
						continue
					else
						failure = Dict{String, Any}(
							"t" => t,
							"g" => g,
							"lower bound" => 0,
							"value" => ramp_down[t, g],
							"equation" => `$(ramp_down[t, g]) ≥ 0`
						)

						push!(minmax_failures, failure)
					end
				end

				# add filled array to the failures dictionary
				failures[case_name][model_name]["Min-Max-Failure-7"] = minmax_failures
			end
		end
	end
end



failures_graph_minmax = Graph("output/graphs/failures_minmax.html")

models = ["AC", "DC", "Logarithmic", "Quadratic", "Linear"]
let graph_style = 1

for model in models

	# collect the differences for all power balance equation
	differences_minmax = []

	for case in keys(failures)
		for minmax_equation in keys(failures[case][model])

			# get the failed minmax equation
			failed_minmax_equations = failures[case][model][minmax_equation]

			# check that there are failed equations
			if length(failed_minmax_equations) > 0

				total_difference = 0

				for equation in failed_minmax_equations
					difference_lower = 99999999
					difference_upper = 99999999

					if "lower bound" in keys(equation)
						difference_lower = abs(equation["value"] - equation["lower bound"])
					end
					
					if "upper bound" in keys(equation)
						difference_upper = abs(equation["value"] - equation["upper bound"])
					end

					total_difference += min(difference_lower, difference_upper)
				end

				# add it to the differences array
				push!(differences_minmax, sum(total_difference) / length(total_difference))
			end
		end
	end

	add_scatter(failures_graph_minmax, collect(keys(failures)), differences_minmax, model, graph_style)
	graph_style += 1
end

create_plot(failures_graph_minmax, "absolute difference in minmax equation of failed cases", "Case Number", "Abs Difference ( average )")
save_graph(failures_graph_minmax)

end