module MPOPF
    using PowerModels, JuMP, Ipopt, PlotlyJS, Gurobi
    
    # Exporting these functions from the module so we dont have to prefix them with MPOPF.
    export create_model, optimize_model, ACMPOPFModelFactory, DCMPOPFModelFactory, optimize_model_with_plot, LinMPOPFModelFactory, NewACMPOPFModelFactory, create_model_check_feasibility, get_ref

##############################################################################################
# Factory Structs
# They are used as parameters so that Julias multiple dispatch knows which functions to call
##############################################################################################

    # Abstract type as a base so that we can use this type as a parameter in fucntions
    abstract type AbstractMPOPFModelFactory end

    # This struct "inherits" from PowerFlowModelFactory
    mutable struct ACMPOPFModelFactory <: AbstractMPOPFModelFactory
        file_path::String
        optimizer::Type

        function ACMPOPFModelFactory(file_path::String, optimizer::Type)
            return new(file_path, optimizer)
        end
    end

    # This struct "inherits" from PowerFlowModelFactory
    mutable struct DCMPOPFModelFactory <: AbstractMPOPFModelFactory
        file_path::String
        optimizer::Type

        function DCMPOPFModelFactory(file_path::String, optimizer::Type)
            return new(file_path, optimizer)
        end
    end

    mutable struct LinMPOPFModelFactory <: AbstractMPOPFModelFactory
        file_path::String
        optimizer::Type

        function LinMPOPFModelFactory(file_path::String, optimizer::Type)
            return new(file_path, optimizer)
        end
    end

    mutable struct NewACMPOPFModelFactory <: AbstractMPOPFModelFactory
        file_path::String
        optimizer::Type

        function NewACMPOPFModelFactory(file_path::String, optimizer::Type)
            return new(file_path, optimizer)
        end
    end

##############################################################################################
# Concrete Model Structs
# They are used as objects, passed around with variabels that are specific to each model
##############################################################################################

    # Abstract type as a base so that we can use this type as a parameter in fucntions
    abstract type AbstractMPOPFModel end

    # The actual PowerFlowModel struct that "inherits" forrm AbstractPowerFlowModel
    mutable struct MPOPFModel <: AbstractMPOPFModel
        model::JuMP.Model
        data::Dict
        time_periods::Int64
        factors::Vector{Float64}
        ramping_cost::Int64

        function MPOPFModel(model::JuMP.Model, data::Dict, time_periods::Int64=1, factors::Vector{Float64}=[1.0], ramping_cost::Int64=0)
            return new(model, data, time_periods, factors, ramping_cost)
        end
    end

    # Similar PowerFlowModel object but with an additional scenrios variable for uncertainty
    mutable struct MPOPFModelUncertainty <: AbstractMPOPFModel
        model::JuMP.Model
        data::Dict
        scenarios::Dict
        time_periods::Int64
        factors::Vector{Float64}
        ramping_cost::Int64

        function MPOPFModelUncertainty(model::JuMP.Model, data::Dict, scenarios::Dict, time_periods::Int64=1, factors::Vector{Float64}=[1.0], ramping_cost::Int64=0)
            return new(model, data, scenarios, time_periods, factors, ramping_cost)
        end
    end

