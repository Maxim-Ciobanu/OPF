module MPOPF
    using PowerModels, JuMP, Ipopt#, Gurobi
    
    # Exporting these functions from the module so we dont have to prefix them with MPOPF.
    export create_model, optimize_model, ACMPOPFModelFactory, DCMPOPFModelFactory, LinMPOPFModelFactory, NewACMPOPFModelFactory, create_model_check_feasibility

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
    function create_model(factory::AbstractMPOPFModelFactory, time_periods::Int64=1, factors::Vector{Float64}=[1.0], ramping_cost::Int64=0)::MPOPFModel
        data = PowerModels.parse_file(factory.file_path)
        PowerModels.standardize_cost_terms!(data, order=2)
        PowerModels.calc_thermal_limits!(data)

        model = JuMP.Model(factory.optimizer)

        power_flow_model = MPOPFModel(model, data, time_periods, factors, ramping_cost)

        set_model_variables!(power_flow_model, factory)
        set_model_objective_function!(power_flow_model, factory)
        set_model_constraints!(power_flow_model, factory)

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
    function create_model_check_feasibility(new_pg, new_qg, factory::NewACMPOPFModelFactory, time_periods::Int64=1, factors::Vector{Float64}=[1.0], ramping_cost::Int64=0)::MPOPFModel
        data = PowerModels.parse_file(factory.file_path)
        PowerModels.standardize_cost_terms!(data, order=2)
        PowerModels.calc_thermal_limits!(data)

        model = JuMP.Model(factory.optimizer)

        power_flow_model = MPOPFModel(model, data, time_periods, factors, ramping_cost)

        set_model_variables!(power_flow_model, factory)
        # sets pg from previous model
        fix.(power_flow_model.model[:pg], new_pg; force=true)
        fix.(power_flow_model.model[:qg], new_qg; force=true)
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
    end

end # module
