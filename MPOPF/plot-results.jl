include("Problem-3_Case-5.jl")

using PlotlyJS

Combined_Plot = make_subplots(rows=1, cols=2, shared_yaxes=true)

bar_names = ["Pg1", "Pg2", "Pg3", "Pg4", "Pg5"]

single_trace_scatter_blue = scatter(x=bar_names, y=[cost_vector[1], cost_vector[3], cost_vector[5], cost_vector[7], cost_vector[9]], mode="lines+markers", name="Plus epsilon", marker_color="blue")
single_trace_scatter_red = scatter(x=bar_names, y=[cost_vector[2], cost_vector[4], cost_vector[6], cost_vector[8], cost_vector[10]], mode="lines+markers", name="Minus epsilon", marker_color="red")

add_trace!(Combined_Plot, single_trace_scatter_blue, row=1, col=1)
add_trace!(Combined_Plot, single_trace_scatter_red, row=1, col=1)

include("Problem-3pairs_Case-5.jl")

pair_trace_scatter_blue = scatter(x=plotting_x, y=cost_vector[1:2:end], mode="lines+markers", marker_color="blue", showlegend=false)
pair_trace_scatter_red = scatter(x=plotting_x, y=cost_vector[2:2:end], mode="lines+markers", marker_color="red", showlegend=false)

add_trace!(Combined_Plot, pair_trace_scatter_blue, row=1, col=2)
add_trace!(Combined_Plot, pair_trace_scatter_red, row=1, col=2)

# Adding axis labels and title
relayout!(Combined_Plot, title="Local Search for minimum Cost with Epsilon of 0.1",
        xaxis_title="single Pg's Affected",
        yaxis_title="Total Cost",
        xaxis2_title="Pair Pg's Affected")

Combined_Plot

savefig(Combined_Plot, "index.html")
