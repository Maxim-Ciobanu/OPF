using JuMP, Ipopt, Gurobi, Serialization, Random
using PowerModels
using MPOPF
using Statistics
using CSV
using DataFrames

cases = load_and_compile_models("results/")

failures = Dict{String, Dict{String, Any}}()
minmax_failures = Dict{String, Dict{String, Any}}()


for case_name in keys(cases) 	

	# initialise case names failures
	failures[case_name] = Dict{String, Any}()
	minmax_failures[case_name] = Dict{String, Any}()

	println("Performing $case_name")

	for model_name in keys(cases[case_name])

		# initialise case names failures
		failures[case_name][model_name] = Dict{String, Any}()
		minmax_failures[case_name][model_name] = Dict{String, Any}()


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


		# do DC
		if model_name == "DC"

			# get model data necessary for checking
			va = model[:va]
			p = model[:p]
			pg = model[:pg]
			ramp_up = model[:ramp_up]
			ramp_down = model[:ramp_down]

			println("\t- Performing minmax checks on $model_name")
		
			# @variable(model, gen_data[i]["pmin"] <= pg[t in 1:T, i in keys(gen_data)] <= gen_data[i]["pmax"])
			for t in 1:T, i in keys(gen_data)
				if gen_data[i]["pmin"] > value(pg[t, i]) && value(pg[t, i]) > gen_data[i]["pmax"]
					minmax_failures[case_name][model_name]["Min-Max-Equation1"] = Dict{String, Any}()
					minmax_failures[case_name][model_name]["Min-Max-Equation1"]["t"] = t
					minmax_failures[case_name][model_name]["Min-Max-Equation1"]["i"] = i
					minmax_failures[case_name][model_name]["Min-Max-Equation1"]["equation"] = `$(gen_data[i]["pmin"]) ≤ $(value(pg[t, i])) ≤ $(gen_data[i]["pmax"])`
				end
			end

			# # @variable(model, -branch_data[l]["rate_a"] <= p[t in 1:T, (l,i,j) in ref[:arcs]] <= branch_data[l]["rate_a"]) IS THERE A REASON THIS IS COMMENTED OUT IN implementation-dc
			# for t in 1:T, (l,i,j) in ref[:arcs]
			# 	if -branch_data[l]["rate_a"] > value(p[t, (l,i,j)]) && value(p[t, (l,i,j)]) > branch_data[l]["rate_a"]
					# failures[case_name][model_name]["Min-Max-Equation2"] = Dict{String, Any}()
					# failures[case_name][model_name]["Min-Max-Equation2"]["t"] = t
					# failures[case_name][model_name]["Min-Max-Equation2"]["l"] = l
					# failures[case_name][model_name]["Min-Max-Equation2"]["i"] = i
					# failures[case_name][model_name]["Min-Max-Equation2"]["j"] = j
					# failures[case_name][model_name]["Min-Max-Equation2"]["equation"] = `$(-branch_data[l]["rate_a"]) <= $(value(p[t,(l,i,j)])) <= $(branch_data[l]["rate_a"])`
			# 	end
			# end
			
			# @variable(model, -ref[:branch][l]["rate_a"] <= p[1:T,(l,i,j) in ref[:arcs_from]] <= ref[:branch][l]["rate_a"])
			for t in 1:T, (l,i,j) in ref[:arcs_from]
				if -ref[:branch][l]["rate_a"] > value(p[t,(l,i,j)]) && value(p[t,(l,i,j)]) > ref[:branch][l]["rate_a"]
					minmax_failures[case_name][model_name]["Min-Max-Equation2"] = Dict{String, Any}()
					minmax_failures[case_name][model_name]["Min-Max-Equation2"]["t"] = t
					minmax_failures[case_name][model_name]["Min-Max-Equation2"]["l"] = l
					minmax_failures[case_name][model_name]["Min-Max-Equation2"]["i"] = i
					minmax_failures[case_name][model_name]["Min-Max-Equation2"]["j"] = j
					minmax_failures[case_name][model_name]["Min-Max-Equation2"]["equation"] = `$(-ref[:branch][l]["rate_a"]) ≤ $(value(p[t,(l,i,j)])) ≤ $(ref[:branch][l]["rate_a"])`
				end
			end

			# @variable(model, ramp_up[t in 2:T, g in keys(gen_data)] >= 0)
			for t in 2:T, g in keys(gen_data)
				if ramp_up[t, g] < 0
					minmax_failures[case_name][model_name]["Min-Max-Equation3"] = Dict{String, Any}()
					minmax_failures[case_name][model_name]["Min-Max-Equation3"]["t"] = t
					minmax_failures[case_name][model_name]["Min-Max-Equation3"]["g"] = g
					minmax_failures[case_name][model_name]["Min-Max-Equation3"]["equation"] = `$(ramp_up[t, g]) ≥ 0`
				end
			end

			# @variable(model, ramp_down[t in 2:T, g in keys(gen_data)] >= 0)
			for t in 2:T, g in keys(gen_data)
				if ramp_down[t, g] < 0
					minmax_failures[case_name][model_name]["Min-Max-Equation4"] = Dict{String, Any}()
					minmax_failures[case_name][model_name]["Min-Max-Equation4"]["t"] = t
					minmax_failures[case_name][model_name]["Min-Max-Equation4"]["g"] = g
					minmax_failures[case_name][model_name]["Min-Max-Equation4"]["equation"] = `$(ramp_down[t, g]) ≥ 0`
				end
			end


		# all other models
		elseif model_name == "AC" || model_name == "Quadratic" || model_name == "Logarithmic" || model_name == "Linear" 

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
			for t in 1:T, i in keys(bus_data)
				if bus_data[i]["vmin"] > value(vm[t, i]) && value(vm[t, i]) > bus_data[i]["vmax"]
					minmax_failures[case_name][model_name]["Min-Max-Equation1"] = Dict{String, Any}()
					minmax_failures[case_name][model_name]["Min-Max-Equation1"]["t"] = t
					minmax_failures[case_name][model_name]["Min-Max-Equation1"]["i"] = i
					minmax_failures[case_name][model_name]["Min-Max-Equation1"]["equation"] = `$(bus_data[i]["vmin"]) ≤ $(value(vm[t, i])) ≤ $(bus_data[i]["vmax"])`
				end
			end
			
			# @variable(model, gen_data[i]["pmin"] <= pg[t in 1:T, i in keys(gen_data)] <= gen_data[i]["pmax"])
			for t in 1:T, i in keys(gen_data)
				if gen_data[i]["pmin"] > value(pg[t, i]) && value(pg[t, i]) > gen_data[i]["pmax"]
					minmax_failures[case_name][model_name]["Min-Max-Equation2"] = Dict{String, Any}()
					minmax_failures[case_name][model_name]["Min-Max-Equation2"]["t"] = t
					minmax_failures[case_name][model_name]["Min-Max-Equation2"]["i"] = i
					minmax_failures[case_name][model_name]["Min-Max-Equation2"]["equation"] = `$(gen_data[i]["pmin"]) ≤ $(value(pg[t, i])) ≤ $(gen_data[i]["pmax"])`
				end
			end

			# @variable(model, gen_data[i]["qmin"] <= qg[t in 1:T, i in keys(gen_data)] <= gen_data[i]["qmax"])
			for t in 1:T, i in keys(gen_data)
				if gen_data[i]["qmin"] > value(qg[t, i]) && value(qg[t, i]) > gen_data[i]["qmax"]
					minmax_failures[case_name][model_name]["Min-Max-Equation3"] = Dict{String, Any}()
					minmax_failures[case_name][model_name]["Min-Max-Equation3"]["t"] = t
					minmax_failures[case_name][model_name]["Min-Max-Equation3"]["i"] = i
					minmax_failures[case_name][model_name]["Min-Max-Equation3"]["equation"] = `$(gen_data[i]["qmin"]) ≤ $(value(qg[t, i])) ≤ $(gen_data[i]["qmax"])`
				end
			end

			# @variable(model, -branch_data[l]["rate_a"] <= p[t in 1:T, (l,i,j) in ref[:arcs]] <= branch_data[l]["rate_a"])
			for t in 1:T, (l,i,j) in ref[:arcs]
				if -branch_data[l]["rate_a"] > value(p[t, (l,i,j)]) && value(p[t, (l,i,j)]) > branch_data[l]["rate_a"]
					minmax_failures[case_name][model_name]["Min-Max-Equation4"] = Dict{String, Any}()
					minmax_failures[case_name][model_name]["Min-Max-Equation4"]["t"] = t
					minmax_failures[case_name][model_name]["Min-Max-Equation4"]["l"] = l
					minmax_failures[case_name][model_name]["Min-Max-Equation4"]["i"] = i
					minmax_failures[case_name][model_name]["Min-Max-Equation4"]["j"] = j
					minmax_failures[case_name][model_name]["Min-Max-Equation4"]["equation"] = `$(-branch_data[l]["rate_a"]) ≤ $(value(p[t, (l,i,j)])) ≤ $(branch_data[l]["rate_a"])`
				end
			end

			# @variable(model, -branch_data[l]["rate_a"] <= q[t in 1:T, (l,i,j) in ref[:arcs]] <= branch_data[l]["rate_a"])
			for t in 1:T, (l,i,j) in ref[:arcs]
				if -branch_data[l]["rate_a"] > value(q[t, (l,i,j)]) && value(q[t, (l,i,j)]) > branch_data[l]["rate_a"]
					minmax_failures[case_name][model_name]["Min-Max-Equation5"] = Dict{String, Any}()
					minmax_failures[case_name][model_name]["Min-Max-Equation5"]["t"] = t
					minmax_failures[case_name][model_name]["Min-Max-Equation5"]["l"] = l
					minmax_failures[case_name][model_name]["Min-Max-Equation5"]["i"] = i
					minmax_failures[case_name][model_name]["Min-Max-Equation5"]["j"] = j
					minmax_failures[case_name][model_name]["Min-Max-Equation5"]["equation"] = `$(-branch_data[l]["rate_a"]) ≤ $(value(q[t, (l,i,j)])) ≤ $(branch_data[l]["rate_a"])`
				end
			end

			# @variable(model, ramp_up[t in 2:T, g in keys(gen_data)] >= 0)
			for t in 2:T, g in keys(gen_data)
				if ramp_up[t, g] < 0
					minmax_failures[case_name][model_name]["Min-Max-Equation6"] = Dict{String, Any}()
					minmax_failures[case_name][model_name]["Min-Max-Equation6"]["t"] = t
					minmax_failures[case_name][model_name]["Min-Max-Equation6"]["g"] = g
					minmax_failures[case_name][model_name]["Min-Max-Equation6"]["equation"] = `$(ramp_up[t, g]) ≥ 0`
				end
			end

			# @variable(model, ramp_down[t in 2:T, g in keys(gen_data)] >= 0)
			for t in 2:T, g in keys(gen_data)
				if ramp_down[t, g] < 0
					minmax_failures[case_name][model_name]["Min-Max-Equation6"] = Dict{String, Any}()
					minmax_failures[case_name][model_name]["Min-Max-Equation6"]["t"] = t
					minmax_failures[case_name][model_name]["Min-Max-Equation6"]["g"] = g
					minmax_failures[case_name][model_name]["Min-Max-Equation6"]["equation"] = `$(ramp_down[t, g]) ≥ 0`
				end
			end

			println("\t- Performing constraint checks on $model_name")

			# perform power balance equation checks
			for t in 1:T, (i, bus) in ref[:bus]

				# a list to keep track of failures
				power_balance_failures = []

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
						
						push!(power_balance_failures, failure)
					end
				end

				failures[case_name][model_name]["Power-Balance-Equation"] = power_balance_failures
			end

			# perform the reactive power balance equation
			for t in 1:T, (i, bus) in ref[:bus]

				# a list to keep track of failures
				power_balance_failures = []

				for (i, bus) in ref[:bus]
					bus_loads = [load_data[l] for l in ref[:bus_loads][i]]
					bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]

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
						
						push!(power_balance_failures, failure)
					end
				end

				failures[case_name][model_name]["Reactive-Power-Balance-Equation"] = power_balance_failures
			end
		end
	end