##############################################################################################
# Create Model Functions
# First function returns PowerFlowModel object
# Second function returns PowerFlowModelUncertainty object
##############################################################################################

    # Here we include our implementation files
    # They hold the implementations of the functions utilized in the create_model functions
    include("implementation-ac.jl")
    include("implementation-dc.jl")
    include("implementation_uncertainty.jl")
    include("implementation-linear.jl")
    include("implementation-new_ac.jl")

    # The first create_model fucntion creates a PowerFlowModel object
    # It creates the right model depending on the factory passed as the first paramenter
    # For Example: If the factory passed is an AC factory the function will return an AC model
    function create_model(factory::AbstractMPOPFModelFactory; time_periods::Int64=1, factors::Vector{Float64}=[1.0], ramping_cost::Int64=0, model_type=undef)::MPOPFModel
        data = PowerModels.parse_file(factory.file_path)
        PowerModels.standardize_cost_terms!(data, order=2)
        PowerModels.calc_thermal_limits!(data)

        model = JuMP.Model(factory.optimizer)

        power_flow_model = MPOPFModel(model, data, time_periods, factors, ramping_cost)

        set_model_variables!(power_flow_model, factory)
        set_model_objective_function!(power_flow_model, factory)
        model_type !== undef ? set_model_constraints!(power_flow_model, factory, model_type) : set_model_constraints!(power_flow_model, factory)

        return power_flow_model
    end

    # The second create_model fucntion creates a PowerFlowModelUncertainty object
    # Similarly it creates the right model depending on the factory passed as the first paramenter
    # However now we are passing the scenarios as parameters too
    function create_model(factory::AbstractMPOPFModelFactory, scenarios::Dict, time_periods::Int64=1, factors::Vector{Float64}=[1.0], ramping_cost::Int64=0)::MPOPFModelUncertainty
        data = PowerModels.parse_file(factory.file_path)
        PowerModels.standardize_cost_terms!(data, order=2)
        PowerModels.calc_thermal_limits!(data)

        model = JuMP.Model(factory.optimizer)
        
        power_flow_model = MPOPFModelUncertainty(model, data, scenarios, time_periods, factors, ramping_cost)

        set_model_variables!(power_flow_model, factory)
        set_model_uncertainty_variables!(power_flow_model)
        set_model_uncertainty_objective_function!(power_flow_model, factory)
        set_model_uncertainty_constraints!(power_flow_model, factory)

        return power_flow_model
    end

    # A new create model to create a secondary model that asseses how feasible the first solution was
    # It uses the pg values from a previous model and fixes it, then asses if it works referencing AC OPF
    function create_model_check_feasibility(factory::NewACMPOPFModelFactory, new_pg=false, new_qg=false, v=false, theta=false, time_periods::Int64=1, factors::Vector{Float64}=[1.0], ramping_cost::Int64=0)::MPOPFModel
        data = PowerModels.parse_file(factory.file_path)
        PowerModels.standardize_cost_terms!(data, order=2)
        PowerModels.calc_thermal_limits!(data)

        model = JuMP.Model(factory.optimizer)

        power_flow_model = MPOPFModel(model, data, time_periods, factors, ramping_cost)

        set_model_variables!(power_flow_model, factory)

        # fix values that have been declared
        if (new_pg !== false) fix.(power_flow_model.model[:pg], new_pg; force=true) end
        if (new_qg !== false) fix.(power_flow_model.model[:qg], new_qg; force=true) end
		if (v !== false) fix.(power_flow_model.model[:v], v; force=true) end
		if (theta !== false) fix.(power_flow_model.model[:theta], theta; force=true) end

        set_model_objective_function!(power_flow_model, factory)
        set_model_constraints!(power_flow_model, factory)

        return power_flow_model
    end

