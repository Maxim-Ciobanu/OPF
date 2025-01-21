using JuMP, Ipopt, Gurobi, Serialization, Random
using PowerModels
using MPOPF
using Statistics
using CSV
using DataFrames

# how much error are we willing to operate at?
threshold = 0


function minmax_AC_1(vm, bus_data)
	# @variable(model, bus_data[i]["vmin"] <= vm[t in 1:T, i in keys(bus_data)] <= bus_data[i]["vmax"], start=1.0)

	minmax_fails = []
	t = 1

	for i in keys(bus_data)
		if bus_data[i]["vmin"] - threshold <= value(vm[t, i]) <= bus_data[i]["vmax"] + threshold
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

			push!(minmax_fails, failure)
		end
	end

	return minmax_fails
end

function minmax_AC_2(pg, gen_data)
	# @variable(model, gen_data[i]["pmin"] <= pg[t in 1:T, i in keys(gen_data)] <= gen_data[i]["pmax"])
	

	# collect all failures
	minmax_fails = []
	t = 1

	for i in keys(gen_data)
		if gen_data[i]["pmin"] - threshold <= value(pg[t, i]) <= gen_data[i]["pmax"] + threshold
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

			push!(minmax_fails, failure)
		end
	end

	# add filled array to the failures dictionary
	return minmax_fails
end

function minmax_AC_3(qg, gen_data)
	# @variable(model, gen_data[i]["qmin"] <= qg[t in 1:T, i in keys(gen_data)] <= gen_data[i]["qmax"])
	

	# collect all failures
	minmax_fails = []
	t = 1

	for i in keys(gen_data)
		if gen_data[i]["qmin"] - threshold <= value(qg[t, i]) <= gen_data[i]["qmax"] + threshold
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

			push!(minmax_fails, failure)
		end
	end

	return minmax_fails
	
end

function minmax_AC_4(p, ref, branch_data)
	# @variable(model, -branch_data[l]["rate_a"] <= p[t in 1:T, (l,i,j) in ref[:arcs]] <= branch_data[l]["rate_a"])

	# collect all failures
	minmax_fails = []
	t = 1

	for (l,i,j) in ref[:arcs]
		if -branch_data[l]["rate_a"] - threshold <= value(p[t, (l,i,j)]) <= branch_data[l]["rate_a"] + threshold
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

			push!(minmax_fails, failure)
		end
	end

	# add filled array to the failures dictionary
	return minmax_fails

end

function minmax_AC_5(q, ref, branch_data)
	# @variable(model, -branch_data[l]["rate_a"] <= q[t in 1:T, (l,i,j) in ref[:arcs]] <= branch_data[l]["rate_a"])

	# collect all failures
	minmax_fails = []
	t = 1

	for (l,i,j) in ref[:arcs]
		if -branch_data[l]["rate_a"] - threshold <= value(q[t, (l,i,j)]) <= branch_data[l]["rate_a"] + threshold
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

			push!(minmax_fails, failure)
		end
	end

	# add filled array to the failures dictionary
	return minmax_fails

end

function minmax_AC_6(ramp_up, gen_data)
	# @variable(model, ramp_up[t in 2:T, g in keys(gen_data)] >= 0)

	# collect all failures
	minmax_fails = []
	t = 2

	for g in keys(gen_data)
		if ramp_up[t, g] + threshold >= 0
			continue
		else
			failure = Dict{String, Any}(
				"t" => t,
				"g" => g,
				"lower bound" => 0,
				"value" => ramp_up[t, g],
				"equation" => `$(ramp_up[t, g]) ≥ 0`
			)

			push!(minmax_fails, failure)
		end
	end

	# add filled array to the failures dictionary
	return minmax_fails
end

