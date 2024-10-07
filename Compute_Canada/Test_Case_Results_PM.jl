using PowerModels
using Ipopt
using Serialization

# Path to the case file
case_file = "../Cases/US.m"

# Function to solve OPF and return results
function solve_and_get_results(case_file, max_iter)
    ipopt = optimizer_with_attributes(Ipopt.Optimizer,
        "max_iter" => max_iter
    )
    result = solve_ac_opf(case_file, ipopt)
    return result
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

# Function to print results
function print_results(result)
    println("Objective Value (Total Cost): ", result["objective"])

    println("\nGenerator Active Power (Pg) Values:")
    for (g, gen) in result["solution"]["gen"]
        println("Generator $g: $(gen["pg"]) MW")
    end

    println("\nGenerator Reactive Power (Qg) Values:")
    for (g, gen) in result["solution"]["gen"]
        println("Generator $g: $(gen["qg"]) MVAr")
    end

    println("\nVoltage Magnitude (Vm) Values:")
    for (b, bus) in result["solution"]["bus"]
        println("Bus $b: $(bus["vm"]) p.u.")
    end

    println("\nVoltage Angle (Va) Values:")
    for (b, bus) in result["solution"]["bus"]
        println("Bus $b: $(bus["va"]) radians")
    end
end

# Solve OPF and get results
result = solve_and_get_results(case_file, 1000000)

# Save results to a file
save_results(result, "PM_US_Job.jld")

# Print results
print_results(result)

# To load and print results later, you can use:
# loaded_result = load_results("PM_US_Job.jld")
# print_results(loaded_result)