end



# failures_graph_power = Graph("output/graphs/failures_power.html")
# failures_graph_reactive = Graph("output/graphs/failures_reactive.html")

# models = ["AC", "DC", "Logarithmic", "Quadratic", "Linear"]
# style = 1

# for model in models

# 	# collect the differences for all power balance equation
# 	differences_power = []
# 	differences_reactive = []

# 	for case in keys(failures)

# 		# get the power balance differences
# 		fail = failures[case][model]

# 		if length(keys(fail)) > 0
			
# 			equation = string(fail["Power-Balance-Equation"]["equation"])

# 			split_equation = split(equation, " == ")[1]
# 			cleaned_equation = strip(replace(split_equation, r"[\`]" => ""), ['`'])
# 			lhs = parse(Float64, cleaned_equation)

# 			split_equation = split(equation, " == ")[2]
# 			cleaned_equation = strip(replace(split_equation, r"[\`]" => ""), ['`'])
# 			rhs = parse(Float64, cleaned_equation)
			
# 			difference = abs(rhs-lhs)
# 			push!(differences_power, difference)
# 		end

# 		if length(keys(fail)) > 0
			
# 			equation = string(fail["Reactive-Power-Balance-Equation"]["equation"])

# 			split_equation = split(equation, " == ")[1]
# 			cleaned_equation = strip(replace(split_equation, r"[\`]" => ""), ['`'])
# 			lhs = parse(Float64, cleaned_equation)

# 			split_equation = split(equation, " == ")[2]
# 			cleaned_equation = strip(replace(split_equation, r"[\`]" => ""), ['`'])
# 			rhs = parse(Float64, cleaned_equation)
			
# 			difference = abs(rhs-lhs)
# 			push!(differences_reactive, difference)
# 		end
# 	end

# 	add_scatter(failures_graph_power, collect(keys(failures)), differences_power, model, style)
# 	add_scatter(failures_graph_reactive, collect(keys(failures)), differences_reactive, model, style)
# 	style += 1
# end

# create_plot(failures_graph_power, "absolute difference in power balance equation of failed cases", "Case Number", "Abs Difference")
# create_plot(failures_graph_reactive, "absolute difference in reactive power balance equation of failed cases", "Case Number", "Abs Difference")

# save_graph(failures_graph_power)
# save_graph(failures_graph_reactive)