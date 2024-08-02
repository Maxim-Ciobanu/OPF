using PlotlyJS, Dates

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
			open("output/$(file_name)", "a") do io
				write(io, string(now()))
				write(io, "\n\n")
				write(io, output)
				write(io, "\n\n")
			end
		else
			open("output/$(file_name)", "w") do io
				write(io, string(now()))
				write(io, "\n\n")
				write(io, output)
				write(io, "\n\n")
			end
		end
	
	# create a new output file
	else

		# get the number of files in the directory
		num = length(files) + 1

		open("output/output_$(num).txt", "w") do io
			write(io, string(now()))
			write(io, "\n\n")
			write(io, output)
			write(io, "\n\n")
		end
	end
end






# struct for storing data about the graph
#
# plot: Any - the plotly plot
# traces: Vector{GenericTrace} - array of traces to be plotted
# location: String - save location
# ------------------------------------------------------------
mutable struct Graph
	plot::Any
	traces::Vector{GenericTrace} # array of traces to be plotted
	location::String # save location

	# constructor for the Graph struct
	function Graph(location::String)
		print("creating function with variables")
		new(nothing, Vector{GenericTrace}(), location)
	end
end


# a function for adding a scatter plot to the graph
# 
# graph: Graph - the graph to add the scatter plot to
# x: Array{Int} - x-axis values
# y: Array{Int} - y-axis values
# name: String - name of the trace ( optional )
# color: String - color of the trace ( optional )
# ------------------------------------------------------------
function add_scatter(graph::Graph, x::Array, y::Array, name::String="default name", color::String="blue")
	trace = PlotlyJS.scatter(x=x, y=y,
		mode="lines+markers",
		name=name,
		marker_color=color,
		hoverinfo="x+y", # Ensure hover displays both x and y values
		hovertemplate="%{x}, %{y:.2f}<extra></extra>") # Custom hover text format

	push!(graph.traces, trace)
end


# a function for creating the plot with 
#
# graph: Graph - the graph to be created from the traces
# title: String - title of the plot
# x_label: String - x-axis label
# y_label: String - y-axis label
# ------------------------------------------------------------
function create_plot(graph::Graph, title::String, x_label::String, y_label::String)

	# conditions
	if (length(graph.traces) < 1) throw("cannot create plot, no traces to plot") end

	# create the layout
	layout = Layout(
		title=title,
		xaxis=attr(title=x_label, tickangle=-45, tickmode="linear", tick0=0, dtick=1),
		yaxis=attr(title=y_label, hoverformat=".2f"),
		showlegend=true
	)

	# create the plot from the traces and the layout
	print(graph.traces)
	graph.plot = PlotlyJS.plot(graph.traces, layout)
end


# a function for saving a plot that is currently being create_model
#
# graph: Graph - the graph to be saved
# ------------------------------------------------------------
function save_graph(graph::Graph)
	
	print(graph.location)
	# minimum conditions to be met before saving
	if (graph.location == "") 
		throw("cannot save, location is not set") 
	end
	if (isnothing(graph.plot)) 
		throw("cannot save, plot is not set")
	end
	if (length(graph.traces) < 1)
		throw("cannot save, no traces to plot")
	end

	# save the plot in the location
	PlotlyJS.savefig(graph.plot, graph.location)
end


# a function for displaying the graph
#
# graph: Graph - the graph to be displayed
# ------------------------------------------------------------
function display_graph(graph::Graph)

	# check if the plot is set
	if (!graph.plot) throw("cannot display, plot is not set") end

	display(graph.plot)
end


# graph = Graph("output/plot.html")
# print(graph)
# add_scatter(graph, ["a", "b", "c", "d", "e"], [1, 2, 3, 4, 5], "trace 1", "blue")
# add_scatter(graph, ["a", "b", "c", "d", "e"], [5, 4, 3, 2, 1], "trace 2", "red")
# create_plot(graph, "my plot", "x-axis", "y-axis")
# save_graph(graph)