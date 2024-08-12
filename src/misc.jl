using PlotlyJS, Dates, Serialization 

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


# a function for serializing data to a file
#
# output: Any - the data to be saved
# file_name: String - the name of the file to be saved
function save(file_name::String, output::Any)
	serialize(file_name, output)
end


# a function for deserializing data from a file, return false if not found
#
# file_name: String - the name of the file to be retrieved
# case: Int - the case number corresponding the the dictionary key value
function retreive(file_name::String, case::Int)
	if isfile(file_name)
		data::Dict = deserialize(file_name)
		
		if data isa Dict
			if case in keys(data)
				return data[case]
			else
				return false
			end
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






