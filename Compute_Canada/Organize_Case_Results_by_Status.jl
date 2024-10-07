using PowerModels
using Ipopt
using Serialization
using JuMP
using MPOPF

results_directory = "CC_results_copy/"

function check_status_files(results_directory::String)
    # Define model types
    model_types = ["AC", "DC", "Linear", "Logarithmic", "Quadratic"]

    # Get all case directories
    case_dirs = sort(filter(isdir, readdir(results_directory, join=true)))
    
    # Array to store cases with all status files present
    cases_with_status = String[]
    cases_without_status = String[]

    for case_dir in case_dirs
        case_name = basename(case_dir)
        status_present = false

        for model in model_types
            status_file = joinpath(case_dir, model, "status.jls")

            # Check if status file is missing
            if isfile(status_file)
                status_present = true
                break  # No need to check other models if one is missing
            end
        end

        # Add case to cases_with_status array if all status files are present
        if status_present
            push!(cases_with_status, case_name)
        else 
            push!(cases_without_status, case_name)
        end
    end

    return cases_with_status, cases_without_status
end

function check_status_files_detailed(results_directory::String)
    # Define model types
    model_types = ["AC", "DC", "Linear", "Logarithmic", "Quadratic"]

    # Get all case directories
    case_dirs = sort(filter(isdir, readdir(results_directory, join=true)))
    
    # Array to store cases with all status files present
    cases_with_status = String[]
    cases_without_status = String[]

    for case_dir in case_dirs
        case_name = basename(case_dir)
        status_present = false

        for model in model_types
            
            status_file = joinpath(case_dir, model, "status.jls")

            # Check if status file is missing
            if isfile(status_file)
                status_present = true
                # break  # No need to check other models if one is missing
            else
                status_present = false
            end

                # Add case to cases_with_status array if all status files are present
            if status_present
                push!(cases_with_status, joinpath(case_name, model))
            else 
                push!(cases_without_status, joinpath(case_name, model))
            end
            
        end


    end

    return cases_with_status, cases_without_status
end

cases_with_status, cases_without_status = check_status_files_detailed(results_directory)



cases_with_status


cases_without_status


# Define the file path
output_file_path = "output_detailed.txt"

# Open the file for writing
open(output_file_path, "w") do file
    # Write the string value of cases_with_status to the file
    println(file, "cases_with_status: ", string(cases_with_status))
    
    # Write the string value of cases_without_status to the file
    # println(file, "cases_without_status: ", string(cases_without_status))
end


using FileIO

function move_cases_by_status(results_directory::String, cases_with_status::Vector{String}, cases_without_status::Vector{String}, destination_with_status::String, destination_without_status::String)
    # Ensure destination directories exist
    mkpath(destination_with_status)
    mkpath(destination_without_status)

    # Move cases with status
    # for case_name in cases_with_status
    #     source_path = joinpath(results_directory, case_name)
    #     dest_path = joinpath(destination_with_status, case_name)
    #     if isdir(source_path)
    #         try
    #             cp(source_path, dest_path)
    #             println("Moved $case_name to $destination_with_status")
    #         catch e
    #             println("Error moving $case_name: $e")
    #         end
    #     else
    #         println("Directory not found for $case_name")
    #     end
    # end

    # Move cases without status
    for case_name in cases_without_status
        source_path = joinpath(results_directory, case_name)
        dest_path = joinpath(destination_without_status, case_name)
        # dest_path = joinpath(destination_without_status)
        if isdir(source_path)
            try
                mkpath(dest_path)
                cp(source_path, dest_path; force=true)
                println("Copied $case_name to $destination_without_status")
            catch e
                println("Error copying $case_name: $e")
            end
        else
            println("Directory not found for $case_name")
        end
    end
end

move_cases_by_status(results_directory, cases_with_status, cases_without_status, "destination_with_status_detailed", "destination_without_status_detailed")

source_path = joinpath(results_directory, cases_without_status[1])
dest_path = joinpath("destination_without_status_detailed")
cp(source_path, dest_path)