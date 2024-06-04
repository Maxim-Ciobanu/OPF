# Note: Add JLG2 package, needed to load data
using PowerModels, Gurobi, JuMP, JLD2, Ipopt
const PM = PowerModels
include("functions.jl")

file_path = "./Cases/case5.m"

data = PowerModels.parse_file(file_path)
PowerModels.standardize_cost_terms!(data, order=2)
PowerModels.calc_thermal_limits!(data)

# Load initial values of pg from Problem-2_Case5
@load "./Attachments/saved_data.jld2" initial_pg_values

# Use random epsilon with range 0.005 - 0.025
epsilon = -(0.025 + (0.005 - 0.025) * rand())

# Solver to be used 
solver = Ipopt

t = rand(1:24)
i = rand(1:5)
test = run_MPOPF_local_search(solver, data, initial_pg_values, epsilon, t, i)
display(value.(test))
#test = value.(test)
#=
test2 = run_MPOPF_local_search(data, test, epsilon, t, i)
value.(test)
=#
println("T: ", t)
println("i: ", i)