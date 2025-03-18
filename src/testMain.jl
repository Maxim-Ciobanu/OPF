using JuMP, Ipopt, Gurobi, Serialization, Random, Graphs, MetaGraphs, MathOptInterface
using PowerModels
using MPOPF
using Statistics, Plots, GraphRecipes

include("graph_search.jl")
include("search_functions.jl")

matpower_file_path = "./Cases/case300.m"
output_dir = "./Cases"
data = PowerModels.parse_file(matpower_file_path)
PowerModels.standardize_cost_terms!(data, order=2)
PowerModels.calc_thermal_limits!(data)

ramping_csv_file = generate_power_system_csv(data, output_dir)
ramping_data, demands = parse_power_system_csv(ramping_csv_file, matpower_file_path)

search_factory = DCMPOPFSearchFactory(matpower_file_path, Ipopt.Optimizer)
search_model = create_search_model(search_factory, 1, ramping_data, demands)
optimize!(search_model.model)


#DC_Factory = DCMPOPFModelFactory(matpower_file_path, Gurobi.Optimizer)
#DC_model = create_model(DC_Factory)
#optimize_model(DC_model)
#graph, scenarios, full_path, total_cost, solution = iter_search(search_factory, demands, ramping_data, 12)


# add mu_plus and mu_minus, from implementation_uncertainty (look at DC implementation, bottom)


# Create a new model with fixed generator values from your graph solution
#=
verification_model = create_search_model(search_factory, 12, ramping_data, demands)
for t in keys(solution)
    for (gen, val) in solution[t]["generator_values"]
        fix(verification_model.model[:pg][t, gen], val, force=true)
    end
end
optimize!(verification_model.model)
status = termination_status(verification_model.model)
println("Graph solution feasibility: $status")
if status == MOI.OPTIMAL || status == MOI.LOCALLY_SOLVED
    println("Objective value: $(objective_value(verification_model.model))")
end
=#
vioaltions = find_infeasible_constraints(search_model.model)

# p = power flow between along arcs between busses
# va = voltage angle
println("################")

violations2 = find_bound_violations(search_model.model)