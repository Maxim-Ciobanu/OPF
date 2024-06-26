# Code-Base Documentation

This report includes three sections:
Firstly, we will go over how to use this code base to create and optimize Multi Period Optimal Power Flow systems with additional components for Uncertainty, Linearization, and Local Search Optimization strategies.
Second, we will explain the design in detail and how different components work together.
Thirdly, we will showcase how development can continue, and how new optimization strategies can be added to the code-base.
Lastly, we will go over some key points about the design Philosophy of this project.

## Usage

### Requirements

To run the scripts, you need to have the following Julia packages installed:

- JuMP
- PowerModels
- Ipopt
- Gurobi

You can install these packages using the Julia package manager:

```julia
using Pkg
Pkg.add("JuMP")
Pkg.add("PowerModels")
Pkg.add("Ipopt")
Pkg.add("Gurobi")
```

### Usage

To be able to run the code we need to use the packages we just installed, we need to include the `MPOPF.jl` file, and we need to explicitly say we want to use our defined MPOPF module. (Note: The period indicates that it is a local Module)
This can be done with the following three lines of code.

   ```julia
   using JuMP, PowerModels, Ipopt, Gurobi
   include("MPOPF.jl")
   using .MPOPF
   ```

#### Simple example

Here is a simple example to showcase how a model can be created and optimized.

```julia
using PowerModels, JuMP, Ipopt, Gurobi
include("MPOPF.jl")
using .MPOPF

# We define the file path of the case we want to solve
file_path = "./Cases/case14.m"

# To create a DC model we need to first define a DC factory
# It is done with the following function
# Takes in two parameters, the fille path for the case we want to solve
# and the optimizer we want to use, Ipopt or Gurobi
dc_factory = DCMPOPFModelFactory(file_path, Ipopt.Optimizer)

# After creating our factory we pass it to our create model function
my_dc_model = create_model(dc_factory)

# Once we have our model we just optimize
# This will print the Minimum Cost
optimize_model(my_dc_model)
```

If we want to make an AC model instead simply create it with an AC Factory

```julia
ac_factory = ACMPOPFModelFactory(file_path, Ipopt.Optimizer)
my_ac_model = create_model(ac_factory)
```

#### Multi Period Example

To create a model with multiple periods we just specify the number of periods, the factors for the loads (multiplied to the current load to create different demand for the next period), and the ramping cost.
They are specified in the `create_model` function

```julia
using PowerModels, JuMP, Ipopt, Gurobi
include("MPOPF.jl")
using .MPOPF

# We define the file path of the case we want to solve
file_path = "./Cases/case14.m"

# Our DC factory
dc_factory = DCMPOPFModelFactory(file_path, Ipopt.Optimizer)

# Create the model as before but now with multiperiod variables specified
# Time Periods = 3
# One factor per time period
# Ramping Cost = 7
my_dc_model = create_model(dc_factory, 3, [1.0, 0.98, 1.03], 7)

# Once we have our model we just optimize
# This will print the Minimum Cost
optimize_model(my_dc_model)
```

## How it Works

### Factory Structs

The Factories are used as parameters so that Julia's multiple dispatch feature runs the correct functions depending on the factory given.

We have two, `ACMPOPFModelFactory` and `DCMPOPFModelFactory` which are subtypes of the abstract type `AbstractMPOPFModelFactory`.
This abstract type is what the implementation functions expect but since AC and DC are subtypes they will work. This makes it possible to create functions with the same names that preform different cations depending on the factory provided.

The functions inside these two factory structs `function ACMPOPFModelFactory(file_path::String, optimizer::Type)` are optional since they preform the same thing as the default constructors but I put them here for clarity.

Here is the code:

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

### MPOPF Model Structs

The MPOPF Model objects are what the `create_model` function returns. They have all the information specific to MPOPF.

Similarly to our factory structs we currently have two concrete structs of MPOPF, `MPOPFModel` and `MPOPFModelUncertainty` which are subtypes of the abstract type `AbstractMPOPFModel`. This is useful when we want both MPOPF models to be passed in a function interchangeably (That is the case for the `optimize_model` function).

`MPOPFModel` has the following as variables: `Jump Model`, `Data read from file`, `time periods`, `Load Factors`, and `Ramping Cost`.
`MPOPFModelUncertainty` has the same variables except that it hold one more variable `scenarios` which is only relevant for Uncertainty.

