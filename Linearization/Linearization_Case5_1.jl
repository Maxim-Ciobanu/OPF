using PowerModels, Ipopt, JuMP, JLD2
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
model = JuMP.Model(Ipopt.Optimizer) # Use Ipopt for AC-OPF

# Time periods
T = 24

# Set a ramping cost
ramping_cost = 7




@variable(model, va[t in 1:T, i in keys(ref[:bus])])
@variable(model, ref[:bus][i]["vmin"] <= vm[t in 1:T, i in keys(ref[:bus])] <= ref[:bus][i]["vmax"], start=1.0)

# Define variables
# Sets variables for each 1 -> T with upper and lower bounds

@variable(model, ref[:gen][i]["pmin"] <= pg[t in 1:T, i in keys(ref[:gen])] <= ref[:gen][i]["pmax"])
@variable(model, ref[:gen][i]["qmin"] <= qg[t in 1:T, i in keys(ref[:gen])] <= ref[:gen][i]["qmax"])

# @variable(model, -360 <= theta[t in 1:T, b in 1:bus_length] <= 360, start = 0)

# Stuff below is from Sajads notebook
for t in 1:T
    for (i,bus) in ref[:ref_buses]
        @constraint(model, va[t,i] == 0)
    end
end
@variable(model, -ref[:branch][l]["rate_a"] <= p[1:T,(l,i,j) in ref[:arcs]] <= ref[:branch][l]["rate_a"])
@variable(model, -ref[:branch][l]["rate_a"] <= q[1:T,(l,i,j) in ref[:arcs]] <= ref[:branch][l]["rate_a"])

# ---------------------------------------------
# For some Reason if we use p_expr 
# we get the wrong anser will investigate
# ---------------------------------------------
# p_expr = Dict()
# for t in 1:T
#     p_expr[t] = Dict()
# end
# # Iterate over each time period
# for t in 1:T
#     p_expr[t] = Dict([((l, i, j), 1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs]])
#     p_expr[t] = merge(p_expr[t], Dict([((l, j, i), -1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs]]))
# end

# q_expr = Dict()
# for t in 1:T
#     q_expr[t] = Dict()
# end
# # Iterate over each time period
# for t in 1:T
#     q_expr[t] = Dict([((l, i, j), 1.0 * q[t, (l, i, j)]) for (l, i, j) in ref[:arcs]])
#     q_expr[t] = merge(q_expr[t], Dict([((l, j, i), -1.0 * q[t, (l, i, j)]) for (l, i, j) in ref[:arcs]]))
# end
# ---------------------------------------------

# Create a random vector two multiply loads by for each T
factor = [1]
random_vector = [0.975, 0.98, 1.01, 1.015, 1.025, 0.99, 0.975, 1.03, 0.975, 0.98, 1.01, 1.015, 1.025, 0.99, 0.975, 1.03, 0.975, 0.98, 1.01, 1.015, 1.025, 0.99, 0.975]
factor = vcat(factor, random_vector)

