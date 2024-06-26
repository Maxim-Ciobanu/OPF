function parseFile(filePath)
    data = PowerModels.parse_file(filePath)
    PowerModels.standardize_cost_terms!(data, order=2)
    PowerModels.calc_thermal_limits!(data)
    return data
end

function buildYMatrixV1(num_buses, branch_data)
    yMatrix = zeros(ComplexF64, num_buses, num_buses)
    for(b, branch) in branch_data
        z = branch_data[b]["br_r"] + branch_data[b]["br_x"]im
        i = branch_data[b]["f_bus"]
        j = branch_data[b]["t_bus"]
        
        yMatrix[i,j] = -1/z
        yMatrix[j,i] = -1/z
    end

    for i in 1:length(ref[:bus])
        sum_of_elements = 0.0
        for j in 1:length(ref[:bus])
            sum_of_elements = sum(yMatrix[i, :])
        end
        yMatrix[i,i] = -sum_of_elements
    end
    return yMatrix
end


function buildYMatrixV2(num_buses, branch_data)
    Y_bus = zeros(ComplexF64, num_buses, num_buses)
    for branch in 1:num_branches
        f_bus = branch_data[branch]["f_bus"]
        t_bus = branch_data[branch]["t_bus"]
        r = branch_data[branch]["br_r"]
        x = branch_data[branch]["br_x"]
        y = 1 / (r + im*x) # admittance
        # If we want to include b uncomment this code
        # *****
         b_fr = branch_data[branch]["b_fr"]
         b_to = branch_data[branch]["b_to"]
         b = b_fr + b_to  # Sum of b_fr and b_to for total susceptance
         Y_bus[f_bus, f_bus] += y + im*b/2
         Y_bus[t_bus, t_bus] += y + im*b/2
        # *****
    
        
        # Y_bus[f_bus, f_bus] += y # If using b comment this line out
        # Y_bus[t_bus, t_bus] += y # If using b comment this line out
        Y_bus[f_bus, t_bus] -= y
        Y_bus[t_bus, f_bus] -= y
    end
    return Y_bus
end


function findNewP(V, theta, G, B, slack_bus_index)
    num_buses = length(V)
    newP = zeros(num_buses)
    
    for i in 1:num_buses
        # Skip calculations for the slack bus
        if i != slack_bus_index
            for j in 1:num_buses
                newP[i] = newP[i] + V[i] * V[j] * (G[i, j] * cos(theta[i] - theta[j]) + B[i, j] * sin(theta[i] - theta[j]))
            end
        end
    end
    return newP
end

function findNewQ(V, theta, G, B, slack_bus_index, gen_data)
    num_buses = length(V)
    newQ = zeros(num_buses)
    num_gens = length(gen_data)
    for i in 1:num_gens
        # Skip calculations for the slack bus
        # if i != slack_bus_index
            for j in 1:num_buses
                newQ[i] = newQ[i] + V[i] * V[j] * (G[i, j] * sin(theta[i] - theta[j]) - B[i, j] * cos(theta[i] - theta[j]))
            end
            # Clamping data
            newQ[i] = clamp(newQ[i], gen_data[i]["qmin"], gen_data[i]["qmax"])
        # end
    end
    return newQ
end



function calculateP(num_buses, gen_data, load_data)
    pd = zeros(num_buses)
    pg = zeros(num_buses)
    num_loads = length(load_data)
    num_gens = length(gen_data)
    
    for i in 1:num_loads
        index = load_data[i]["load_bus"]
        pd[index] = load_data[i]["pd"]
    end

    for i in 1:num_gens
        index = gen_data[i]["gen_bus"]
        pg[index] += gen_data[i]["pg"]
    end
    return pg-pd
end

function calculateQ(num_buses, gen_data, load_data)
    qd = zeros(num_buses)
    qg = zeros(num_buses)
    num_loads = length(load_data)
    num_gens = length(gen_data)

    for i in 1:num_loads
        index = load_data[i]["load_bus"]
        qd[index] = load_data[i]["qd"]
    end

    for i in 1:num_gens
        index = gen_data[i]["gen_bus"]
        qg[index] += gen_data[i]["qg"]
    end
    return qg-qd
