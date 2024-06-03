using PowerModels, Ipopt, JuMP
const PM = PowerModels

file_path = "./Cases/case5.m"

data = PowerModels.parse_file(file_path)
PowerModels.standardize_cost_terms!(data, order=2)
PowerModels.calc_thermal_limits!(data)

# Initialize variables
ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
bus_data = ref[:bus]
gen_data = ref[:gen]
branch_data = ref[:branch]
load_data = ref[:load]

gen_length = length(gen_data)
bus_length = length(bus_data)
branch_length = length(branch_data)
load_length = length(load_data)


# Create model
model = JuMP.Model(Ipopt.Optimizer)
# Set print level 
set_optimizer_attribute(model, "print_level", 5)

# Time periods
T = 2

# Set a ramping cost
ramping_cost = 7

@variable(model, va[t in 1:T, i in keys(ref[:bus])])

# Define variables
# Sets variables for each 1 -> T with upper and lower bounds
# PGtg where t = T and i = gen, PG21 is the first gen of second t
# Likewise for theta
@variable(model, gen_data[g]["pmin"] <= pg[t in 1:T, g in 1:gen_length] <= gen_data[g]["pmax"])
@variable(model, -360 <= theta[t in 1:T, b in 1:bus_length] <= 360, start = 0)

# Adjust demand for each T (increase by 3%)
# Initialize adjusted_demand as a dictionary
# adjusted_demand = Dict{Int, Vector{Float64}}()

# for t in 1:T
    # adjusted_demand[t] = Float64[]  # Initialize an empty vector for each time period
    # for i in 1:load_length
        # push!(adjusted_demand[t], load_data[i]["pd"] * (1 + 0.03 * (t - 1)))
    # end
# end

# Dont know if we need this but doesnt seem to affect solution
# Extract ramp rates (assuming you have added them in the case file)
# max_ramp_up = [gen_data[i]["ramp_agc"] for i in 1:gen_length]
# max_ramp_down = [gen_data[i]["ramp_10"] for i in 1:gen_length]


# Stuff below is from Sajads notebook
for t in 1:T
    for (i,bus) in ref[:ref_buses]
        @constraint(model, va[t,i] == 0)
    end
end
@variable(model, -ref[:branch][l]["rate_a"] <= p[1:T,(l,i,j) in ref[:arcs_from]] <= ref[:branch][l]["rate_a"])

p_expr = Dict()
for t in 1:T
    p_expr[t] = Dict()
end
# Iterate over each time period
for t in 1:T
    p_expr[t] = Dict([((l, i, j), 1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs_from]])
    p_expr[t] = merge(p_expr[t], Dict([((l, j, i), -1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs_from]]))
end

# increase = 1.0
for t in 1:T
    for (i,bus) in ref[:bus]
        # Build a list of the loads and shunt elements connected to the bus i
        bus_loads = [ref[:load][l] for l in ref[:bus_loads][i]]
        bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]

        # Active power balance at node i
        @constraint(model,
            sum(p_expr[t][a] for a in ref[:bus_arcs][i]) ==    
            sum(pg[t, g] for g in ref[:bus_gens][i]) -  # Note the double loop over t and g
            sum(load["pd"] for load in bus_loads) -       # Maybe add * increase here               
            sum(shunt["gs"] for shunt in bus_shunts)*1.0^2          
        )
    end
    # global increase += 0.03


# Branch power flow physics and limit constraints
    for (i,branch) in ref[:branch]
        # Build the from variable id of the i-th branch, which is a tuple given by (branch id, from bus, to bus)
        f_idx = (i, branch["f_bus"], branch["t_bus"])

        p_fr = p[t,f_idx]                     # p_fr is a reference to the optimization variable p[f_idx]

        va_fr = va[t,branch["f_bus"]]         # va_fr is a reference to the optimization variable va on the from side of the branch
        va_to = va[t,branch["t_bus"]]         # va_fr is a reference to the optimization variable va on the to side of the branch

        # Compute the branch parameters and transformer ratios from the data
        g, b = PowerModels.calc_branch_y(branch)

        # DC Power Flow Constraint
        @constraint(model, p_fr == -b*(va_fr - va_to))
    
        # Voltage angle difference limit
        @constraint(model, va_fr - va_to <= branch["angmax"])
        @constraint(model, va_fr - va_to >= branch["angmin"])
    end

end

# Objective function
# Minimum sum of cost for each T and ramping between T's
# Cost function: c1[i] * pg[i]^2 + c2[i] * pg[i] + c3[i]
# Ramping function: |pg t+1,1 - pg t,1| * ramping_cost for each i for each t - 1
@objective(model, Min,
    sum(gen_data[i]["cost"][1] * pg[t, i]^2 + gen_data[i]["cost"][2] * pg[t, i] + gen_data[i]["cost"][3]
        for t in 1:T, i in 1:gen_length) +
    sum(ramping_cost * abs((pg[t + 1, i] - pg[t, i]))
        for t in 1:T-1, i in 1:gen_length)
)

optimize!(model)
println("Optimal Cost: ", objective_value(model))

pgValues = JuMP.value.(pg)
thetaValues = JuMP.value.(theta)
println("Pg values: ")
display(pgValues)
println("Theta values: ")
display(value.(theta))