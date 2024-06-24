# OPF

## Utilities

- [MatPower Graph Display](https://matpower.app/)
- [MatPower Description of Case Format](https://matpower.org/docs/ref/matpower5.0/caseformat.html)
    - [Local Copy](./Attachments/Description%20of%20caseformat.html)



# Power System Analysis with Julia

This repository contains code for power system analysis and optimization using Julia. The code leverages the JuMP and PowerModels libraries to create and optimize both AC and DC power flow models, with additional consideration for uncertainty.

## Files

- **classes.jl**: Defines custom types and structures used throughout the project.
- **implementation_uncertainty.jl**: Implements power flow models considering uncertainty.
- **implementation-ac.jl**: Implements the AC power flow model.
- **implementation-dc.jl**: Implements the DC power flow model.
- **main.jl**: Main script to run the models and perform optimizations. (Holds Examples at the moment)

## Requirements

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

## Usage

**Defining Custom Types**: The `classes.jl` file contains custom type definitions essential for the models.
   ```julia
   include("classes.jl")
   using .MPOPF
   ```

## Example

Here is some examples of how to run basic models:

```julia
using PowerModels, JuMP, Ipopt, Gurobi
include("classes.jl")
using .MPOPF

file_path = "./Cases/case5.m"


# Example for AC
# --------------------------------------------------------------------------
ac_factory = ACPowerFlowModelFactory(file_path, Ipopt.Optimizer)
My_AC_model = create_model(ac_factory)
optimize_model(My_AC_model)
# --------------------------------------------------------------------------


# Example for DC
# --------------------------------------------------------------------------
dc_factory = DCPowerFlowModelFactory(file_path, Ipopt.Optimizer)
My_DC_model = create_model(dc_factory)
optimize_model(My_DC_model)
# --------------------------------------------------------------------------


# Example for AC with UncertaintyFactory
# --------------------------------------------------------------------------
load_scenarios_factors = Dict(
    1 => Dict(1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1),
    2 => Dict(1 => 1.001, 2 => 1.001, 3 => 1.003, 4 => 1.002, 5 => 1.001),
    3 => Dict(1 => 0.98, 2 => 0.99, 3 => 0.997, 4 => 0.998, 5 => 0.99)
)
# Using AC Factory from previous example
My_AC_model_Uncertainty = create_model(ac_factory, load_scenarios_factors)
optimize_model(My_AC_model_Uncertainty)
# --------------------------------------------------------------------------


# Example for DC with UncertaintyFactory
# --------------------------------------------------------------------------
load_scenarios_factors2 = Dict(
    1 => Dict(1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1),
    2 => Dict(1 => 1.03, 2 => 1.03, 3 => 1.03, 4 => 1.03, 5 => 1.03),
    3 => Dict(1 => 0.95, 2 => 0.95, 3 => 0.95, 4 => 0.95, 5 => 0.95)
)
# Using DC Factory but with Gurobi
dc_factory_Gurobi = DCPowerFlowModelFactory(file_path, Gurobi.Optimizer)
My_DC_model_Uncertainty = create_model(dc_factory_Gurobi, load_scenarios_factors2)
optimize_model(My_DC_model_Uncertainty)
# --------------------------------------------------------------------------
display(JuMP.value.(mu_minus))
```

## Note: Will update README.md with detailed descriptions of each function in the future
