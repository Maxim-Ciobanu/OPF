using PowerModels, PlotlyJS
using Ipopt
using JuMP

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

global status = nothing

plotting_x = [] # Used for the x axis when plotting later

cost_vector_pairs_plus_plus = []
cost_vector_pairs_plus_minus = []
cost_vector_pairs_minus_plus = []
cost_vector_pairs_minus_minus = []
for i in 1:size
    global epsilon1 = 0.1
    global epsilon2 = epsilon1*-1
    global ramping = 0.0
    for j in 1:size
        push!(plotting_x, "Pg"*string(i)*string(j))
        println("**************************************************")
        println("Pg"*string(i)*string(j))
        println("**************************************************")
        for b in 1:4
            if b == 1
                pg_change1, cost_after_change1, status1 = run_optimization_changes3(data_time1, pg_time1, epsilon1, epsilon1, i, j)
                pg_change2, cost_after_change2, status2 = run_optimization_changes3(data_time2, pg_time2, epsilon1, epsilon1, i, j)
            elseif b == 2
                pg_change1, cost_after_change1, status1 = run_optimization_changes3(data_time1, pg_time1, epsilon1, epsilon2, i, j)
                pg_change2, cost_after_change2, status2 = run_optimization_changes3(data_time2, pg_time2, epsilon1, epsilon2, i, j)
            elseif b == 3
                pg_change1, cost_after_change1, status1 = run_optimization_changes3(data_time1, pg_time1, epsilon2, epsilon1, i, j)
                pg_change2, cost_after_change2, status2 = run_optimization_changes3(data_time2, pg_time2, epsilon2, epsilon1, i, j)
            elseif b == 4
                pg_change1, cost_after_change1, status1 = run_optimization_changes3(data_time1, pg_time1, epsilon2, epsilon2, i, j)
                pg_change2, cost_after_change2, status2 = run_optimization_changes3(data_time2, pg_time2, epsilon2, epsilon2, i, j)
            end
            
            diff_vec = []
            for k in 1:size
                diff = abs(pg_change2[k] - pg_change1[k])
                push!(diff_vec, diff)
            end
            for k in 1:size
                global ramping += diff_vec[k]
            end

            overall_status = ""
            if (status1 == 1 && status2 == 1)
                overall_status = "LOCALLY_SOLVED"
            else
                overall_status = "LOCALLY_INFEASIBLE"
            end

            if b == 1
                push!(cost_vector_pairs_plus_plus, (cost_after_change1 + cost_after_change2 + ramping*7, overall_status))
            elseif b == 2
                push!(cost_vector_pairs_plus_minus, (cost_after_change1 + cost_after_change2 + ramping*7, overall_status))
            elseif b == 3
                push!(cost_vector_pairs_minus_plus, (cost_after_change1 + cost_after_change2 + ramping*7, overall_status))
            elseif b == 4
                push!(cost_vector_pairs_minus_minus, (cost_after_change1 + cost_after_change2 + ramping*7, overall_status))
            end
            println((cost_after_change1 + cost_after_change2 + ramping*7, overall_status))
            println("**************************************************")
            println()
            ramping = 0.0
        end
        println()
        println()
        println()
    end    
end

smallest_value = minimum([cost_vector_pairs_plus_plus; cost_vector_pairs_plus_minus; cost_vector_pairs_minus_plus; cost_vector_pairs_minus_minus])

println("Initial optimal cost: ", cost1 + cost2 + initialRamping*7)
println("Lowest cost in neighbourhood after changes: ", smallest_value)