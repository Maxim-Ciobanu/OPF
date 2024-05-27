using PlotlyJS

# Define nodes and edges
nodes = [(1, 1), (2, 2), (3, 1), (4, 2)]
edges = [(1, 2), (2, 3), (3, 4), (4, 1)]

# Extract node positions and colors
node_positions = Dict(i => (x, y) for (i, (x, y)) in enumerate(nodes))
node_colors = [color == 1 ? "red" : "blue" for (i, color) in nodes]

# Create a list of edge traces
edge_traces = Vector{AbstractTrace}()
for (start, stop) in edges
    x_start, y_start = node_positions[start]
    x_end, y_end = node_positions[stop]
    push!(edge_traces, scatter(x=[x_start, x_end], y=[y_start, y_end],
                               mode="lines", line_color="gray", showlegend=false))
end

# Create a scatter trace for nodes
node_x = [pos[1] for pos in values(node_positions)]
node_y = [pos[2] for pos in values(node_positions)]
node_trace = scatter(x=node_x, y=node_y, mode="markers", marker_size=10,
                     marker_color=node_colors, text=1:4, showlegend=false)

# Combine the edge traces and node trace
plot_data = vcat(edge_traces, [node_trace])

# Create layout
layout = Layout(title="Happy-Net", xaxis=attr(showgrid=false, zeroline=false),
                yaxis=attr(showgrid=false, zeroline=false), showlegend=false)

# Plot the graph
plot(plot_data, layout)
