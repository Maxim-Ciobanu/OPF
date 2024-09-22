# Function for generating scenario load factors
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

function read_multi_period_data(ramping_file_path) 

    df = CSV.read(ramping_file_path, DataFrame)

    ramping_data = Dict(col => df[!, col] for col in names(df))

    return ramping_data
end


function safe_parse_float(s::AbstractString)
    

    try
        return parse(Float64, s)
    catch
        return missing  # or you could use missing
    end
end

# Do not leave cells blank, insert 0 for busses that don't demand power
function parse_power_system_csv(file_path::String, matpower_file_path::String)
    csv_content = read(file_path, String)
    lines = split(csv_content, '\n')
    csv_case_name = strip(lines[1])

    mat_power_case_name = basename(matpower_file_path)
    mat_power_case_name = replace(mat_power_case_name, ".m" => "")

    if csv_case_name != mat_power_case_name
        error("CSV case name ($csv_case_name) does not match the loaded MATPOWER case ($mat_power_case_name)")
    end
    
    # Read the entire CSV file into a DataFrame
    df = CSV.read(IOBuffer(join(lines[2:end], '\n')), DataFrame, header=1, skipto=2)
    # Initialize the output structures
    ramping_data = Dict{String, Vector{Float64}}()
    demands = Vector{Vector{Float64}}()

    # Find the row where bus data starts
    bus_data_start = findfirst(x -> x == "#bus_data", df[!, 1])

    # Process generator data
    gen_data = df[1:bus_data_start-1, :]
    ramping_data["gen_id"] = [safe_parse_float(x) for x in gen_data[!, 1] if x != "gen_id"]
    ramping_data["ramp_limits"] = [safe_parse_float(x) for x in gen_data[!, 2] if x != "ramp_limits"]
    ramping_data["costs"] = [safe_parse_float(x) for x in gen_data[!, 3] if x != "costs"]

    # Process bus data
    bus_data = df[bus_data_start+1:end, 2:end]
    for col in names(bus_data)
        push!(demands, filter(!ismissing, [safe_parse_float(x) for x in bus_data[!, col]]))
    end

    return ramping_data, demands
end