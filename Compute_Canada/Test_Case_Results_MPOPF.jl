using PowerModels
using Ipopt
using Serialization
using JuMP
using MPOPF

# Path to the case file
case_file = "../Cases/US.m"

# Function to solve OPF and return results
function solve_and_get_results(case_file, max_iter)
    ipopt = optimizer_with_attributes(Ipopt.Optimizer,
        "max_iter" => max_iter
    )
    ac_factory = ACMPOPFModelFactory(case_file, ipopt)
    My_AC_model = create_model(ac_factory)
    optimize_model(My_AC_model)
    return My_AC_model
end

# Function to save results to a file
function save_results(result, filename)
    open(filename, "w") do io
        serialize(io, result)
    end
    println("Results saved to $filename")
end

# Function to load results from a file
function load_results(filename)
    result = open(deserialize, filename)
    println("Results loaded from $filename")
    return result
end

function print_results(model::JuMP.Model)
    println("Objective Value (Total Cost): ", objective_value(model))

    println("\nGenerator Active Power (Pg) Values:")
    display(JuMP.value.(model[:pg]))


    println("\nGenerator Reactive Power (Qg) Values:")
    display(JuMP.value.(model[:qg]))

    println("\nVoltage Magnitude (Vm) Values:")
    display(JuMP.value.(model[:vm]))

    println("\nVoltage Angle (Va) Values:")
    display(JuMP.value.(model[:va]))
end



My_model = solve_and_get_results(case_file, 1000000)
print_results(My_model.model)

save_results(My_model, "MPOPF_US_Job.jld")

# To load and print results later, you can use:
# loaded_result = load_results("MPOPF_US_Job.jld")
# print_results(loaded_result.model)