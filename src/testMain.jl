using JuMP, Ipopt, Gurobi, Serialization, Random, Graphs, MetaGraphs
using PowerModels
using MPOPF
using Statistics, Plots, GraphRecipes

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

graph, scenarios = search(search_factory, demands, ramping_data, 12)
println("done")