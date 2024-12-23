using JuMP, Ipopt, Gurobi, Serialization, Random
using PowerModels
using MPOPF
using Statistics
using CSV
using DataFrames

cases = load_and_compile_models("results/")

# power_flow_model = cases["case14"]["Linear"]
# model = power_flow_model.model




for case_name in keys(cases)
	for model_name in keys(cases[case_name])
		println(`Performing $model_name`)

		# ignore DC
		if model_name == "DC" break end

		power_flow_model = cases[case_name][model_name]
		model = power_flow_model.model

		data = power_flow_model.data
		T = power_flow_model.time_periods
		ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
		
		gen_data = ref[:gen]
		load_data = ref[:load]
		
		va = model[:va]
		p = model[:p]
		q = model[:q]
		pg = model[:pg]
		qg = model[:qg]
		vm = model[:vm]
		ramp_up = model[:ramp_up]
		ramp_down = model[:ramp_down]
		
		factors = power_flow_model.factors
		
		# power balance constraints for time periods
		for t in 1:T
		
			# 
			for (i, bus) in ref[:ref_buses]
				@constraint(model, va[t,i] == 0)
			end
		
			# 
			for (i, bus) in ref[:bus]
				bus_loads = [load_data[l] for l in ref[:bus_loads][i]]
				bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]
		
				if sizeof(bus_loads) == 0 || sizeof(bus_shunts) == 0
					println("bus loads or shunts is equal to 0 raising error")
					break
				end
		
				equation_a_lhs = sum(p[t,a] for a in ref[:bus_arcs][i])
				equation_a_rhs = sum(pg[t, g] for g in ref[:bus_gens][i]) - sum(load["pd"] * factors[t] for load in bus_loads) - sum(shunt["gs"] for shunt in bus_shunts)*vm[t,i]^2
		
				equation_b_lhs = sum(q[t,a] for a in ref[:bus_arcs][i])
				equation_b_rhs = sum(qg[t, g] for g in ref[:bus_gens][i]) - sum(load["qd"] * factors[t] for load in bus_loads) + sum(shunt["bs"] for shunt in bus_shunts)*vm[t,i]^2
		
				if equation_a_lhs == equation_a_rhs
					println(`SUCCESS - Power Balance Equation Valid`)
				else
					println(`FAILED - Power Balance Equation Failed`)
				end
		
				if equation_b_lhs == equation_b_rhs
					println(`SUCCESS - Reactive Power Balance Equation Valid`)
				else
					println(`FAILED - Reactive Power Balance Equation Failed`)
				end
			end
		end
	end
end



