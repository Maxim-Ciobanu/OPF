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


function findNewP(V, theta, G, B)
    newP = zeros(num_buses)
    
    for i in 1:num_buses
        sp = 0.0
        for j in 1:num_buses
            sp += V[i] * V[j] * (G[i, j] * cos(theta[i] - theta[j]) + B[i, j] * sin(theta[i] - theta[j]))
        end
        newP[i] = sp
    end
    return newP
end


function findNewQ(V, theta, G, B)
    newQ = zeros(num_buses)
    
    for i in 1:num_buses
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