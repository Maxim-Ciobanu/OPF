using PlotlyJS

# Combined_Plot = make_subplots(rows=1, cols=3)

include("Problem-1_Case-5.jl")

base_point_trace = scatter(x=[" "], y=[TotalCost], mode="markers", name="Base Cost", marker=attr(color="Red", symbol="triangle-up", size=20))

# add_trace!(Combined_Plot, base_point_trace, row=1, col=1)

include("Problem-3_Case-5.jl")

bar_names = ["Pg1", "Pg2", "Pg3", "Pg4", "Pg5"]

single_trace_scatter_blue = scatter(x=bar_names, y=[cost_vector[1], cost_vector[3], cost_vector[5], cost_vector[7], cost_vector[9]], mode="lines+markers", name="Plus epsilon", marker_color="blue", xaxis="x2", yaxis="y2")
single_trace_scatter_red = scatter(x=bar_names, y=[cost_vector[2], cost_vector[4], cost_vector[6], cost_vector[8], cost_vector[10]], mode="lines+markers", name="Minus epsilon", marker_color="red", xaxis="x2", yaxis="y2")

# add_trace!(Combined_Plot, single_trace_scatter_blue, row=1, col=2)
# add_trace!(Combined_Plot, single_trace_scatter_red, row=1, col=2)

include("Plotting-Problem-3pairs_Case-5.jl")

# pp_pair_trace_scatter = scatter(x=plotting_x, y=[pair[1] for pair in cost_vector_pairs_plus_plus], mode="lines+markers", name="i+epsilon, j+epsilon", marker_color="green", xaxis="x3", yaxis="y3")
# pm_pair_trace_scatter = scatter(x=plotting_x, y=[pair[1] for pair in cost_vector_pairs_plus_minus], mode="lines+markers", name="i+epsilon, j-epsilon", marker_color="#FF4162", xaxis="x3", yaxis="y3")
# mp_pair_trace_scatter = scatter(x=plotting_x, y=[pair[1] for pair in cost_vector_pairs_minus_plus], mode="lines+markers", name="i-epsilon, j+epsilon", marker_color="orange", xaxis="x3", yaxis="y3")
# mm_pair_trace_scatter = scatter(x=plotting_x, y=[pair[1] for pair in cost_vector_pairs_minus_minus], mode="lines+markers", name="i-epsilon, j-epsilon", marker_color="black", xaxis="x3", yaxis="y3")

pp_y_values = [pair[2] != "LOCALLY_INFEASIBLE" ? pair[1] : missing for pair in cost_vector_pairs_plus_plus]
pp_pair_trace_scatter = scatter(x=plotting_x, y=pp_y_values, mode="lines+markers", name="i+epsilon, j+epsilon", marker_color="green", xaxis="x3", yaxis="y3")

pm_y_values = [pair[2] != "LOCALLY_INFEASIBLE" ? pair[1] : missing for pair in cost_vector_pairs_plus_minus]
pm_pair_trace_scatter = scatter(x=plotting_x, y=pm_y_values, mode="lines+markers", name="i+epsilon, j-epsilon", marker_color="#FF4162", xaxis="x3", yaxis="y3")

mp_y_values = [pair[2] != "LOCALLY_INFEASIBLE" ? pair[1] : missing for pair in cost_vector_pairs_minus_plus]
mp_pair_trace_scatter = scatter(x=plotting_x, y=mp_y_values, mode="lines+markers", name="i-epsilon, j+epsilon", marker_color="orange", xaxis="x3", yaxis="y3")

mm_y_values = [pair[2] != "LOCALLY_INFEASIBLE" ? pair[1] : missing for pair in cost_vector_pairs_minus_minus]
mm_pair_trace_scatter = scatter(x=plotting_x, y=mm_y_values, mode="lines+markers", name="i-epsilon, j-epsilon", marker_color="black", xaxis="x3", yaxis="y3")

# add_trace!(Combined_Plot, pp_pair_trace_scatter, row=1, col=3)
# add_trace!(Combined_Plot, pm_pair_trace_scatter, row=1, col=3)
# add_trace!(Combined_Plot, mp_pair_trace_scatter, row=1, col=3)
# add_trace!(Combined_Plot, mm_pair_trace_scatter, row=1, col=3)

# Find minimum values and their indices
min_value_blue, min_index_blue = findmin([cost_vector[1], cost_vector[3], cost_vector[5], cost_vector[7], cost_vector[9]])
min_value_red, min_index_red = findmin([cost_vector[2], cost_vector[4], cost_vector[6], cost_vector[8], cost_vector[10]])
min_value_pp, min_index_pp = findmin(skipmissing(pp_y_values))
min_value_pm, min_index_pm = findmin(skipmissing(pm_y_values))
min_value_mp, min_index_mp = findmin(skipmissing(mp_y_values))
min_value_mm, min_index_mm = findmin(skipmissing(mm_y_values))

