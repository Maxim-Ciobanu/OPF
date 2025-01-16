using JuMP, Ipopt, Gurobi, Serialization, Random
using PowerModels
using MPOPF
using Statistics
using CSV
using DataFrames

# load in all the cases
cases = load_and_compile_models("results/")

# load the graph
graph = Graph("output/graphs/case_status.html")


for case in keys(cases)

	# for each case check if at least one of the models is infeasible
	infeasible = false

	for model_type in keys(cases[case])
		model = cases[case][model_type].model
		termination = termination_status(model)
		if termination == LOCALLY_INFEASIBLE
			infeasible = true
		end
	end

	# if any of the models are infeasible show it
	if infeasible
		add_vertical_line(graph, case)
		
	end
end

create_plot(graph, "absolute difference in minmax equation of failed cases", "Case Number", "Abs Difference ( average )")
save_graph(graph)


