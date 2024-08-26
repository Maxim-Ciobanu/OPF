!!! danger

    Should fill this in :)

# Approximation Techniques for MPOPF

Currently this is a simple example showcasing how code can be run and a dynamic graph can be displayed on the docs.

```@example
using JuMP, Ipopt, Gurobi
using MPOPF
using PlotlyDocumenter

graph1, gaph2, graph3 = perform_feasibility([0, 0, 0, 0, 1])

to_documenter(graph1.plot)
```
This is a simple example showcasing how code can be run and a dynamic graph can be displayed on the docs.