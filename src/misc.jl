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