for t in 1:T
    for (i,bus) in ref[:bus]
        # Build a list of the loads and shunt elements connected to the bus i
        bus_loads = [ref[:load][l] for l in ref[:bus_loads][i]]
        bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]

        # Active power balance at node i

        @constraint(model,
            sum(p[t,a] for a in ref[:bus_arcs][i]) ==    
            sum(pg[t, g] for g in ref[:bus_gens][i]) -  # Note the double loop over t and g
            sum(load["pd"] * factor[t] for load in bus_loads) -       # Maybe add * increase here               
            sum(shunt["gs"] for shunt in bus_shunts)*vm[t,i]^2         
        )

        @constraint(model,
            sum(q[t,a] for a in ref[:bus_arcs][i]) ==    
            sum(qg[t, g] for g in ref[:bus_gens][i]) -  # Note the double loop over t and g
            sum(load["qd"] * factor[t] for load in bus_loads) +       # Maybe add * increase here               
            sum(shunt["bs"] for shunt in bus_shunts)*vm[t,i]^2         
        )
    end

    # Branch power flow physics and limit constraints
    for (i,branch) in ref[:branch]
        # Build the from variable id of the i-th branch, which is a tuple given by (branch id, from bus, to bus)
        f_idx = (i, branch["f_bus"], branch["t_bus"])
        t_idx = (i, branch["t_bus"], branch["f_bus"])

        p_to = p[t,t_idx]
        q_to = q[t,t_idx]
        p_fr = p[t,f_idx]                     # p_fr is a reference to the optimization variable p[f_idx]
        q_fr = q[t,f_idx]


        va_fr = va[t,branch["f_bus"]]         # va_fr is a reference to the optimization variable va on the from side of the branch
        va_to = va[t,branch["t_bus"]]         # va_fr is a reference to the optimization variable va on the to side of the branch

        vm_fr = vm[t,branch["f_bus"]]
        vm_to = vm[t,branch["t_bus"]]


        # Compute the branch parameters and transformer ratios from the data
        g, b = PowerModels.calc_branch_y(branch)

        tr, ti = PowerModels.calc_branch_t(branch)
        ttm = tr^2 + ti^2
        
        # Note: Dont know if we need t index here
        g_fr = branch["g_fr"]
        b_fr = branch["b_fr"]
        g_to = branch["g_to"]
        b_to = branch["b_to"]

        # From side of the branch flow
        # old p = @constraint(model, p_fr ==  (g+g_fr)/ttm*vm_fr^2 + (-g*tr+b*ti)/ttm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-b*tr-g*ti)/ttm*(vm_fr*vm_to*sin(va_fr-va_to)) )
        # old q = @constraint(model, q_fr == -(b+b_fr)/ttm*vm_fr^2 - (-b*tr-g*ti)/ttm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-g*tr+b*ti)/ttm*(vm_fr*vm_to*sin(va_fr-va_to)) )

        # From side of the branch flow in linear form
        @constraint(model, p_fr == ((g+g_fr)/ttm*vm_fr^2)/2 + ((-g*tr+b*ti)/ttm*vm_to^2)/2 + (-b*tr-g*ti)/ttm * (va_fr-va_to) # approximation -> gij*vi^2/2 - gij*jv^2/2 - bij*thetha_ij
        + ((-g*tr+b*ti)/ttm) *((va_fr-va_to)^2)/2 + ((-g*tr+b*ti)/ttm)*((vm_fr-vm_to)^2)/2 # loss_p -> gij*((va_fr-va_to)^2)/2 + gij*((vm_fr-vm_to)^2)/2
        )
        @constraint(model, q_fr == (-(b+b_fr)/ttm*vm_fr^2)/2 - ((-b*tr-g*ti)/ttm*vm_to^2)/2 + (-g*tr+b*ti)/ttm*(va_fr-va_to) # approximation -> -bij*vi^2/2 - -bij*vj^2/2 - gij*thetha_ij
        + ((-b*tr-g*ti)/ttm)*((va_fr-va_to)^2)/2 + ((-b*tr-g*ti)/ttm)*((vm_fr-vm_to)^2)/2 # loss_q -> -bij*((va_fr-va_to)^2)/2 + -bij*((vm_fr-vm_to)^2)/2
        )

        
        # (g+g_fr)/ttm*vm_fr^2 + 
        # (-g*tr+b*ti)/ttm*(vm_fr*vm_to*cos(va_fr-va_to)) + 
        # (-b*tr-g*ti)/ttm*(vm_fr*vm_to*sin(va_fr-va_to))

        # gij = (-g*tr+b*ti)/ttm
        # bij = (-b*tr-g*ti)/ttm
        # vi = vm_fr
        # vj = vm_to
        # theta = va_fr-va_to

        # loss = gij*(va_fr-va)/2 + gij*(vm_fr-vm_to)

        # here is the right function:
        # ((g+g_fr)/ttm*vm_fr^2)/2 + ((-g*tr+b*ti)/ttm*vm_to^2)/2 + (-b*tr-g*ti)/ttm * (va_fr-va_to)

        # ---------------------------------------------------------------------------------------------------------------------

        # -(b+b_fr)/ttm*vm_fr^2 - (-b*tr-g*ti)/ttm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-g*tr+b*ti)/ttm*(vm_fr*vm_to*sin(va_fr-va_to))

        # New function:
        # (-(b+b_fr)/ttm*vm_fr^2)/2 - ((-b*tr+g*ti)/ttm*vm_to^2)/2 + (-g*tr+b*ti)/ttm*(va_fr-va_to) + loss


        # To side of the branch flow
        # old p = @constraint(model, p_to ==  (g+g_to)*vm_to^2 + (-g*tr-b*ti)/ttm*(vm_to*vm_fr*cos(va_to-va_fr)) + (-b*tr+g*ti)/ttm*(vm_to*vm_fr*sin(va_to-va_fr)) )
        # old q = @constraint(model, q_to == -(b+b_to)*vm_to^2 - (-b*tr+g*ti)/ttm*(vm_to*vm_fr*cos(va_to-va_fr)) + (-g*tr-b*ti)/ttm*(vm_to*vm_fr*sin(va_to-va_fr)) )

        # To side of the branch flow in linear form
        @constraint(model, p_fr == ((g+g_to)*vm_to^2)/2 + ((-g*tr-b*ti)/ttm*vm_fr^2)/2 + (-b*tr+g*ti)/ttm*(va_to-va_fr) # approximation -> gij*vj^2/2 - gij*vi^2/2 - bij*thetha_ji
        + ((-g*tr-b*ti)/ttm)*((va_to-va_fr)^2)/2 + ((-g*tr-b*ti)/ttm)*((vm_to-vm_fr)^2)/2 # loss -> gij*((va_to-va_fr)^2)/2 + gij*((vm_to-vm_fr)^2)/2
        )
        @constraint(model, q_fr == (-(b+b_to)*vm_to^2)/2 - ((-b*tr+g*ti)/ttm*vm_fr^2)/2 + (-g*tr-b*ti)/ttm*(va_to-va_fr)# approximation -> -bij*vi^2/2 - -bij*vj^2/2 - gij*thetha_ij
        - ((-b*tr+g*ti)/ttm) *((va_to-va_fr)^2)/2 - ((-b*tr+g*ti)/ttm)*((vm_to-vm_fr)^2)/2 # loss -> -bij*((va_to-va_fr)^2)/2 + -bij*((vm_to-vm_fr)^2)/2
        )

    
        # Voltage angle difference limit
        @constraint(model, va_fr - va_to <= branch["angmax"])
        @constraint(model, va_fr - va_to >= branch["angmin"])

        # Apparent power limit, from side and to side
        @constraint(model, p_fr^2 + q_fr^2 <= branch["rate_a"]^2)
        @constraint(model, p_to^2 + q_to^2 <= branch["rate_a"]^2)
    end