end

function fetchInitialV(bus_data)
    num_buses = length(bus_data)
    V = ones(num_buses)
    for i in 1:num_buses
        V[i] = bus_data[i]["vm"]
    end
    return V
end

function fetchInitialTheta(bus_data)
    num_buses = length(bus_data)
    theta = zeros(num_buses)
    for i in 1:num_buses
        theta[i] = bus_data[i]["va"]
    end
    return theta
end

function findSlackBusIndex(bus_data)
    slack_bus_index = nothing
    for (bus_id, bus) in bus_data
        if bus["bus_type"] == 3
            slack_bus_index = bus_id
            break
        end
    end
    return slack_bus_index
end

function nonSlackBuses(bus_data)
    num = 0
    num_buses = length(bus_data)
    for i in 1:num_buses
        if bus_data[i]["bus_type"] != 1
            num += 1
        end
    end
    return num
end

function findPQBuses(bus_data)
    PQ_buses = []
    for (bus_id, bus) in bus_data
        if bus["bus_type"] == 1
            push!(PQ_buses, bus_id)
        end
    end
    return PQ_buses
end

function findPVBuses(bus_data)
    PQ_buses = []
    for (bus_id, bus) in bus_data
        if bus["bus_type"] == 2
            push!(PQ_buses, bus_id)
        end
    end
    return PQ_buses
end

function calculateHMatrix(H_size, num_buses, slack_bus_index, V, theta, Q, G, B)
    H = zeros(H_size)
    k = 1
    for i in 1:num_buses
        if i == slack_bus_index
            continue
        end
        l = 1
        for j in 1:num_buses
            if j == slack_bus_index
                continue
            end
            if i == j
                H[k, l] = -Q[i]-B[i, i]*(V[i]^2)
            else
                H[k, l] = V[i]*V[j]*(G[i, j]*sin(theta[i]-theta[j]) + B[i, j]*cos(theta[i]-theta[j]))
            end
            l += 1
        end
        k += 1
    end
    return H
end

function calculateNMatrix(N_size, num_buses, PQ_buses, slack_bus_index, V, theta, P, G, B)
    N = zeros(N_size)
    k = 1
    for i in 1:num_buses
        if i == slack_bus_index
            continue
        end
        l = 1
        for j in 1:num_buses
            if j == slack_bus_index || !(j in PQ_buses) # Skip non-PQ buses and the slack bus in columns
                continue
            end
            if i == j
                N[k, l] = P[i]+G[i, i]*(V[i]^2)
            else
                N[k, l] = V[i]*V[j] * (G[i, j] * cos(theta[i] - theta[j]) + B[i, j] * sin(theta[i] - theta[j]))
            end
            l += 1
        end
        k += 1
    end
    return N
end

function calculateJMatrix(J_size, num_buses, slack_bus_index, V, theta, P, G, B)
    J = zeros(J_size)
    k = 1
    for i in 1:num_buses
        if i == slack_bus_index || !(i in PQ_buses)
            continue
        end
        l = 1
        for j in 1:num_buses
            if j == slack_bus_index
                continue
            end
            if i == j
                J[k, l] = P[i]-G[i, i]*(V[i]^2)
            else
                J[k, l] = V[i]*V[j] * (-G[i, j] * cos(theta[i] - theta[j]) - B[i, j] * sin(theta[i] - theta[j]))
            end
            l += 1
        end
        k += 1
    end
    return J
end

