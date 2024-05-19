include("case5-functions.jl")
using PowerModels
using Ipopt
using JuMP
using LinearAlgebra
const PM = PowerModels

file_path = "case5.m"

data = parseFile(file_path)

ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]

# Extracting data variables
bus_data = ref[:bus]
gen_data = ref[:gen]
branch_data = ref[:branch]
load_data = ref[:load]

# Number of buses and branches
num_buses = length(bus_data)
num_branches = length(branch_data)
num_loads = length(load_data)
num_gens = length(gen_data)

slack_bus_index = findSlackBusIndex(bus_data)


# populate admittance matrix
yMatrix = buildYMatrixV1(num_buses, branch_data)

# Seperate admittance matrix into real and imaginary parts
G = real(yMatrix)
B = imag(yMatrix)

# calculate Pg - Pd and Qg - Qd for all busses
P = calculateP(num_buses, gen_data, load_data)
Q = calculateQ(num_buses, gen_data, load_data)

# Get inital V and phase angles(theta) for all busses. Uknown Vs = 1, unknown thetas = 0
# I dont see why we need thse functions since the initial data is in the file anyway so we can just pull when we need them
# Thats what I did int the findNewP and findNewQ functons
V = fetchInitialV(bus_data)
theta = fetchInitialTheta(bus_data)




# TODO Calculate H matrix
# The H matrix is the size of number of unknown thetas.
# Which is the number of busses that are not slack (PV + PQ busses)
# For this case we only have one slack bus so we can just subtract 1 from num_busses
# We might want to make this different if we want it to work with cases that cave more than one slack bus
H = calculateHMatrix(num_buses, slack_bus_index, V, theta, Q, G, B) # Seems right but IDK


# TODO Calculate N matrix

# TODO Calculate J matrix

# TODO Calculate L

# TODO Calculate Jacobian matrix

# TODO Calculate the search vector

# TODO Update variables




















# The followig loop is for the completed code so we cant test stuff on it.
# I comented out and whonce we finished the Jacobian calculations we can uncoment it.



# tolerance = 0.0000001
# max_iterations = 100000


# iteration = 1
# for iteration in max_iterations 

#     # Compute new P and Q values
#     # My only concern here is that I dont know if we should start with i at 1 or 2
#     # Since in class we didnt calculate P_1 since it was slack bus
#     # I set it to 1 but I'm not sure
#     newP = findNewP(V, theta, G, B)
#     newQ = findNewQ(V, theta, G, B)

#     # Calculate mismatches
#     mismatchP = P - newP
#     mismatchQ = Q - newQ

#     mismatches = [mismatchP; mismatchQ]

#     # Check for convergence based on mismatches
#     if norm(mismatches) < tolerance
#         println("Convergence achieved after $iteration iterations.")
#         break
#     end

#     # TODO Initialize H matrix
#     # The H matrix is the size of number of unknown thetas.
#     # Which is the number of busses that are not slack (PV + PQ busses)
#     # For this case we only have one slack bus so we can just subtract 1 from num_busses
#     # We might want to make this different if we want it to work with cases that cave more than one slack bus
#     H = calculateHMatrix(num_buses, slack_bus_index, V, theta, Q, G, B)


#     # TODO Initialize N matrix

#     # TODO Initialize J matrix

#     # TODO Calculate L

#     # TODO Initialize Jacobian matrix

#     # TODO Calculate the search vector

#     # TODO Update variables

# end

# if iteration == max_iterations
#     println("Max iterations reached without convergence.")
# end

# # TODO Print Solution
# display(V)
# display(theta)
