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

function output_to_file(output::String, file_name::String="")
	# check if the output directory exists
	if !isdir("output")
		mkdir("output")
	end

	# list all of the files in this directory
	files = readdir("output")

	# append to file
	if (file_name !== "")
		
		# check if it already exists
		if file_name in files
			println("File already exists")
		else
			open("output/$(file_name)", "w") do io
				write(io, output)
			end
		end
	
	# create a new output file
	else

		# get the number of files in the directory
		num = length(files) + 1

		open("output/output_$(num).txt", "w") do io
			write(io, output)
		end
	end
end

# Function for plotting the objective cost against solver iterations
# x: Array{Int} - x-axis values
# y: Array{Int} - y-axis values
# x_label: String - x-axis label
# y_label: String - y-axis label
# -------------------------------------------------------------
function plot_graph(x, y, x_label, y_label)
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

	return My_plot
end

# graph = plot_graph([1, 2, 3, 4, 5], [1, 2, 3, 4, 5], "X label", "Y label")
# display(graph)

using Plots
x = 1:10; y = rand(10); 
p = Plots.plot(x, y)
savefig(p, "output/plots/plot.png")