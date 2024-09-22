using PowerModels, JuMP, Ipopt, CSV, DataFrames
include("MPOPF.jl")
include("misc.jl")
include("search_functions.jl")
include("search2.jl")
using .MPOPF



# Example usage:
matpower_file_path = "./Cases/case14.m"
csv_file_path = "./Cases/rampingData.csv"
data = PowerModels.parse_file(matpower_file_path)
PowerModels.standardize_cost_terms!(data, order=2)
PowerModels.calc_thermal_limits!(data)

#=
ramp_limits = fill(10000, 420) #0.2 .+ 0.4 .* rand(69)
costs = fill(7, 420) #700 .+ 100 .* rand(69)
ramping_data = Dict(
    "ramp_limits" => ramp_limits,
    "costs" => costs
    )
    
    #demands = [5 .+ 10 .* rand(420) for _ in 1:24]
    
    demand_dict = Dict{Int, Float64}()
    
    
# Iterate through the loads in the data
for (_, load) in data["load"]
    bus_id = load["load_bus"]
    pd = get(load, "pd", 0.0)
    
    # Add the demand to the dictionary, summing if multiple loads on same bus
    demand_dict[bus_id] = get(demand_dict, bus_id, 0.0) + pd
end

# Create a vector of demands, ensuring we have a value for each bus
num_buses = length(data["bus"])
demand = [get(demand_dict, i, 0.0) for i in 1:num_buses]

demand = repeat([demand], 24)
=#
#=
demands = []
for (bus_id, load) in data["load"]
    push!(demands, (bus_id, data["load"][bus_id]["pd"]))
end
sort!(demands, by = x -> x[1])
loads = [load for (bus_id, load) in demands]
loads = repeat([loads], 24)
demands = loads
=#

#=
ramping_data = Dict(
    #"ramp_limits" => [0.261308, 0.179846, 0.127649, 0.256349, 0.124095], # These ramp limits arent working
    "ramp_limits" => [0.5, 0.5, 0.5, 0.5, 0.5],
    #"costs" => [27.1089, 59.3871, 79.9998, 27.0244, 48.7984]
    "costs" => [7, 7, 7, 7, 7]
)

demands = [
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149],
    [0.217, 0.942, 0.478, 0.076, 0.112, 0.295, 0.09, 0.035, 0.061, 0.135, 0.149]
]

demands[2] .*= 1.1
demands[3] .*= 0.9
demands[4] .*= 1
demands[5] .*= 1.1
demands[6] .*= 0.9
demands[7] .*= 1.2
demands[8] .*= 1.1
demands[9] .*= 1.2
demands[10] .*= 1.1
demands[11] .*= 0.9
demands[12] .*= 1.2
demands[13] .*= 1.1
demands[14] .*= 1.2
demands[15] .*= 1.1
demands[16] .*= 0.9
demands[17] .*= 1.2
demands[18] .*= 1.3
demands[19] .*= 1.2
demands[20] .*= 1.1
demands[21] .*= 0.9
demands[22] .*= 1.2
demands[23] .*= 1.1
demands[24] .*= 0.9
=#
ramping_data, demands = parse_power_system_csv(csv_file_path, matpower_file_path)

# Total demand for initial case adjusted order=2 is 2.59
search_factory = DCMPOPFSearchFactory(matpower_file_path, Ipopt.Optimizer)
search_model = create_search_model(search_factory, 5, ramping_data, demands)
optimize_model(search_model)

#best_solution1, best_cost1, best_models1, base_cost1 = decomposed_mpopf_local_search(search_factory, 3, ramping_data, demands)


#best_solution2, best_cost2, best_models2, base_cost2, final_demands, total_iterations = decomposed_mpopf_demand_search(search_factory, 24, ramping_data, demands)
#=
println()
println("Full model cost:, ", objective_value(search_model.model))
println("Decomposed model cost: $best_cost2")
println("Base cost: $base_cost2")
println("Full model pg values:")
display(value.(search_model.model[:pg]))
println("Decomposed model pg values:")
display(best_solution2)
println("Base cost / best cost: ", base_cost2 / best_cost2)
println("Optimal / found solution: ", objective_value(search_model.model) / best_cost2)
#println(total_iterations) =#

#decomposed_model = create_decomposed_mpopf_model(search_factory, 24, ramping_data, demands)


#= Ramping rates
It seems traditional gas/coal plants can ramp very quickly,
to the point where its not much of a constraint
Nuclear has very low ramping rates, treat as static
(Moder nuclear plants can change up to 5% per minute, but only change once or twice per day)
Renewable (solar/wind) have ramp rates that we cannot control
=#

#= Ramping costs
Solar = N/A
Wind = N/A
Gas/Coal = $2.43 - $4.68 (MWh)

=#

#=
solution, models = create_initial_solution(search_factory, data, 24, demand, ramping_data)

total = 0
for x in models
    global total += objective_value(x[2].model)
end

sol = []
for t in 1:24
    

    indices = axes(search_model.model[:pg], 2)

    test = Dict{Int, Float64}()

    for (i, gen_id) in enumerate(indices)
        test[gen_id] = value(search_model.model[:pg][1, gen_id])
    end
end

for i in 1:420
    println("Gen $i:")
    println(value.(search_model.model[:pg][1, i]))
    println(solution[1][i])
end
=#

#factory = DCMPOPFSearchFactory(file_path, Gurobi.Optimizer)
#model = create_search_model(factory, 24, ramping_data, demands)
#optimize_model(model)

