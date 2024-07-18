using PowerModels, JuMP, Ipopt, Gurobi
function set_model_uncertainty_variables!(power_flow_model::MPOPFModelUncertainty)
    model = power_flow_model.model
    T = power_flow_model.time_periods
    ref = PowerModels.build_ref(power_flow_model.data)[:it][:pm][:nw][0]
    scenarios = power_flow_model.scenarios

    @variable(model, mu_plus[t in 1:T, g in keys(ref[:gen]), s in 1:length(scenarios)] >= 0)
    @variable(model, mu_minus[t in 1:T, l in keys(ref[:bus]), s in 1:length(scenarios)] >= 0)
end

function set_model_uncertainty_objective_function!(power_flow_model::MPOPFModelUncertainty, factory::ACMPOPFModelFactory)
    model = power_flow_model.model
    data = power_flow_model.data
    T = power_flow_model.time_periods
    ramping_cost = power_flow_model.ramping_cost
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
    gen_data = ref[:gen]
    pg = model[:pg]
    ramp_up = model[:ramp_up]
    ramp_down = model[:ramp_down]
    mu_plus = model[:mu_plus]
    mu_minus = model[:mu_minus]
    scenarios = power_flow_model.scenarios
    
    @objective(model, Min,
        sum(sum(gen_data[g]["cost"][1]*pg[t,g]^2 + gen_data[g]["cost"][2]*pg[t,g] + gen_data[g]["cost"][3] for g in keys(gen_data)) for t in 1:T) +
        sum(ramping_cost * (ramp_up[t, g] + ramp_down[t, g]) for g in keys(gen_data) for t in 2:T)
        # Adding some cost for mu_plus and mu_minus.
        + sum(10000 * (mu_plus[t, g, s]^2 + mu_minus[t, l, s]) for g in keys(ref[:gen]) for l in keys(ref[:load]) for t in 1:T for s in 1:length(scenarios))
    )
end

function set_model_uncertainty_constraints!(power_flow_model::MPOPFModelUncertainty, factory::ACMPOPFModelFactory)
    model = power_flow_model.model
    data = power_flow_model.data
    T = power_flow_model.time_periods
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
    gen_data = ref[:gen]
    va = model[:va]
    p = model[:p]
    q = model[:q]
    pg = model[:pg]
    qg = model[:qg]
    vm = model[:vm]
    ramp_up = model[:ramp_up]
    ramp_down = model[:ramp_down]
    mu_plus = model[:mu_plus]
    mu_minus = model[:mu_minus]
    scenarios = power_flow_model.scenarios
    num_scenarios = length(scenarios)

    for t in 1:T
        for (i, bus) in ref[:ref_buses]
            @constraint(model, va[t,i] == 0)
        end

        for s in 1:num_scenarios
            scenario = scenarios[s]
            for b in keys(ref[:bus])
                
                # Active power balance at node i for scenario s
                bus_loads = [ref[:load][l] for l in ref[:bus_loads][b]]
                bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][b]]
    
                @constraint(model,
                    sum(p[t, a] for a in ref[:bus_arcs][b]) ==
                    sum(pg[t, g] + mu_plus[t, g, s] for g in ref[:bus_gens][b]) - 
                    sum(load["pd"] * scenario[b] + mu_minus[t, l, s] for load in bus_loads for l in ref[:bus_loads][b]) - 
                    sum(shunt["gs"] for shunt in bus_shunts)*vm[t,b]^2
                )
    
                @constraint(model,
                    sum(q[t, a] for a in ref[:bus_arcs][b]) ==
                    sum(qg[t, g] for g in ref[:bus_gens][b]) - 
                    sum(load["qd"] * scenario[b] + mu_minus[t, l, s] for load in bus_loads for l in ref[:bus_loads][b]) + 
                    sum(shunt["bs"] for shunt in bus_shunts)*vm[t,b]^2 
                )
            end
        end

        for (i, branch) in ref[:branch]
            f_idx = (i, branch["f_bus"], branch["t_bus"])
            t_idx = (i, branch["t_bus"], branch["f_bus"])

            p_to = p[t,t_idx]
            q_to = q[t,t_idx]
            p_fr = p[t,f_idx]
            q_fr = q[t,f_idx]

            va_fr = va[t,branch["f_bus"]]
            va_to = va[t,branch["t_bus"]]

            vm_fr = vm[t,branch["f_bus"]]
            vm_to = vm[t,branch["t_bus"]]

            g, b = PowerModels.calc_branch_y(branch)
            tr, ti = PowerModels.calc_branch_t(branch)
            ttm = tr^2 + ti^2

            g_fr = branch["g_fr"]
            b_fr = branch["b_fr"]
            g_to = branch["g_to"]
            b_to = branch["b_to"]

            @constraint(model, p_fr ==  (g+g_fr)/ttm*vm_fr^2 + (-g*tr+b*ti)/ttm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-b*tr-g*ti)/ttm*(vm_fr*vm_to*sin(va_fr-va_to)) )
            @constraint(model, q_fr == -(b+b_fr)/ttm*vm_fr^2 - (-b*tr-g*ti)/ttm*(vm_fr*vm_to*cos(va_fr-va_to)) + (-g*tr+b*ti)/ttm*(vm_fr*vm_to*sin(va_fr-va_to)) )

            @constraint(model, p_to ==  (g+g_to)*vm_to^2 + (-g*tr-b*ti)/ttm*(vm_to*vm_fr*cos(va_to-va_fr)) + (-b*tr+g*ti)/ttm*(vm_to*vm_fr*sin(va_to-va_fr)) )
            @constraint(model, q_to == -(b+b_to)*vm_to^2 - (-b*tr+g*ti)/ttm*(vm_to*vm_fr*cos(va_to-va_fr)) + (-g*tr-b*ti)/ttm*(vm_to*vm_fr*sin(va_to-va_fr)) )

            @constraint(model, va_fr - va_to <= branch["angmax"])
            @constraint(model, va_fr - va_to >= branch["angmin"])

            @constraint(model, p_fr^2 + q_fr^2 <= branch["rate_a"]^2)
            @constraint(model, p_to^2 + q_to^2 <= branch["rate_a"]^2)
        end
    end

    for g in keys(gen_data)
        for t in 2:T
            @constraint(model, ramp_up[t, g] >= pg[t, g] - pg[t-1, g])
            @constraint(model, ramp_down[t, g] >= pg[t-1, g] - pg[t, g])
        end
    end
