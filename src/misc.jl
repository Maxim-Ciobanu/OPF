using PlotlyJS

# Function for generating scenario load factors
# function generate_load_scenarios(num_scenarios::Int, num_buses::Int)
#     load_scenarios_factors = Dict()
#     for scenario in 1:num_scenarios
#         bus_factors = Dict()
#         for bus in 1:num_buses
#             factor = 1.0
#             if scenario == 1
#                 factor = 1.0
#             elseif scenario == 2
#                 factor = 1.01
#             elseif scenario == 3
#                 factor = 0.99
#             elseif scenario == 4
#                 factor = 0.98
#             elseif scenario == 5
#                 factor = 1.02
#             elseif scenario == 6
#                 factor = 0.97
#             elseif scenario == 7
#                 factor = 1.03
#             elseif scenario == 8
#                 factor = 0.96
#             elseif scenario == 9
#                 factor = 1.04
#             elseif scenario == 10
#                 factor = 0.95
#             end
#             bus_factors[bus] = factor
#         end
#         load_scenarios_factors[scenario] = bus_factors
#     end
#     return load_scenarios_factors
# end

function generate_load_scenarios(num_scenarios::Int, num_buses::Int)
    load_scenarios_factors = Dict()
    for scenario in 1:num_scenarios
        scenario_factor = rand(0.95:0.01:1.05)
        bus_factors = Dict()
        for bus in 1:num_buses
            bus_factors[bus] = scenario_factor
        end
        load_scenarios_factors[scenario] = bus_factors
    end
    return load_scenarios_factors
end

function plot_graph(x, y, x_label, y_label)
	# Plotting Code
	trace = scatter(x=x, y=y,
		mode="lines+markers",
		name="Objective Cost",
		marker_color="blue",
		hoverinfo="x+y", # Ensure hover displays both x and y values
		hovertemplate="%{x}, %{y:.2f}<extra></extra>") # Custom hover text format

	layout = Layout(
		title="Plotting Objective Cost agaist Solver Iterations",
		xaxis=attr(title=x_label, tickangle=-45, tickmode="linear", tick0=0, dtick=1),
		yaxis=attr(title=y_label, hoverformat=".2f"),
		showlegend=true)

	My_plot = plot([trace], layout)

	display(My_plot)
end

plot_graph([1, 2, 3, 4, 5], [1, 2, 3, 4, 5], "X label", "Y label")

