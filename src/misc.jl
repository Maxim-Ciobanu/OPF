# Functionf or scenarios
function generate_load_scenarios(num_scenarios::Int, num_buses::Int)
    load_scenarios_factors = Dict()
    for scenario in 1:num_scenarios
        bus_factors = Dict()
        for bus in 1:num_buses
            if scenario == 1
                factor = 1.0
                bus_factors[bus] = factor
            elseif scenario == 2
                factor = 1.02
                bus_factors[bus] = factor
            else 
                factor = 0.98
                bus_factors[bus] = factor
            end
        end
        load_scenarios_factors[scenario] = bus_factors
    end
    return load_scenarios_factors
end