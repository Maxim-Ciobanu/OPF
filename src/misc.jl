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

function output_to_file(output::String, file_name::String="")
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
			println("File already exists")
		else
			open("output/$(file_name)", "w") do io
				write(io, output)
			end
		end
	
	# create a new output file
	else

		# get the number of files in the directory
		num = length(files) + 1

		open("output/output_$(num).txt", "w") do io
			write(io, output)
		end
	end
end