function calculateLMatrix(L_size, num_buses, PQ_buses, slack_bus_index, V, theta, Q, G, B)
    L = zeros(L_size)
    k = 1
    for i in 1:num_buses
        if i == slack_bus_index || !(i in PQ_buses)
            continue
        end
        l = 1
        for j in 1:num_buses
            if j == slack_bus_index || !(j in PQ_buses)
                continue
            end
            if i == j
                L[k, l] = Q[i] - B[i, i] * (V[i]^2)
            else
                L[k, l] = V[i] * V[j] * (G[i, j] * sin(theta[i] - theta[j]) - B[i, j] * cos(theta[i] - theta[j]))
            end
            l += 1
        end
        k += 1
    end
    return L
end

function calculateJacobian(H, N, J, L)
    top = hcat(H, N)
    bottom = hcat(J, L)
    Jacobian = vcat(top, bottom)
    return Jacobian
end

function findMismatchMatrix(mismatchP, mismatchQ, num_buses)
    P = []
    Q = []
    for i in 1:num_buses + 1
        if bus_data[i]["bus_type"] == 2
            push!(P, mismatchP[i])
        end
        if bus_data[i]["bus_type"] == 1
            push!(P, mismatchP[i])
            push!(Q, mismatchQ[i])
        end
    end
    return vcat(P, Q)
end

function findIncrementMatrix(mismatchMatrix, Jacobian)
    return inv(Jacobian) * mismatchMatrix
end

function updateTheta(theta, incrementMatrix)
    newTheta = zeros(length(theta))
    for i in 1:num_buses
        newTheta[i] = theta[i] + incrementMatrix[i]
    end  
    return newTheta
end

function updateV(V, incrementMatrix)
    newV = zeros(length(V))
    for i in 1:num_buses
        newV[i] = V[i] + incrementMatrix[i]
    end
    return newV
end


function findBusType(bus_data)
    num_buses = length(bus_data)
    bus_type = zeros(Int, num_buses)
    for i in 1:num_buses
        bus_type[i] = bus_data[i]["bus_type"]
    end
    return bus_type
end



function calculateMismatches(num_buses, P_spec, Q_spec, bus_type, P_calc, Q_calc)
    # Initialize mismatch vectors
    deltaP = zeros(num_buses)  # Mismatch in active power
    deltaQ = zeros(num_buses)  # Mismatch in reactive power
    
    # Calculate mismatches for PQ and PV buses
    for i in 1:num_buses
        if bus_type[i] != 3  # Slack bus has no mismatch calculation
            deltaP[i] = P_spec[i] - P_calc[i]
            if bus_type[i] == 1  # Only PQ buses have Q mismatch calculated
                deltaQ[i] = Q_spec[i] - Q_calc[i]
            end
        end
    end
    
    # Collect all mismatches
    # First, collect all deltaP for PV and PQ buses, then all deltaQ for PQ buses
    mismatches = []
    # Collect deltaP for PV and PQ buses
    for i in 1:num_buses
        if bus_type[i] == 2  # PV
            push!(mismatches, deltaP[i])
        end
    end

    for i in 1:num_buses
        if  bus_type[i] == 1  # PQ
            push!(mismatches, deltaP[i])
        end
    end
    
    # Collect deltaQ for PQ buses
    for i in 1:num_buses
        if bus_type[i] == 1  # PQ
            push!(mismatches, deltaQ[i])
        end
    end
    
    return mismatches
end

function clampVoltageMagnitudes(V, bus_data)
    n = length(V)  # Number of buses
    for i in 1:n
        V[i] = clamp(V[i], bus_data[i]["vmin"], bus_data[i]["vmax"])
    end
    return V
end

function updateVoltages(theta, V, search, bus_type)
    n = length(theta)  # Total number of buses
    angle_idx = 1  # Initialize index for voltage angles in the search vector

    # Update voltage angles for all buses except slack
    for i in 1:n
        if bus_type[i] != 3  # Slack bus does not update
            theta[i] += search[angle_idx]
            angle_idx += 1
        end
    end

    # Update voltage magnitudes for PQ buses
    for i in 1:n
        if bus_type[i] == 1  # Only PQ buses update voltage magnitudes
            V[i] += search[angle_idx]
            angle_idx += 1
        end
    end
    
    return theta, V
end
