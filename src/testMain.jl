using JuMP, Ipopt, Gurobi, Serialization, Random, Graphs, MetaGraphs
using PowerModels
using MPOPF
using Statistics

include("graph_search.jl")
include("search_functions.jl")

matpower_file_path = "./Cases/case14.m"
output_dir = "./Cases"
data = PowerModels.parse_file(matpower_file_path)
PowerModels.standardize_cost_terms!(data, order=2)
PowerModels.calc_thermal_limits!(data)

ramping_csv_file = generate_power_system_csv(data, output_dir)
ramping_data, demands = parse_power_system_csv(ramping_csv_file, matpower_file_path)

search_factory = DCMPOPFSearchFactory(matpower_file_path, Gurobi.Optimizer)
search_model = create_search_model(search_factory, 12, ramping_data, demands)
optimize!(search_model.model)

largest = find_largest_time_period(12, demands)

model = build_and_optimize_largest_period(search_factory, demands[largest], ramping_data)

loads = generate_random_loads(model)
l = loads[1]
m = power_flow(search_factory, demands[largest], ramping_data, l)

#values = optimize_largest_period(search_factory, data, largest, demands)

# m = set_all_values_to_largest(data, 12, values, demands, ramping_data)


#=
test = create_initial_feasible_solution(data, 12, demands, ramping_data)
=#