Again, the functions inside these two MPOPF structs are optional since they preform the same thing as the default constructors but I put them here for clarity.

Here is the code:

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

### Create Model Functions

At the moment we have two `create_model` functions.
The first returns an `MPOPFModel` object and the second returns an `MPOPFModelUncertainty` object.
The system knows which one to call depending on whether the `scenarios` variable was given.

Both share the same logic so whatever I explain about the first can be extrapolated to the second.

The `create_model` function takes in a factory of type `AbstractMPOPFModelFactory` as the first parameter. This means that both `ACMPOPFModelFactory`, `ACMPOPFModelFactory`, or any other Factory that inherits from the Abstract one is accepted.
The following three parameters, `time_periods`, `factors`, and `ramping_cost` are only relevant for multiperiod so they are optional. (If not provided the system will assume one period).

For AC and DC models, the steps of creating a model are the same. We first define the model variables, then we define the model objective function, and lastly we set the model constraints.

However inside of these functions different things happen depending if we want AC, DC, or any other form of defining.
This is why the factory is passed as a parameter inside the `set_model_variables!`, `set_model_objective_function!`, and `set_model_constraints!` functions alongside the model we want to add these things to.

Thanks to Julia's multiple dispatch feature, the correct function will be called depending on the type of the factory. Therefore, the correct variables, objective function, and constraints will be added without having to create massive if statements that check what model we want.

Here is the function:

```julia
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
```

Here is an example of the AC and DC `set_model_variables!` functions. Take note of the factory type accepted.

**AC**
```julia
function set_model_variables!(power_flow_model::AbstractMPOPFModel, factory::ACMPOPFModelFactory)
    model = power_flow_model.model
    T = power_flow_model.time_periods
    ref = PowerModels.build_ref(power_flow_model.data)[:it][:pm][:nw][0]
    bus_data = ref[:bus]
    gen_data = ref[:gen]
    branch_data = ref[:branch]
    
    @variable(model, va[t in 1:T, i in keys(bus_data)])
    @variable(model, bus_data[i]["vmin"] <= vm[t in 1:T, i in keys(bus_data)] <= bus_data[i]["vmax"], start=1.0)
    @variable(model, gen_data[i]["pmin"] <= pg[t in 1:T, i in keys(gen_data)] <= gen_data[i]["pmax"])
    @variable(model, gen_data[i]["qmin"] <= qg[t in 1:T, i in keys(gen_data)] <= gen_data[i]["qmax"])
    @variable(model, -branch_data[l]["rate_a"] <= p[t in 1:T, (l,i,j) in ref[:arcs]] <= branch_data[l]["rate_a"])
    @variable(model, -branch_data[l]["rate_a"] <= q[t in 1:T, (l,i,j) in ref[:arcs]] <= branch_data[l]["rate_a"])
    @variable(model, ramp_up[t in 2:T, g in keys(gen_data)] >= 0)
    @variable(model, ramp_down[t in 2:T, g in keys(gen_data)] >= 0)
end
```

**DC**
```julia
using PowerModels, JuMP, Ipopt, Gurobi
function set_model_variables!(power_flow_model::AbstractMPOPFModel, factory::DCMPOPFModelFactory)
    model = power_flow_model.model
    T = power_flow_model.time_periods
    ref = PowerModels.build_ref(power_flow_model.data)[:it][:pm][:nw][0]
    bus_data = ref[:bus]
    gen_data = ref[:gen]
    
    @variable(model, va[t in 1:T, i in keys(bus_data)])
    @variable(model, gen_data[i]["pmin"] <= pg[t in 1:T, i in keys(gen_data)] <= gen_data[i]["pmax"])
    @variable(model, -ref[:branch][l]["rate_a"] <= p[1:T,(l,i,j) in ref[:arcs_from]] <= ref[:branch][l]["rate_a"])
    @variable(model, ramp_up[t in 2:T, g in keys(gen_data)] >= 0)
    @variable(model, ramp_down[t in 2:T, g in keys(gen_data)] >= 0)
end
```

The factory is not used for any computation, it is just there to let the system know which function should be called in what situation.

## Future Development

1. Create new factory
2. implement set functions
3. that's it

... Not done this section ...


