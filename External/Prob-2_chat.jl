using JuMP, Ipopt, PowerModels

function case5()
    # Define system MVA base
    baseMVA = 100

    # Bus data
    bus = [
        (1, 2, 0, 0, 0, 0, 1, 1, 0, 230, 1, 1.1, 0.9),
        (2, 1, 300, 98.61, 0, 0, 1, 1, 0, 230, 1, 1.1, 0.9),
        (3, 2, 300, 98.61, 0, 0, 1, 1, 0, 230, 1, 1.1, 0.9),
        (4, 3, 400, 131.47, 0, 0, 1, 1, 0, 230, 1, 1.1, 0.9),
        (5, 2, 0, 0, 0, 0, 1, 1, 0, 230, 1, 1.1, 0.9)
    ]

    # Generator data
    gen = [
        (1, 40, 0, 30, -30, 1, 100, 1, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
        (1, 170, 0, 127.5, -127.5, 1, 100, 1, 170, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
        (3, 323.49, 0, 390, -390, 1, 100, 1, 520, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
        (4, 0, 0, 150, -150, 1, 100, 1, 200, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
        (5, 466.51, 0, 450, -450, 1, 100, 1, 600, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    ]

    # Branch data
    branch = [
        (1, 2, 0.00281, 0.0281, 0.00712, 400, 400, 400, 0, 0, 1, -360, 360),
        (1, 4, 0.00304, 0.0304, 0.00658, 0, 0, 0, 0, 0, 1, -360, 360),
        (1, 5, 0.00064, 0.0064, 0.03126, 0, 0, 0, 0, 0, 1, -360, 360),
        (2, 3, 0.00108, 0.0108, 0.01852, 0, 0, 0, 0, 0, 1, -360, 360),
        (3, 4, 0.00297, 0.0297, 0.00674, 0, 0, 0, 0, 0, 1, -360, 360),
        (4, 5, 0.00297, 0.0297, 0.00674, 240, 240, 240, 0, 0, 1, -360, 360)
    ]

    # Generator cost data
    gencost = [
        (2, 0, 0, 2, 14, 0),
        (2, 0, 0, 2, 15, 0),
        (2, 0, 0, 2, 30, 0),
        (2, 0, 0, 2, 40, 0),
        (2, 0, 0, 2, 10, 0)
    ]

    return baseMVA, bus, gen, branch, gencost
end

function MPOPF()
    # Load case data
    baseMVA, bus, gen, branch, gencost = case5()

    # Create optimization model
    model = Model(Ipopt.Optimizer)

    # Time periods
    T = 2  # Number of time periods

    # Define sets
    G = 1:length(gen)
    B = 1:length(bus)
    L = 1:length(branch)

    # Define variables
    @variable(model, gen[g][10] <= Pg[g in G, t in 1:T] <= gen[g][9])
    @variable(model, -360 <= θ[b in B, t in 1:T] <= 360, start = 0)

    # Objective function
    @objective(model, Min, sum(gencost[g][5] * Pg[g, t] for g in G, t in 1:T))

    # Power balance constraints
    for t in 1:T
        for b in B
            @constraint(model, sum(Pg[g, t] for g in G if gen[g][1] == bus[b][1]) -
                sum(bus[b][3] for _ in B) == 
                sum((θ[branch[l][1], t] - θ[branch[l][2], t]) / branch[l][3] for l in L if branch[l][1] == bus[b][1] || branch[l][2] == bus[b][1]))
        end
    end

    # Voltage angle difference constraints
    for l in L
        for t in 1:T
            @constraint(model, -360 <= θ[branch[l][1], t] - θ[branch[l][2], t] <= 360)
        end
    end

    # Generator ramp rate constraints
    for g in G
        for t in 2:T
            @constraint(model, Pg[g, t] - Pg[g, t-1] <= gen[g][17])
            @constraint(model, Pg[g, t-1] - Pg[g, t] <= gen[g][18])
        end
    end

    # Solve the model
    optimize!(model)

    # Output results
    if termination_status(model) == MOI.OPTIMAL
        println("Optimal solution found.")
        for t in 1:T
            println("Time period: $t")
            for g in G
                println("Generator $g: Pg = $(value(Pg[g, t])) MW")
            end
            for b in B
                println("Bus $b: θ = $(value(θ[b, t])) degrees")
            end
        end
    else
        println("No optimal solution found.")
    end
end

# Run the MPOPF function
MPOPF()
