using PowerModels, JuMP, Ipopt, Gurobi, CSV, DataFrames
include("MPOPF.jl")
include("rampingCSVimplementation.jl")
include("search_functions.jl")
include("search2.jl")
using .MPOPF

# Initialize data files and variables
matpower_file_path = "./Cases/case30Q.m"
output_dir = "./Cases"
data = PowerModels.parse_file(matpower_file_path)
PowerModels.standardize_cost_terms!(data, order=2)
PowerModels.calc_thermal_limits!(data)

results = []

# Generate the CSV used for auxilary ramping data
ramping_csv_file = generate_power_system_csv(data, output_dir)
# Parse the ramping data
ramping_data, demands = parse_power_system_csv(ramping_csv_file, matpower_file_path)
# Create factory for building model
search_factory = DCMPOPFSearchFactory(matpower_file_path, Gurobi.Optimizer)
# Initialize model with data and set num of time periods
search_model = create_search_model(search_factory, 12, ramping_data, demands)
# Optimize the model (this is the entire model, not decomposed. We can compare out search against this answer)
optimize!(search_model.model)


# Run a search on the same model and data as our optimal model
best_solution, best_cost, best_models, base_cost, current_demands, total_iterations = decomposed_mpopf_demand_search(search_factory, 12, ramping_data, demands)

# Cost of the non decomposed optimal model found by Gurobi
#println("Full model cost:, ", objective_value(search_model.model))
# Cost of the decomposed search model
#println("Decomposed model cost: $best_cost1")

push!(results, (objective_value(search_model.model), best_cost))


sum_of_opt = sum(x[1] for x in results)
sum_of_search = sum(x[2] for x in results)

println("Average difference: ")
println(sum_of_search / sum_of_opt)

