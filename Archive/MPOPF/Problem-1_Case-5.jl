using PowerModels
using Ipopt
using JuMP
const PM = PowerModels

include("functions.jl")

file_path = "./Cases/case5.m"

#a function to deal with two different time variables (done by gpt using Sajad's code)

# Time 1 optimization
data_time1 = PowerModels.parse_file(file_path)
PowerModels.standardize_cost_terms!(data_time1, order=2)
PowerModels.calc_thermal_limits!(data_time1)


pg_time1, cost1 = run_optimization(data_time1)
println("Time 1 generator outputs: ", pg_time1)

# Time 2 optimization with 3% increased demand
data_time2 = deepcopy(data_time1) # Make a copy of the original data

for (bus_id, load) in data_time2["load"]
    data_time2["load"][bus_id]["pd"] *= 1.03
end

pg_time2, cost2= run_optimization(data_time2)
println("Time 2 generator outputs: ", pg_time2)


val_vec = []
size = length(pg_time1)

for i in 1:size
    val = (pg_time2[i] - pg_time1[i])
    push!(val_vec, val)
end


println("The difference between the times: ", val_vec)

ramping = 0.0
for i in 1:size
    global ramping += abs(val_vec[i])
end


println("Total cost with ramping: ")
TotalCost = cost1 + cost2 + ramping*7 # So that I can use this in the plot-results file
println(TotalCost)



