using PlotlyJS

N = 100
random_x = range(0, stop=1, length=N)
random_y = randn(N)


# Create trace
trace = scatter(x=random_x, y=random_y,
                    mode="lines+markers",
                    name="lines+markers")

My_plot = plot(trace)

savefig(My_plot, "Plots/InteractiveGraph.html")