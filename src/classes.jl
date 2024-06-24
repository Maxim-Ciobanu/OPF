module MPOPF
    using PowerModels, JuMP, Ipopt, Gurobi
    
    # Exporting these functions from the module so we dont have to prefix them with MPOPF.
    export create_model, optimize_model, ACPowerFlowModelFactory, DCPowerFlowModelFactory

##############################################################################################
# Factory Structs
# They are used as parameters so that Julias multiple dispatch knows which functions to call
##############################################################################################

    # Abstract type as a base so that we can use this type as a parameter in fucntions
    abstract type PowerFlowModelFactory end

    # This struct "inherits" from PowerFlowModelFactory
    mutable struct ACPowerFlowModelFactory <: PowerFlowModelFactory
        file_path::String
        optimizer::Type

        function ACPowerFlowModelFactory(file_path::String, optimizer::Type)
            return new(file_path, optimizer)
        end
    end

    # This struct "inherits" from PowerFlowModelFactory
    mutable struct DCPowerFlowModelFactory <: PowerFlowModelFactory
        file_path::String
        optimizer::Type

        function DCPowerFlowModelFactory(file_path::String, optimizer::Type)
            return new(file_path, optimizer)
        end
    end


##############################################################################################
# Concrete Model Structs
# They are used as objects, passed around with variabels that are specific to each model
##############################################################################################

    # Abstract type as a base so that we can use this type as a parameter in fucntions
    abstract type AbstractPowerFlowModel end

    # The actual PowerFlowModel struct that "inherits" forrm AbstractPowerFlowModel
    mutable struct PowerFlowModel <: AbstractPowerFlowModel
        model::JuMP.Model
        data::Dict
        time_periods::Int64
        ramping_cost::Int64
    end

    # Similar PowerFlowModel object but with an additional scenrios variable for uncertainty
    mutable struct PowerFlowModelUncertainty <: AbstractPowerFlowModel
        model::JuMP.Model
        data::Dict
        time_periods::Int64
        ramping_cost::Int64
        scenarios::Dict
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

    # The first create_model fucntion creates a PowerFlowModel object
    # It creates the right model depending on the factory passed as the first paramenter
    # For Example: If the factory passed is an AC factory the function will return an AC model
    function create_model(factory::PowerFlowModelFactory, time_periods::Int64=1, ramping_cost::Int64=0)::PowerFlowModel
        data = PowerModels.parse_file(factory.file_path)
        PowerModels.standardize_cost_terms!(data, order=2)
        PowerModels.calc_thermal_limits!(data)

        model = JuMP.Model(factory.optimizer)

        power_flow_model = PowerFlowModel(model, data, time_periods, ramping_cost)

        set_model_variables!(power_flow_model, factory)
        set_model_objective_function!(power_flow_model, factory)
        set_model_constraints!(power_flow_model, factory)

        return power_flow_model
    end

    # The second create_model fucntion creates a PowerFlowModelUncertainty object
    # Similarly it creates the right model depending on the factory passed as the first paramenter
    # However now we are passing the scenarios as parameters too
    function create_model(factory::PowerFlowModelFactory, scenarios::Dict, time_periods::Int64=1, ramping_cost::Int64=0)::PowerFlowModelUncertainty
        data = PowerModels.parse_file(factory.file_path)
        PowerModels.standardize_cost_terms!(data, order=2)
        PowerModels.calc_thermal_limits!(data)

        model = JuMP.Model(factory.optimizer)
        
        power_flow_model = PowerFlowModelUncertainty(model, data, time_periods, ramping_cost, scenarios)

        set_model_variables!(power_flow_model, factory)
        set_model_uncertainty_variables!(power_flow_model)
        set_model_uncertainty_objective_function!(power_flow_model, factory)
        set_model_uncertainty_constraints!(power_flow_model, factory)

        return power_flow_model
    end

##############################################################################################
# Optimization function
##############################################################################################

    # This function simply optimizes any model given as a parameter
    # It prints the Optimial cost
    function optimize_model(model::AbstractPowerFlowModel)
        println("Processing Model with case data: ", model.data)
        optimize!(model.model)
        optimal_cost = objective_value(model.model)
        println("Optimal Cost: ", optimal_cost)
    end

end # module