##############################################################################################
# Optimization function
##############################################################################################

    # This function simply optimizes any model given as a parameter
    # It prints the Optimial cost
    function optimize_model(model::AbstractMPOPFModel)
        optimize!(model.model)
        optimal_cost = objective_value(model.model)
        println("Optimal Cost: ", optimal_cost)
        println()

        if isa(model, MPOPFModelUncertainty)
            data = model.data
            T = model.time_periods
            S = length(model.scenarios)
            ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]
            error_check = 0

            for t in 1:T    
                for s in 1:S
                    for b in keys(ref[:bus])
                        sum_of_mu_plus = 0
                        mu_minus = 0
                        sum_of_mu_plus = sum(value(model.model[:mu_plus][t, g, s]) for g in ref[:bus_gens][b]; init = 0)
                        mu_minus = value(model.model[:mu_minus][t, b, s])
                        if sum_of_mu_plus >= 0.01 && mu_minus >= 0.01
                            error_check = error_check + 1
                            println("###############")
                            println("#### Error ####")
                            Println("###############")

                            println("Scenario: $s Bus: $b")
                            println("mu_plus: $sum_of_mu_plus")
                            println("mu_minus: $mu_minus")
                            println()
                        end
                    end
                end
            end
            if error_check == 0
                println("No mu_plus and mu_minus errors found")
                println()
            else
                println("Found $error_check error(s)")
                println()
            end
        end
    end

    # Optimized and graphs the given model using a callback function
    function optimize_model_with_plot(model::AbstractMPOPFModel)
        T = model.time_periods

        if T == 1
            objective_values = Float64[]
            iterations = Int[]

            function ipopt_callback(
                alg_mod::Cint, iter_count::Cint, obj_value::Float64,
                inf_pr::Float64, inf_du::Float64, mu::Float64,
                d_norm::Float64, regularization_size::Float64,
                alpha_du::Float64, alpha_pr::Float64, ls_trials::Cint
            )
                push!(objective_values, obj_value)
                push!(iterations, iter_count)
                return true  # Return true to continue the optimization
            end

            # Note: The callback does not work without a new package
            # https://github.com/jump-dev/Gurobi.jl#callbacks
            function gurobi_callback(cb_data, where)
                if where == GRB_CB_MIP
                    iteration = Ref{Cint}()
                    GRBcbget(cb_data, where, GRB_CB_MIP_NODCNT, iteration)
                    
                    objbst = Ref{Cdouble}()
                    GRBcbget(cb_data, where, GRB_CB_MIP_OBJBST, objbst)
                    
                    push!(iterations, iteration[])
                    push!(objective_values, objbst[])
                    
                    println("Iteration: $(iteration[]), Best Obj: $(objbst[])")
                end
            end

            if solver_name(model.model) == "Ipopt"
                MOI.set(model.model, Ipopt.CallbackFunction(), ipopt_callback)
            elseif solver_name(model.model) == "Gurobi"
                error("At the moment there is no graphing for gurobi if Time_periods = 1")
                # MOI.set(model.model, MOI.RawOptimizerAttribute("LazyConstraints"), 1)
                # MOI.set(model.model, Gurobi.CallbackFunction(), gurobi_callback)
                # if MOI.get(model.model, MOI.NumberOfVariables()) > 0
                #     println("Callback has been set for Gurobi")
                # else
                #     println("No variables in the model. Callback may not be triggered.")
                # end
            else
                error("Optimizer must be either Ipopt or Gurobi")
            end

            optimize!(model.model)
            optimal_cost = objective_value(model.model)
            println("Optimal Cost: ", optimal_cost)
            
            # Plotting Code
            trace = scatter(
                x=iterations, y=objective_values,
                mode="lines+markers",
                name="Objective Cost",
                marker_color="blue",
                hoverinfo="x+y", # Ensure hover displays both x and y values
                hovertemplate="%{x}, %{y:.2f}<extra></extra>" # Custom hover text format
            )

            layout = Layout(
                title="Plotting Objective Cost against Solver Iterations",
                xaxis=attr(title="Iterations", tickangle=-45, tickmode="linear", tick0=0, dtick=1),
                yaxis=attr(title="Objective Cost", hoverformat=".2f"),
                showlegend=true
            )

            Plot = plot([trace], layout)

            display(Plot)
        else
            optimize!(model.model)
            optimal_cost = objective_value(model.model)
            println("Optimal Cost: ", optimal_cost)
        
            # Extracting cost components
            ref = PowerModels.build_ref(model.data)[:it][:pm][:nw][0]
            pg = model.model[:pg]
            ramp_up = model.model[:ramp_up]
            ramp_down = model.model[:ramp_down]
            ramping_cost = model.ramping_cost
        
            ramping_cost_per_period = [sum(ramping_cost * (value(ramp_up[t, g]) + value(ramp_down[t, g])) for g in keys(ref[:gen])) for t in 2:T]
            ramping_up_per_period = [sum(ramping_cost * (value(ramp_up[t, g])) for g in keys(ref[:gen])) for t in 2:T]
            ramping_down_per_period = [sum(ramping_cost * (value(ramp_down[t, g])) for g in keys(ref[:gen])) for t in 2:T]
            
            # Adjusting ramping cost array to match periods (adding zero for first period)
            ramping_cost_per_period = [0.0; ramping_cost_per_period]
            ramping_up_per_period = [0.0; ramping_up_per_period]
            ramping_down_per_period = [0.0; ramping_down_per_period]
    
            cost_per_period_with_ramping_to_that_period = [sum(ref[:gen][g]["cost"][1]*value(pg[t,g])^2 + ref[:gen][g]["cost"][2]*value(pg[t,g]) + ref[:gen][g]["cost"][3] for g in keys(ref[:gen])) + ramping_cost_per_period[t] for t in 1:T]
            cost_per_period_no_ramping = [sum(ref[:gen][g]["cost"][1]*value(pg[t,g])^2 + ref[:gen][g]["cost"][2]*value(pg[t,g]) + ref[:gen][g]["cost"][3] for g in keys(ref[:gen])) for t in 1:T]
            
            roling_cost_per_period = zeros(Float64, T)  # Initialize the array with zeros
            roling_cost_per_period[1] = cost_per_period_with_ramping_to_that_period[1]
            for t in 2:T
                roling_cost_per_period[t] = roling_cost_per_period[t-1] + cost_per_period_with_ramping_to_that_period[t]
            end

            # Plotting costs
            trace_cost_per_period_no_ramping = scatter(
                x=1:T,
                y=cost_per_period_no_ramping,
                mode="lines+markers",
                name="Objective Cost no Ramping",
                marker_color="black"
            )
    
            trace_cost_per_period_with_ramping_to_that_period = scatter(
                x=1:T,
                y=cost_per_period_with_ramping_to_that_period,
                mode="lines+markers",
                name="Objective Cost With Ramping",
                marker_color="blue"
            )
        
            trace_ramping_cost_per_period = scatter(
                x=1:T,
                y=ramping_cost_per_period,
                mode="lines+markers",
                name="Ramping Cost",
                marker_color="red"
            )
    
            trace_ramping_up_per_period = scatter(
                x=1:T,
                y=ramping_up_per_period,
                mode="lines+markers",
                name="Ramping Up",
                marker_color="green"
            )
    
            trace_ramping_down_per_period = scatter(
                x=1:T,
                y=ramping_down_per_period,
                mode="lines+markers",
                name="Ramping Down",
                marker_color="orange"
            )

            trace_roling_cost_per_period = scatter(
                x=1:T,
                y=roling_cost_per_period,
                mode="lines+markers",
                name="Roling Objective Cost",
                marker_color="#FF4162",
                visible = "legendonly"
            )
        
            layout = Layout(
                title="Plotting Objective Cost Against Time Periods With Ramping Costs",
                xaxis=attr(title="Time Periods", tickangle=-45, tickmode="linear", tick0=1, dtick=1),
                yaxis=attr(title="Objective Cost"),
                showlegend=true
            )
    
            Plot = plot([trace_cost_per_period_no_ramping, trace_cost_per_period_with_ramping_to_that_period, trace_ramping_cost_per_period, trace_ramping_up_per_period, trace_ramping_down_per_period, trace_roling_cost_per_period], layout)
    
            display(Plot)
        end
    end

    # Function to return the built reference from a data dictionary
    # Useful if we want to look up specific values in the data
    function get_ref(data::Dict{String, Any})
        return PowerModels.build_ref(data)[:it][:pm][:nw][0]
    end
end # module


methods(MPOPF.create_model_check_feasibility)