function minmax_AC_7(ramp_down, gen_data)
	# @variable(model, ramp_down[t in 2:T, g in keys(gen_data)] >= 0)

	# collect all failures
	minmax_fails = []
	t = 2

	for g in keys(gen_data)
		if ramp_down[t, g] + threshold >= 0
			continue
		else
			failure = Dict{String, Any}(
				"t" => t,
				"g" => g,
				"lower bound" => 0,
				"value" => ramp_down[t, g],
				"equation" => `$(ramp_down[t, g]) ≥ 0`
			)

			push!(minmax_fails, failure)
		end
	end

	# add filled array to the failures dictionary
	return minmax_fails
end

function minmax_DC_1(pg, gen_data)
	# @variable(model, gen_data[i]["pmin"] <= pg[t in 1:T, i in keys(gen_data)] <= gen_data[i]["pmax"])
	
	# collect all failures
	minmax_failures = []
	t = 1

	for i in keys(gen_data)
		if gen_data[i]["pmin"] - threshold <= value(pg[t, i]) <= gen_data[i]["pmax"] + threshold
			
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

	# add to failures
	return minmax_failures
end

function minmax_DC_2(p, ref)
	# @variable(model, -ref[:branch][l]["rate_a"] <= p[1:T,(l,i,j) in ref[:arcs_from]] <= ref[:branch][l]["rate_a"])

	# collect all failures
	minmax_failures = []
	t = 1

	for (l,i,j) in ref[:arcs_from]
		if -ref[:branch][l]["rate_a"] - threshold <= value(p[t,(l,i,j)]) <= ref[:branch][l]["rate_a"] + threshold
			continue
		else
			failure = Dict{String, Any}(
				"t" => t,
				"i" => i,
				"lower bound" => -ref[:branch][l]["rate_a"],
				"upper bound" => ref[:branch][l]["rate_a"],
				"value" => Float64(value(p[t,(l,i,j)])),
				"equation" => `$(-ref[:branch][l]["rate_a"]) ≤ $(value(p[t,(l,i,j)])) ≤ $(ref[:branch][l]["rate_a"])`
			)

			push!(minmax_failures, failure)
		end
	end

	# add to failures
	return minmax_failures
end

function minmax_DC_3(ramp_up, gen_data)
	# @variable(model, ramp_up[t in 2:T, g in keys(gen_data)] >= 0)

	# collect all failures
	minmax_failures = []
	t = 2

	for g in keys(gen_data)
		if threshold + ramp_up[t, g] >= 0
			continue
		else
			failure = Dict{String, Any}(
				"t" => t,
				"i" => i,
				"lower bound" => 0,
				"value" => ramp_up[t, g],
				"equation" => `$(ramp_up[t, g]) ≥ 0`
			)

			push!(minmax_failures, failure)
		end
	end

	# add to failures
	return minmax_failures
end

function minmax_DC_4(ramp_down, gen_data)
	# @variable(model, ramp_down[t in 2:T, g in keys(gen_data)] >= 0)

	# collect all failures
	minmax_failures = []
	t = 2

	for g in keys(gen_data)
		if threshold + ramp_down[t, g] >= 0
			continue
		else
			failure = Dict{String, Any}(
				"t" => t,
				"i" => i,
				"lower bound" => 0,
				"value" => ramp_up[t, g],
				"equation" => `$(ramp_down[t, g]) ≥ 0`
			)

			push!(minmax_failures, failure)
		end
	end

	# add to failures
	return minmax_failures
end



function powerbalance_AC_1(va, ref)
	# @constraint(model, va[t,i] == 0)

	angle_failures = []
	t = 1

	for (i, bus) in ref[:ref_buses]

		lhs = value(va[t, i])
		rhs = 0

		if abs(lhs - rhs) < threshold
			continue
		else
			failure = Dict{String, Any}(
				"t" => t,
				"i" => i,
				"bus" => bus,
				"lhs" => lhs,
				"rhs_1" => rhs,
				"equation_expanded" => `$lhs == 0`,
				"equation" => `$lhs == 0`
			)
		
			push!(angle_failures, failure)
		end
	end

	return angle_failures
end