end

#compute ramping up and down
@variable(model, ramp_up[t in 2:T, g in keys(ref[:gen])] >= 0)
@variable(model, ramp_down[t in 2:T, g in keys(ref[:gen])] >= 0)


# @objective(model, Min,
# sum(sum(ref[:gen][g]["cost"][1]*pg[t,g]^2 + ref[:gen][g]["cost"][2]*pg[t,g] + ref[:gen][g]["cost"][3] for g in keys(ref[:gen])) for t in 1:T) +
# sum(ramping_cost * (ramp_up[t, g] + ramp_down[t, g]) for g in keys(ref[:gen]) for t in 2:T)
# )

# new objective function using linearized model, this is not the right place...
# @objective(model, Min, 
#     sum(sum(
#         g_ij[i,j] * (vm[t,i]^2 - vm[t,i] * vm[t,j]) - b_ij[i,j] * va[t,i] - va[t,j] +  # Equation 10
#         -b_ij[i,j] * (vm[t,i]^2 - vm[t,i] * vm[t,j]) - g_ij[i,j] * va[t,i] - va[t,j]  # Equation 11
#         for (i,j) in ref[:branch]) for t in 1:T)
# )



for g in keys(ref[:gen])
    for t in 2:T
        @constraint(model, ramp_up[t, g] >= pg[t, g] - pg[t-1, g])
        @constraint(model, ramp_down[t, g] >= pg[t-1, g] - pg[t, g])
    end
end

optimize!(model)
optimal_cost = objective_value(model)
println("Optimal Cost: ")
show(optimal_cost)

AC_initial_pg_values = JuMP.value.(pg)
# @save "./Attachments/AC_initial_pg_values.jld2" AC_initial_pg_values

# Link to code I folowed: https://github.com/lanl-ansi/rosetta-opf/blob/main/jump.jl

# Answer is consistent with Matpower graph when switched to AC: https://matpower.app/