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
    
        # If we want to include b uncomment this code
        # *****
        # b_fr = branch_data[branch]["b_fr"]
        # b_to = branch_data[branch]["b_to"]
        # b = b_fr + b_to  # Sum of b_fr and b_to for total susceptance
        # Y_bus[f_bus, f_bus] += y + im*b/2
        # Y_bus[t_bus, t_bus] += y + im*b/2
        # *****
    
        y = 1 / (r + im*x) # admittance
        Y_bus[f_bus, f_bus] += y # If using b comment this line out
        Y_bus[t_bus, t_bus] += y # If using b comment this line out
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
        if i == slack_bus_index
            continue
        end
        sp = 0.0
        for j in 1:num_buses
            sp += V[i] * V[j] * (G[i, j] * cos(theta[i] - theta[j]) + B[i, j] * sin(theta[i] - theta[j]))
        end
        newP[i] = sp
    end
    return newP
end

function findNewQ(V, theta, G, B, slack_bus_index)
    num_buses = length(V)
    newQ = zeros(num_buses)
    
    for i in 1:num_buses
        # Skip calculations for the slack bus
        if i == slack_bus_index
            continue
        end
        sq = 0.0
        for j in 1:num_buses
            sq += V[i] * V[j] * (G[i, j] * sin(theta[i] - theta[j]) - B[i, j] * cos(theta[i] - theta[j]))
        end
        newQ[i] = sq
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
    return pg .-pd
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
    return qg .-qd
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

function calculateMismatches(num_buses, P, Q, slack_bus_index, newP, newQ)
    mismatches = zeros(num_buses)
    k = 1
    for i in 1:num_buses
        if i != slack_bus_index
            mismatches[k] = P[i] - newP[i]
            k += 1
        end
    end
    
    # writing 2 termporarily it is suposed to be Pq bus index
    mismatches[end] = Q[2] - newQ[2]

    return mismatches
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
