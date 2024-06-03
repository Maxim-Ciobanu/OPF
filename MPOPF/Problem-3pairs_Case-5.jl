using PowerModels, PlotlyJS
using Ipopt
using JuMP
const PM = PowerModels

include("functions.jl")

file_path = "./Cases/case5.m"

# Time 1 optimization
data_time1 = PowerModels.parse_file(file_path)
PowerModels.standardize_cost_terms!(data_time1, order=2)
PowerModels.calc_thermal_limits!(data_time1)

pg_time1, cost1 = run_optimization(data_time1)

# Time 2 optimization with 3% increased demand
data_time2 = deepcopy(data_time1) # Make a copy of the original data

for (bus_id, load) in data_time2["load"]
    data_time2["load"][bus_id]["pd"] *= 1.03
end

pg_time2, cost2= run_optimization(data_time2)

val_vec = []
size = length(pg_time1)

for i in 1:size
    val = (pg_time2[i] - pg_time1[i])
    push!(val_vec, val)
end

initialRamping = 0.0
for i in 1:size
    global initialRamping += abs(val_vec[i])
end


cost_vector_pairs = []
for i in 1:size
    global epsilon = 0.1
    global ramping = 0.0
    for j in 1:size
        push!(plotting_x, "Pg"*string(i)*string(j))
        for d in 1:2
            pg_change1, cost_after_change1 = run_optimization_changes2(data_time1, pg_time1, epsilon, i, j)
            pg_change2, cost_after_change2 = run_optimization_changes2(data_time2, pg_time2, epsilon, i, j)
            diff_vec = []
            for k in 1:size
                diff = abs(pg_change2[k] - pg_change1[k])
                push!(diff_vec, diff)
            end
            for k in 1:size
                global ramping += diff_vec[k]
            end

            epsilon *= -1
            push!(cost_vector_pairs, cost_after_change1 + cost_after_change2 + ramping*7)
            ramping = 0.0
        end
    end
end

display(cost_vector_pairs)

# # Initialize x axis
# x = collect(1:length(cost_vector_pairs))

# # Create the plot
# plot_data = scatter(x=x, y=cost_vector_pairs, mode="lines+markers", name="Cost")

# # Create layout
# layout = Layout(title="Change in Cost for Pairs of Variables. Epsilon = 0.1",
#                 xaxis_title="Iteration",
#                 yaxis_title="Cost")

# # Combine the data and layout into a plot
# plt = plot(plot_data, layout)
# display(plt)
println("Initial optimal cost: ", cost1 + cost2 + initialRamping*7)
println("Lowest cost in neighbourhood after changes: ", minimum(cost_vector_pairs))
