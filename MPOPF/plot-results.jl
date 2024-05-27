include("Problem-1_Case-5.jl")
include("Problem-3_Case-5.jl")
include("Problem-3pairs_Case-5.jl")

using PlotlyJS


bar_names = ["Pg1", "Pg2", "Pg3", "Pg4", "Pg5"]

trace1 = bar(x=bar_names, y=[cost_vector[1], cost_vector[3], cost_vector[5], cost_vector[7], cost_vector[9]], name="Plus epsilon", marker_color="blue")
trace2 = bar(x=bar_names, y=[cost_vector[2], cost_vector[4], cost_vector[6], cost_vector[8], cost_vector[10]], name="Minus epsilon", marker_color="red")
trace3 = scatter(x=bar_names, y=[cost_vector[1], cost_vector[3], cost_vector[5], cost_vector[7], cost_vector[9]], name="Plus epsilon", marker_color="blue")
trace4 = scatter(x=bar_names, y=[cost_vector[2], cost_vector[4], cost_vector[6], cost_vector[8], cost_vector[10]], name="Minus epsilon", marker_color="red")

common_layout = Layout(
    title="Change in cost for Single Variables. Epsilon = 0.2",
    xaxis_title="Variables",
    yaxis_title="Total Cost",
    barmode="group",
)


single_var_bar = plot([trace1, trace2], common_layout)

single_var_scatter = plot([trace3, trace4], common_layout)

p = [single_var_bar single_var_scatter; plt]

savefig(p, "index.html")