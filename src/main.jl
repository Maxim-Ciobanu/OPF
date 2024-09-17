#############################################################################
# Note: This file is curently being used for examples, nothing is permanent
#############################################################################

using JuMP, Ipopt, Serialization
using MPOPF

function load_and_compile_models(results_directory::String)
    # Define model types and their corresponding colors
    model_types = ["AC", "DC", "Linear", "Logarithmic", "Quadratic"]

    # Get all case directories
    case_dirs = sort(filter(isdir, readdir(results_directory, join=true)))
    
    # Create a list to store case information and results
    case_data = []

    for case_dir in case_dirs
        case_name = basename(case_dir)
        case_results = Dict()

        for model in model_types
            results_file = joinpath(case_dir, model, "optimized_model.jls")
            if isfile(results_file)
                data = open(deserialize, results_file)
                case_results[model] = data
            end
        end

        # Only add cases where we have both results and bus count
        if !isempty(case_results)
            push!(case_data, (case_name, case_results))
        end
    end

    # Initialize nested dictionary to store results for each model and case
    model_results = Dict{String, Dict{String, Any}}()
    for (case_name, _) in case_data
        model_results[case_name] = Dict()
    end

    # Collect results for each model and case
    for (case_name, case_results) in case_data
        for model in model_types
            if haskey(case_results, model)
                data = case_results[model]
                model_results[case_name][model] = data
            else
                model_results[case_name][model] = NaN
            end
        end
    end

    # TODO: Add code here to save graphs if save_to_file is true

    return model_results
end

models = load_and_compile_models("./results")

for case in keys(models)
	println("\n\n\nCase: ", case)
	for model in keys(models[case])
		model = models[case][model].model

		try
			# check feasibility of the constraints
			find_infeasible_constraints(model)
		catch
			println("No infeasible constraints found")
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
