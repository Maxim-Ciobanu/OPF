using PowerModels, Ipopt, JuMP
const PM = PowerModels

file_path = "case5.m"

data = PowerModels.parse_file(file_path)
PowerModels.standardize_cost_terms!(data, order=2)
PowerModels.calc_thermal_limits!(data)

# Initialize variables
ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
bus_data = ref[:bus]
gen_data = ref[:gen]
branch_data = ref[:branch]

gen_length = length(gen_data)
bus_length = length(bus_data)
branch_length = length(branch_data)


# Create model
model = JuMP.Model(Ipopt.Optimizer)
# Set print level 
set_optimizer_attribute(model, "print_level", 5)

# Time periods
T = 2

# Set a ramping cost
ramping_cost = 7

# Define variables
# Sets variables for each 1 -> T with upper and lower bounds
# PGtg where t = T and i = gen, PG21 is the first gen of second t
# Likewise for theta
@variable(model, gen_data[g]["pmin"] <= pg[t in 1:T, g in 1:gen_length] <= gen_data[g]["pmax"])
@variable(model, -360 <= theta[b in 1:bus_length, t in 1:T] <= 360, start = 0)


# Stuff below is from Sajads notebook
@variable(model, va[i in keys(ref[:bus])])

for (i,bus) in bus_data
    @constraint(model, va[i] == 0)
end

@variable(model, -ref[:branch][l]["rate_a"] <= p[(l,i,j) in ref[:arcs_from]] <= ref[:branch][l]["rate_a"])

p_expr = Dict([((l,i,j), 1.0*p[(l,i,j)]) for (l,i,j) in ref[:arcs_from]])
p_expr = merge(p_expr, Dict([((l,j,i), -1.0*p[(l,i,j)]) for (l,i,j) in ref[:arcs_from]]))

for (i,bus) in ref[:bus]
    # Build a list of the loads and shunt elements connected to the bus i
    bus_loads = [ref[:load][l] for l in ref[:bus_loads][i]]
    bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]

    # Active power balance at node i
    @constraint(model,
        sum(p_expr[a] for a in ref[:bus_arcs][i]) ==    
        sum(pg[g] for g in ref[:bus_gens][i]) -                 # sum of active power generation at bus i -
        sum(load["pd"] for load in bus_loads) -                 # sum of active load consumption at bus i -
        sum(shunt["gs"] for shunt in bus_shunts)*1.0^2          # sum of active shunt element injections at bus i
    )
end

# Branch power flow physics and limit constraints
for (i,branch) in ref[:branch]
    # Build the from variable id of the i-th branch, which is a tuple given by (branch id, from bus, to bus)
    f_idx = (i, branch["f_bus"], branch["t_bus"])

    p_fr = p[f_idx]                     # p_fr is a reference to the optimization variable p[f_idx]

    va_fr = va[branch["f_bus"]]         # va_fr is a reference to the optimization variable va on the from side of the branch
    va_to = va[branch["t_bus"]]         # va_fr is a reference to the optimization variable va on the to side of the branch

    # Compute the branch parameters and transformer ratios from the data
    g, b = PowerModels.calc_branch_y(branch)

    # DC Power Flow Constraint
    @constraint(model, p_fr == -b*(va_fr - va_to))
   
    # Voltage angle difference limit
    @constraint(model, va_fr - va_to <= branch["angmax"])
    @constraint(model, va_fr - va_to >= branch["angmin"])
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
