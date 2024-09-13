# Function to list all files in a directory and write their relative paths to a file
function write_relative_paths_to_file(directory::String, output_file::String)
    # Open the output file in write mode
    open(output_file, "w") do io
        # Iterate over all entries in the directory
        for entry in readdir(directory)
            # Construct the full path of the entry
            full_path = joinpath(directory, entry)
            
            # Check if the entry is a file (not a directory)
            if isfile(full_path)
                # Write the relative path to the output file, followed by a newline
                relative_path = joinpath(directory_path, entry)
                println(io, relative_path)
            end
        end
    end
end

# Example usage:
# Define the directory to search and the output file
directory_path = "Cases"
output_file_path = "cases.txt"

# Call the function with the specified paths
write_relative_paths_to_file(directory_path, output_file_path)