end

function set_model_uncertainty_objective_function!(power_flow_model::MPOPFModelUncertainty, factory::DCMPOPFModelFactory)
    model = power_flow_model.model
    data = power_flow_model.data
    T = power_flow_model.time_periods
    ramping_cost = power_flow_model.ramping_cost
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
    gen_data = ref[:gen]
    pg = model[:pg]
    ramp_up = model[:ramp_up]
    ramp_down = model[:ramp_down]
    mu_plus = model[:mu_plus]
    mu_minus = model[:mu_minus]
    scenarios = power_flow_model.scenarios
    
    @objective(model, Min,
        sum(sum(gen_data[g]["cost"][1]*pg[t,g]^2 + gen_data[g]["cost"][2]*pg[t,g] + gen_data[g]["cost"][3] for g in keys(gen_data)) for t in 1:T) +
        sum(ramping_cost * (ramp_up[t, g] + ramp_down[t, g]) for g in keys(gen_data) for t in 2:T)
        # Adding some cost for mu_plus and mu_minus.
        # + sum(10000 * (mu_plus[t, g, s] + mu_minus[t, b, s]) for g in keys(ref[:gen]) for b in keys(ref[:bus]) for t in 1:T for s in 1:length(scenarios))
        + sum(10000 * mu_plus[t, g, s] for t in 1:T for s in 1:length(scenarios) for g in keys(ref[:gen]))
        + sum(10000 * mu_minus[t, b, s] for t in 1:T for s in 1:length(scenarios) for b in keys(ref[:bus]))
    )
end

function set_model_uncertainty_constraints!(power_flow_model::MPOPFModelUncertainty, factory::DCMPOPFModelFactory)
    model = power_flow_model.model
    data = power_flow_model.data
    T = power_flow_model.time_periods
    ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
    gen_data = ref[:gen]
    va = model[:va]
    p = model[:p]
    pg = model[:pg]
    ramp_up = model[:ramp_up]
    ramp_down = model[:ramp_down]
    mu_plus = model[:mu_plus]
    mu_minus = model[:mu_minus]
    scenarios = power_flow_model.scenarios
    num_scenarios = length(scenarios)

    p_expr = Dict()
    for t in 1:T
        p_expr[t] = Dict()
    end
    # Iterate over each time period
    for t in 1:T
        p_expr[t] = Dict([((l, i, j), 1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs_from]])
        p_expr[t] = merge(p_expr[t], Dict([((l, j, i), -1.0 * p[t, (l, i, j)]) for (l, i, j) in ref[:arcs_from]]))
    end

    for t in 1:T
        for (i, bus) in ref[:ref_buses]
            @constraint(model, va[t,i] == 0)
        end

        for s in 1:num_scenarios
            scenario = scenarios[s]
            for b in keys(ref[:bus])
                
                # Active power balance at node i for scenario s
                bus_loads = [ref[:load][l] for l in ref[:bus_loads][b]]
                bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][b]]
    
                @constraint(model,
                    sum(p_expr[t][a] for a in ref[:bus_arcs][b]) ==
                    sum(pg[t, g] + mu_plus[t, g, s] for g in ref[:bus_gens][b]) - 
                    sum(load["pd"] * scenario[b] for load in bus_loads) - 
                    sum(shunt["gs"] for shunt in bus_shunts)*1.0^2 - mu_minus[t, b, s]
                )
            end
        end

        for (i,branch) in ref[:branch]
            f_idx = (i, branch["f_bus"], branch["t_bus"])
    
            p_fr = p[t,f_idx]
    
            va_fr = va[t,branch["f_bus"]]
            va_to = va[t,branch["t_bus"]]
    
            g, b = PowerModels.calc_branch_y(branch)
    
            @constraint(model, p_fr == -b*(va_fr - va_to))
        
            @constraint(model, va_fr - va_to <= branch["angmax"])
            @constraint(model, va_fr - va_to >= branch["angmin"])
        end
    end

    for g in keys(gen_data)
        for t in 2:T
            @constraint(model, ramp_up[t, g] >= pg[t, g] - pg[t-1, g])
            @constraint(model, ramp_down[t, g] >= pg[t-1, g] - pg[t, g])
        end
    end
end