function powerbalance_AC_2(p, pg, vm, ref, factors, load_data)
	# @constraint(model,
	#     sum(p[t,a] for a in ref[:bus_arcs][i]) ==
	#     sum(pg[t, g] for g in ref[:bus_gens][i]) -
	#     sum(load["pd"] * factors[t] for load in bus_loads) -
	#     sum(shunt["gs"] for shunt in bus_shunts)*vm[t,i]^2
	# )

	power_failures = []
	t = 1

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

		if abs(lhs - (rhs_1 - rhs_2 - rhs_3)) < threshold
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
	end

	return power_failures
end

function powerbalance_AC_3(q, qg, vm, ref, factors, load_data)
	# @constraint(model,
	#     sum(q[t,a] for a in ref[:bus_arcs][i]) ==
	#     sum(qg[t, g] for g in ref[:bus_gens][i]) -
	#     sum(load["qd"] * factors[t] for load in bus_loads) +
	#     sum(shunt["bs"] for shunt in bus_shunts)*vm[t,i]^2
	# )

	# a list to keep track of failures
	reactive_failures = []
	t = 1

	for (i, bus) in ref[:bus]
		bus_loads = [load_data[l] for l in ref[:bus_loads][i]]
		bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]

		lhs = sum(value(q[t,a]) for a in ref[:bus_arcs][i]; init=0)
		rhs_1 = sum(value(qg[t, g]) for g in ref[:bus_gens][i]; init=0)
		rhs_2 = sum(load["pd"] * factors[t] for load in bus_loads; init=0)
		rhs_3 = sum(shunt["bs"] for shunt in bus_shunts; init=0)*(value(vm[t,i])^2)

		if (lhs - (rhs_1 - rhs_2 + rhs_3)) < threshold
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

	return reactive_failures
end

function powerbalance_DC_1(va, ref)
	# @constraint(model, va[t,i] == 0)

	angle_failures = []
	t = 1

	for (i, bus) in ref[:ref_buses]

		lhs = value(va[t, i])
		rhs = 0

		if abs(lhs - rhs) < threshold
			continue
		else
			failure = Dict{String, Any}(
				"t" => t,
				"i" => i,
				"bus" => bus,
				"lhs" => lhs,
				"rhs_1" => rhs,
				"equation_expanded" => `$lhs == 0`,
				"equation" => `$lhs == 0`
			)
		
			push!(angle_failures, failure)
		end
	end

	return angle_failures
end

function powerbalance_DC_2(p, pg, ref, factors, load_data)
	# @constraint(model,
	# sum(p_expr[t][a] for a in ref[:bus_arcs][i]) ==
	# sum(pg[t, g] for g in ref[:bus_gens][i]) -
	# sum(load["pd"] * factors[t] for load in bus_loads) -
	# sum(shunt["gs"] for shunt in bus_shunts)*1.0^2

	power_failures = []
	t = 1

	# calculate the p_expr dictionary
	p_expr = Dict()
	p_expr[t] = Dict()
	p_expr[t] = Dict([((l, i, j), 1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs_from]])
	p_expr[t] = merge(p_expr[t], Dict([((l, j, i), -1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs_from]]))
	

	for (i, bus) in ref[:bus]
		bus_loads = [load_data[l] for l in ref[:bus_loads][i]]
		bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]

		lhs = sum(value(p_expr[t][a]) for a in ref[:bus_arcs][i]; init=0)
		rhs_1 = sum(value(pg[t, g]) for g in ref[:bus_gens][i]; init=0)
		rhs_2 = sum(load["pd"] * factors[t] for load in bus_loads; init=0)
		rhs_3 = sum(shunt["gs"] for shunt in bus_shunts; init=0)*1.0^2

		if abs(lhs - (rhs_1 - rhs_2 - rhs_3)) < threshold
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

	return power_failures
end



