# Implementation Details

Here we will discuss how the project was built from a programming perspective.

## Factory Structs

The Factories are used as parameters so that Julia's multiple dispatch feature runs the correct functions depending on the factory given.

We have two, `ACMPOPFModelFactory` and `DCMPOPFModelFactory` which are subtypes of the abstract type `AbstractMPOPFModelFactory`.
This abstract type is what the implementation functions expect but since AC and DC are subtypes they will work. This makes it possible to create functions with the same names that preform different operations depending on the factory provided.

Here is the code for our Factory Structs:

```julia
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
```

## MPOPF Model Structs

The MPOPF Model objects are what the `create_model` function returns. They have all the information specific to MPOPF.

Similarly to our factory structs we currently have two concrete structs of MPOPF, `MPOPFModel` and `MPOPFModelUncertainty` which are subtypes of the abstract type `AbstractMPOPFModel`. This is useful when we want both MPOPF models to be passed in a function interchangeably (That is the case for the `optimize_model` function).

`MPOPFModel` has the following as variables: 
- `Jump Model`
- `Data read from file`
- `time periods`
- `Load Factors`
- `Ramping Cost`

`MPOPFModelUncertainty` has the same variables except that it holds one more variable `scenarios` which is only relevant for Uncertainty.

Here is the code for out MPOPF Model Structs:

```julia
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
```

## Create Model Functions

At the moment we have two `create_model` functions.
The first returns an `MPOPFModel` object and the second returns an `MPOPFModelUncertainty` object.
The system knows which one to call depending on whether the `scenarios` variable was given.

Both share the same logic so whatever I explain about the first can be extrapolated to the second.

The `create_model` function takes in a factory of type `AbstractMPOPFModelFactory` as the first parameter. This means that both `ACMPOPFModelFactory`, `DCMPOPFModelFactory`, or any other Factory that inherits from the Abstract one is accepted.
The following three parameters, `time_periods`, `factors`, and `ramping_cost` are only relevant for multiperiod so they are optional. (If not provided, the system will assume one period).

For AC and DC models, the steps of creating a model are the same. We first define the model variables, then we define the model objective function, and lastly we set the model constraints.

However, inside of these functions different things happen depending if we want AC, DC, or any other form of defining.
This is why the factory is passed as a parameter inside the `set_model_variables!`, `set_model_objective_function!`, and `set_model_constraints!` functions.

Thanks to Julia's multiple dispatch feature, the correct function will be called depending on the type of the factory. Therefore, the correct variables, objective function, and constraints will be added without having to create massive if statements that check what model we want.

Here is our create model function:

```julia
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
```

!!! note

    The `model_type` variable is only relevant for linearization and will be discussed here: [Linearization Techniques for MPOPF](@ref)


Here is an example of the AC and DC `set_model_variables!` functions. Take note of the factory type accepted.

**AC**
```julia
function set_model_variables!(power_flow_model::AbstractMPOPFModel, factory::ACMPOPFModelFactory)
# Here would be the code for AC model
# Take note of the second parameter which accepts type ACMPOPFModelFactory
end
```

**DC**
```julia
function set_model_variables!(power_flow_model::AbstractMPOPFModel, factory::DCMPOPFModelFactory)
# Here would be the code for DC model
# Take note of the second parameter which accepts type DCMPOPFModelFactory
end
```

The factory is not used for any computation, it is just there to let the system know which function should be called in what situation.



