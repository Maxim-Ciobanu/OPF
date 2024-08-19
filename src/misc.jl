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


# a function for serializing data to a file
# updates the values if the file already exists
#
# output: Any - the data to be saved
# file_name: String - the name of the file to be saved
function save(file_name::String, output::Any)

	# Cretes the directory if it does not already exist
	mkpath(dirname(file_name))

	# check if the output directory exists
	if retreive(file_name) !== false
		data = retreive(file_name)
		data = merge(data, output)
		serialize(file_name, data)
	else
		serialize(file_name, output)
	end
end


# a function for deserializing data from a file, return false if not found
#
# file_name: String - the name of the file to be retrieved
function retreive(file_name::String)
	if isfile(file_name)
		data::Dict = deserialize(file_name)
		
		if data isa Dict
			return data
		else
			return false
		end
	else
		return false
	end
end


# Function for outputing string to file
#
# output: String - the output to be saved
# file_name: String - the name of the file to be saved
# show_date: Bool - whether to show the date in the file above the output
function output_to_file(output::String, file_name::String="", show_date::Bool=false)
	# check if the output directory exists
	if !isdir("output")
		mkdir("output")
	end

	# list all of the files in this directory
	files = readdir("output")

	# append to file
	if (file_name !== "")
		
		# check if it already exists
		if file_name in files
			open("output/$(file_name)", "a") do io
				if show_date write(io, string(now())); write(io, "\n\n") end
				write(io, output)
				write(io, "\n\n")
			end
		else
			open("output/$(file_name)", "w") do io
				if show_date write(io, string(now())); write(io, "\n\n") end
				write(io, output)
				write(io, "\n\n")
			end
		end
	
	# create a new output file
	else

		# get the number of files in the directory
		num = length(files) + 1

		open("output/output_$(num).txt", "w") do io
			write(io, string(now()))
			write(io, "\n\n")
			write(io, output)
			write(io, "\n\n")
		end
	end
end






