# Note: Add JLG2 package, needed to load data
using PowerModels, Gurobi, JuMP, JLD2
const PM = PowerModels
include("functions.jl")

file_path = "./Cases/case5.m"

data = PowerModels.parse_file(file_path)
PowerModels.standardize_cost_terms!(data, order=2)
PowerModels.calc_thermal_limits!(data)

# Load initial values of pg from Problem-2_Case5
@load "./Attachments/saved_data.jld2" initial_pg_values
epsilon = 0.000001
t = 1
i = 1
test = run_MPOPF_local_search(data, initial_pg_values, epsilon, t, i)
display(value.(test))
test = value.(test)

test2 = run_MPOPF_local_search(data, test, epsilon, t, i)
value.(test)