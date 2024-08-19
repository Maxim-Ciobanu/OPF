# Getting Started

In these following sections we will describe how to get started with using our code.

## Before we Begin

To run the scripts, you need to have the following Julia packages installed:

- JuMP
- PowerModels
- Ipopt
- Gurobi
- PlotlyJS (Optionally for creating visualizations)

You can install these packages using the Julia package manager:

```julia
using Pkg
Pkg.add("JuMP")
Pkg.add("PowerModels")
Pkg.add("Ipopt")
Pkg.add("Gurobi")
Pkg.add("PlotlyJS")
```

To be able to Create MPOPF Models we will need to clone the GitHub repository:

```sh
git clone _________________________________________ FILL THIS IN
```

Then install the MPOPF package using Julia's Package Manager:

```julia
using Pkg
Pkg.add("MPOPF")
```

The packages mentioned above will be installed automatically as they are dependencies.

!!! note

    Optionally if we don't want to install the MPOPF Package we can run the file locally.
    (Note: The period indicates that it is a local Module)
    This can be done with the following three lines of code.

    ```julia
    using JuMP, PowerModels, Ipopt, Gurobi, PlotlyJS
    include("MPOPF.jl")
    using .MPOPF
    ```
    This method is not recommended, simpler to go with the first.

## What to Include in your Workspace

Now to actually use the MPOPF package we simply include it in the workspace
along with it's dependencies

```julia
using PowerModels, JuMP, Ipopt, Gurobi, PlotlyJS
using MPOPF
```

### Basic Example

Here is a simple example to showcase how a model can be created and optimized:

```@example
using PowerModels, JuMP, Ipopt, Gurobi, PlotlyJS
using MPOPF

# We define the file path of the case we want to solve
file_path = "Cases/case14.m"

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

# If we want to make an AC model instead simply create it with an AC Factory
ac_factory = ACMPOPFModelFactory(file_path, Ipopt.Optimizer)
my_ac_model = create_model(ac_factory)
optimize_model(my_ac_model)
```

### Multi-Period Example

To create a model with multiple periods we just specify the number of periods, the factors for the loads (multiplied to the current load to create different demand for the next period), and the ramping cost.
They are specified in the `create_model` function

```@example
using PowerModels, JuMP, Ipopt, Gurobi, PlotlyJS
using MPOPF

# We define the file path of the case we want to solve
file_path = "./Cases/case14.m"

# Our DC factory
dc_factory = DCMPOPFModelFactory(file_path, Ipopt.Optimizer)

# Create the model as before but now with multiperiod variables specified
# Time Periods = 3
# One factor per time period
# Ramping Cost = 7
my_dc_model = create_model(dc_factory; time_periods=3, factors=[1.0, 0.98, 1.03], ramping_cost=7)

# Once we have our model we just optimize
# This will print the Minimum Cost
optimize_model(my_dc_model)
```

## Further Reading

Curious about the implementation of this project? Visit the [Implementation Details](@ref Implementation-Details) page.
