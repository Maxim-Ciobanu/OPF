#############################################################################
# Note: This file is curently being used for examples, nothing is permanent
#############################################################################

using JuMP, Ipopt, Serialization
using MPOPF



models = load_and_compile_models("./results")

for case in keys(models)
	println("\n\n\nCase: ", case)
	for model in keys(models[case])
		println("Model: ", model)
		model = models[case][model].model

		# try
		# check feasibility of the constraints
		feasibility = find_infeasible_constraints(model)
		violations = find_bound_violations(model)

		# sum the violation differences
		total_violation = sum(getindex.(values(violations), 4))
		number_violations = length(values(violations))

		average_violation = total_violation / number_violations

		# look into the feasbility violations
		if length(feasibility) > 0
			for (con, val) in feasibility
				println("")
				println("Infeasible constraint: ", con)
				println("Current value: ", val)
				println("")
			end
		end

		# look into the bound violations below
		if length(violations) > 0
			println("Max violation: ", maximum(getindex.(values(violations), 4)))
			println("Average violation: ", average_violation)
		end
	end
end

# Path to the case file
# file_path = "./Cases/case14.m"


# # Example for AC
# # --------------------------------------------------------------------------
# ac_factory = ACMPOPFModelFactory(file_path, Ipopt.Optimizer)
# My_AC_model = create_model(ac_factory)
# optimize_model(My_AC_model)
# # --------------------------------------------------------------------------


# # Example for DC
# # --------------------------------------------------------------------------
# dc_factory = DCMPOPFModelFactory(file_path, Ipopt.Optimizer)
# My_DC_model = create_model(dc_factory)
# optimize_model(My_DC_model)
# # --------------------------------------------------------------------------


# # Multi Period Graphing Example for AC
# # --------------------------------------------------------------------------
# ac_factory = ACMPOPFModelFactory(file_path, Ipopt.Optimizer)
# My_AC_model_Graphing_multi_period = create_model(ac_factory; time_periods=24, factors=[1.0, 1.05, 0.98, 1.03, 0.96, 0.97, 0.99, 1.0, 1.05, 1.03, 1.01, 0.95, 1.04, 1.02, 0.99, 0.99, 0.99, 0.95, 1.04, 1.02, 0.98, 1.0, 1.02, 0.97], ramping_cost=2000)
# optimize_model_with_plot(My_AC_model_Graphing_multi_period)
# # --------------------------------------------------------------------------


# # Example for DC with UncertaintyFactory
# # --------------------------------------------------------------------------
# load_scenarios_factors = generate_load_scenarios(1000, 14)
# # Using DC Factory with Gurobi
# dc_factory_Gurobi = DCMPOPFModelFactory(file_path, Gurobi.Optimizer)
# My_DC_model_Uncertainty = create_model(dc_factory_Gurobi, load_scenarios_factors)
# optimize_model(My_DC_model_Uncertainty)
# # Output the final Pg Values
# println("Final Pg values:")
# println()
# display(JuMP.value.(My_DC_model_Uncertainty.model[:pg]))
# # --------------------------------------------------------------------------\