function compute_infeasible(directory::String)
	
	# grab all the cases
	cases = load_and_compile_models(directory)

	# define a dictionary to store the failures in here
	failures = Dict{String, Dict{String, Any}}()

	# for each case
	for case_name in keys(cases) 	
	
		# initialise case names failures
		failures[case_name] = Dict{String, Any}()
		
		# for every model in each case
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

			# if DC
			if model_name == "DC"

				# extract model variables
				va = model[:va]
				p = model[:p]
				pg = model[:pg]
				factors = power_flow_model.factors
				ramp_up = model[:ramp_up]
				ramp_down = model[:ramp_down]

				# now perform the checks
				powerbalance_1 = powerbalance_DC_1(va, ref)
				powerbalance_2 = powerbalance_DC_2(p, pg, ref, factors, load_data)
				
				# now complete the bound checks
				minmax_1 = minmax_DC_1(pg, gen_data)
				minmax_2 = minmax_DC_2(p, ref)
				# minmax_3 = minmax_DC_3(ramp_up, gen_data) have t=2 which does not work!!!
				# minmax_4 = minmax_DC_4(ramp_down, gen_data) have t=2 which does not work!!!

				# complete the failures dictionary
				if length(powerbalance_1) > 0
					failures[case_name][model_name]["powerbalance_va"] = powerbalance_1
				end

				if length(powerbalance_2) > 0
					failures[case_name][model_name]["powerbalance_active"] = powerbalance_2
				end

				if length(minmax_1) > 0
					failures[case_name][model_name]["minmax_1"] = minmax_1
				end

				if length(minmax_2) > 0
					failures[case_name][model_name]["minmax_2"] = minmax_2
				end

				# if length(minmax_3) > 0
				# 	failures[case_name][model_name]["Min-Max-Failure-3"] = minmax_3
				# end

				# if length(minmax_4) > 0
				# 	failures[case_name][model_name]["Min-Max-Failure-4"] = minmax_4
				# end

			end

			# if AC or approximation
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

				# now perform powerbalance checks
				powerbalance_1 = powerbalance_AC_1(va, ref)
				powerbalance_2 = powerbalance_AC_2(p, pg, vm, ref, factors, load_data)
				powerbalance_3 = powerbalance_AC_3(q, qg, vm, ref, factors, load_data)

				# now perform bound checks
				minmax_1 = minmax_AC_1(vm, bus_data)
				minmax_2 = minmax_AC_2(pg, gen_data)
				minmax_3 = minmax_AC_3(qg, gen_data)
				minmax_4 = minmax_AC_4(p, ref, branch_data)
				minmax_5 = minmax_AC_5(q, ref, branch_data)
				# minmax_6 = minmax_AC_6(ramp_up, gen_data) have t=2 which does not work!!!
				# minmax_7 = minmax_AC_7(ramp_down, gen_data) have t=2 which does not work!!!

				# complete the failures dictionary
				if length(powerbalance_1) > 0
					failures[case_name][model_name]["powerbalance_va"] = powerbalance_1
				end

				if length(powerbalance_2) > 0
					failures[case_name][model_name]["powerbalance_active"] = powerbalance_2
				end

				if length(powerbalance_3) > 0
					failures[case_name][model_name]["powerbalance_reactive"] = powerbalance_3
				end

				if length(minmax_1) > 0
					failures[case_name][model_name]["minmax_1"] = minmax_1
				end

				if length(minmax_2) > 0
					failures[case_name][model_name]["minmax_2"] = minmax_2
				end

				if length(minmax_3) > 0
					failures[case_name][model_name]["minmax_3"] = minmax_3
				end

				if length(minmax_4) > 0
					failures[case_name][model_name]["minmax_4"] = minmax_4
				end

				if length(minmax_5) > 0
					failures[case_name][model_name]["minmax_5"] = minmax_5
				end

				# if length(minmax_6) > 0
				# 	failures[case_name][model_name]["minmax_6"] = minmax_6
				# end

				# if length(minmax_7) > 0
				# 	failures[case_name][model_name]["minmax_7"] = minmax_7
				# end
			end
		end
	end

	return failures
end

function serialize_failures(failures::Dict)
	serialize("output/failures/all_case_violations_dictionary.bin", failures)
end

failures = compute_infeasible("results")
serialize_failures(failures)