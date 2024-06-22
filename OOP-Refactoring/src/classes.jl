module MPOPF
    
    using PowerModels, JuMP, Ipopt, Gurobi

    export create_model, optimize_model

    abstract type PowerFlowModelFactory end

    mutable struct ACPowerFlowModelFactory <: PowerFlowModelFactory
        file_path::String
        optimizer::Type

        function ACPowerFlowModelFactory(file_path::String, optimizer::Type)
            return new(file_path, optimizer)
        end
    end

    mutable struct DCPowerFlowModelFactory <: PowerFlowModelFactory
        file_path::String
        optimizer::Type

        function DCPowerFlowModelFactory(file_path::String, optimizer::Type)
            return new(file_path, optimizer)
        end
    end

    mutable struct PowerFlowModel
        model::JuMP.Model
        data::Dict
        time_periods::Int64
        ramping_cost::Int64
    end

    include("implementation-ac.jl")
    include("implementation-dc.jl")

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

    function optimize_model(model::PowerFlowModel)
        println("Processing Model with case data: ", model.data)
        optimize!(model.model)
        optimal_cost = objective_value(model.model)
        println("Optimal Cost: ", optimal_cost)
    end

end # module