# Find the minimum between min_value_blue and min_value_red
min_value_single, min_index_single = findmin([min_value_blue, min_value_red])
min_index_single = min_index_single == 1 ? min_index_blue : min_index_red

# Find the minimum among the rest of the traces
min_value_pairs, min_index_pairs = findmin([min_value_pp, min_value_pm, min_value_mp, min_value_mm])
min_index_pairs = min_index_pairs == 1 ? min_index_pp : min_index_pairs == 2 ? min_index_pm : min_index_pairs == 3 ? min_index_mp : min_index_mm

# Create annotations
annotations=[
    attr(
        x=" ",
        y=TotalCost,
        xref="x",
        yref="y",
        text="$(round(TotalCost, digits=2))",
        showarrow=true,
        font=attr(
            family="Courier New, monospace",
            size=16,
            color="#ffffff"
        ),
        align="center",
        arrowhead=2,
        arrowsize=1,
        arrowwidth=2,
        arrowcolor="#636363",
        ax=0,
        ay=50,
        bordercolor="#c7c7c7",
        borderwidth=2,
        borderpad=4,
        bgcolor="#ff7f0e",
        opacity=0.8
    )  

    attr(
        x=bar_names[min_index_single],
        y=min_value_single,
        xref="x2",
        yref="y2",
        text="Minimum Value = $(round(min_value_single, digits=2))",
        showarrow=true,
        font=attr(
            family="Courier New, monospace",
            size=16,
            color="#ffffff"
        ),
        align="center",
        arrowhead=2,
        arrowsize=1,
        arrowwidth=2,
        arrowcolor="#636363",
        ax=0,
        ay=50,
        bordercolor="#c7c7c7",
        borderwidth=2,
        borderpad=4,
        bgcolor="#ff7f0e",
        opacity=0.8
    )    
    
    attr(
        x=plotting_x[min_index_pairs], 
        y=min_value_pairs,
        xref="x3",
        yref="y3",
        text="Minimum Value = $(round(min_value_pairs, digits=2))", 
        showarrow=true,
        font=attr(
            family="Courier New, monospace",
            size=16,
            color="#ffffff"
        ),
        align="center",
        arrowhead=2,
        arrowsize=1,
        arrowwidth=2,
        arrowcolor="#636363",
        ax=-100,
        ay=50,
        bordercolor="#c7c7c7",
        borderwidth=2,
        borderpad=4,
        bgcolor="#ff7f0e",
        opacity=0.8
    )
]
# Determine the maximum y-value across all data
max_y = maximum([
    TotalCost,
    cost_vector[1], cost_vector[3], cost_vector[5], cost_vector[7], cost_vector[9],
    cost_vector[2], cost_vector[4], cost_vector[6], cost_vector[8], cost_vector[10],
    maximum(cost_vector_pairs_plus_plus[1][1]), 
    maximum(cost_vector_pairs_plus_minus[1][1]), 
    maximum(cost_vector_pairs_minus_plus[1][1]), 
    maximum(cost_vector_pairs_minus_minus[1][1])
]) + 500

# Determine the minimum y-value across all data
min_y = minimum([
    TotalCost,
    cost_vector[1], cost_vector[3], cost_vector[5], cost_vector[7], cost_vector[9],
    cost_vector[2], cost_vector[4], cost_vector[6], cost_vector[8], cost_vector[10],
    minimum(cost_vector_pairs_plus_plus[1][1]), 
    minimum(cost_vector_pairs_plus_minus[1][1]), 
    minimum(cost_vector_pairs_minus_plus[1][1]), 
    minimum(cost_vector_pairs_minus_minus[1][1])
]) - 500

Combined_Plot = plot(
    [base_point_trace, single_trace_scatter_blue, single_trace_scatter_red, pp_pair_trace_scatter, pm_pair_trace_scatter, mp_pair_trace_scatter, mm_pair_trace_scatter],
    Layout(
        xaxis_domain=[0, 0.1],
        xaxis2_domain=[0.2, 0.4],
        xaxis3_domain=[0.5, 1],
        yaxis=attr(range=[min_y, max_y]),
        yaxis2=attr(anchor="x2", overlaying="y", range=[min_y, max_y]),
        yaxis3=attr(anchor="x3", overlaying="y", range=[min_y, max_y])
    )
)

# Adding axis labels and title
relayout!(Combined_Plot, title="Local Search for minimum Cost with Epsilon of 0.1",
        xaxis_title="Base Cost Value",
        xaxis2_title="single Pg's Affected",
        yaxis_title="Total Cost",
        xaxis3_title="Pair Pg's Affected",
        xaxis3=attr(tickangle=-45),
        annotations=annotations
)

display(Combined_Plot)

# For updating GitHub Pages
# savefig(Combined_Plot, "index.html")
