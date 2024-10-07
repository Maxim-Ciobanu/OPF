!!! danger

    Should fill this in :)

# Approximation Techniques for MPOPF

Currently this is a simple example showcasing how code can be run and a dynamic graph can be displayed on the docs.

```@example
using JuMP, Ipopt
using MPOPF
using PlotlyDocumenter

file_path = "./Cases/case14.m"

# We haev 24 values for 24 time periods
demand_factors = [1.0, 1.05, 0.98, 1.03, 0.96, 0.97, 0.99, 1.0, 1.05, 1.03, 1.01, 0.95, 1.04, 1.02, 0.99, 0.99, 0.99, 0.95, 1.04, 1.02, 0.98, 1.0, 1.02, 0.97]

my_ac_factory = ACMPOPFModelFactory(file_path, Ipopt.Optimizer)
my_ac_model = create_model(my_ac_factory; time_periods=24, factors=demand_factors, ramping_cost=2000)

graph = optimize_model_with_plot(my_ac_model)

to_documenter(graph.plot)
```
This is a simple example showcasing how code can be run and a dynamic graph can be displayed on the docs.