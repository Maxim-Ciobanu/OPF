using JuMP
using LinearAlgebra

# Initial values
theta = [0.0, 0.0, 0.0]
V = [1.02, 1.03, 1.0]
G = [4.7059 -2.3529 -2.3529;
     -2.3529 4.7059 -2.3529;
     -2.3529 -2.3529 4.7059]
B = [-18.8235 9.418 9.418;
     9.418 -18.8235 9.418;
     9.418 9.418 -18.8235]
p = [-0.9, 1.4, -1.1]
q = [-0.4, 0.0, -0.4]

# Reactive power limits for Bus-2
Q2_min = 0.0
Q2_max = 0.8

# Convergence parameters
tolerance = 0.0000001
max_iterations = 100000

# Main iterative loop
for iteration in 1:max_iterations
    # Initialize new arrays with zeros
    local new_p = zeros(3)
    local new_q = zeros(3)

    # Loop to calculate new_p and new_q
    for i in 2:3
        sp = 0.0
        sq = 0.0
        for j in 1:3
            sp += V[i] * V[j] * (G[i,j] * cos(theta[i] - theta[j]) + B[i,j] * sin(theta[i] - theta[j]))
            sq += V[i] * V[j] * (G[i,j] * sin(theta[i] - theta[j]) - B[i,j] * cos(theta[i] - theta[j]))
        end
        new_p[i] = sp
        new_q[i] = sq
    end

    # Calculate mismatches
    local mismatches = zeros(3)
    mismatches[1] = p[2] - new_p[2]
    mismatches[2] = p[3] - new_p[3]
    mismatches[3] = q[3] - new_q[3]

    # Check for convergence based on mismatches
    if norm(mismatches) < tolerance
        println("Converged after $iteration iterations based on mismatches")
        break
    end

    # Initialize H matrix
    local H = zeros(2, 2)
    for i in 2:3
        for j in 2:3
            if i == j
                H[i-1, j-1] = -q[i] - B[i,i] * V[i]^2
            else
                H[i-1, j-1] = V[i] * V[j] * (G[i,j] * cos(theta[i] - theta[j]) + B[i,j] * sin(theta[i] - theta[j]))
            end
        end
    end

    # Initialize N matrix
    local N = zeros(2, 1)
    for i in 2:3
        for j in 3:3
            if i == 3
                N[i-1, j-2] = p[i] + G[i,i] * V[i]^2
            else
                N[i-1,j-2] = V[i] * V[j] * (G[i,j] * sin(theta[i] - theta[j]) + B[i,j] * cos(theta[i] - theta[j]))
            end
        end
    end

    # Initialize J matrix
    local J = zeros(1, 2)
    for i in 3:3
        for j in 2:3
            if j == 3
                J[i-2, j-1] = p[i] - G[i,i] * V[i]^2
            else
                J[i-2, j-1] = -V[i] * V[j] * (G[i,j] * cos(theta[i] - theta[j]) + B[i,j] * sin(theta[i] - theta[j]))
            end
        end
    end

    # Calculate L
    local L = q[3] - B[3,3] * V[3]^2

    # Initialize Jacobian matrix
    local Jac = zeros(3, 3)
    Jac[1:2, 1:2] = H
    Jac[1:2, 3] = N
    Jac[3, 1:2] = J
    Jac[3, 3] = L

    # Calculate the search vector
    local search = inv(Jac) * mismatches

    # Update variables
    local theta_diff = [0.0, search[1], search[2]]
    local V_diff = [0.0, 0.0, search[3] * V[3]]
    
    theta[2] += search[1]
    theta[3] += search[2]
    V[3] += search[3] * V[3]

    # Ensure V[3] stays within realistic bounds
    if V[3] < 0.9
        V[3] = 0.9
    elseif V[3] > 1.1
        V[3] = 1.1
    end
    
    # Ensure reactive power limits for Bus-2
    if new_q[2] < Q2_min
        new_q[2] = Q2_min
    elseif new_q[2] > Q2_max
        new_q[2] = Q2_max
    end

    global p = new_p
    global q = new_q

    # Check for convergence based on state variable changes
    if maximum(abs.(theta_diff)) < 1e-6 && maximum(abs.(V_diff ./ V)) < 1e-6
        println("Converged after $iteration iterations based on state variable changes")
        break
    end

    # Print progress
    println("Iteration $iteration: V = $V, theta = $theta")
end

# Final results
println("Final V: $V")
println("Final theta: $theta")
