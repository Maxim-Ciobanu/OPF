


################################################################################
################################################################################
################################################################################


# 1. Success Rate vs Mismatch Costs (separate plots for μ+ and μ-)
for case_name in cases
    # Create graph for μ+
    graph_mu_plus = Graph("output/$(case_name)_mu_plus.html")
    
    for (idx, method) in enumerate(["statistical", "covariance"])
        data = filter(row -> row.case == case_name && 
                           row.sampling_method == method && 
                           row.mu_minus == 100.0 && 
                           row.variation == 0.15, results)
        
        add_scatter(graph_mu_plus, 
                   data.mu_plus, 
                   data.success_rate, 
                   "$(method) sampling",
                   idx)
    end
    
    create_plot(graph_mu_plus,
               "Success Rate vs μ+ Cost ($(case_name))",
               "μ+ Cost (log scale)",
               "Success Rate (%)")
    save_graph(graph_mu_plus)
end

# 2. Heat map for μ+ vs μ- (using Plots.jl for this specific visualization)
using Plots

for case_name in cases
    for method in ["statistical", "covariance"]
        data = filter(row -> row.case == case_name && 
                           row.sampling_method == method && 
                           row.variation == 0.15, results)
        
        success_matrix = reshape(data.success_rate, length(mu_plus_values), length(mu_minus_values))
        
        heatmap(log10.(mu_plus_values), 
                log10.(mu_minus_values), 
                success_matrix,
                title="Success Rate Heat Map\n$(case_name) - $(method)",
                xlabel="log₁₀(μ+)",
                ylabel="log₁₀(μ-)",
                c=:viridis)
        savefig("output/heatmap_$(case_name)_$(method).png")
    end
end

# 3. Variation Analysis
graph_variation = Graph("output/variation_analysis.html")
for (idx, case_name) in enumerate(cases)
    data = filter(row -> row.case == case_name && 
                       row.mu_plus == 1000.0 && 
                       row.mu_minus == 1000.0, results)
    
    add_scatter(graph_variation,
               data.variation,
               data.success_rate,
               case_name,
               idx)
end

create_plot(graph_variation,
           "Success Rate vs Variation Value",
           "Variation Value",
           "Success Rate (%)")
save_graph(graph_variation)

################################################################################










using CSV, DataFrames, PlotlyJS

# Read the data
results = CSV.read("simulation_results.csv", DataFrame)

# 1. 3D Surface Plot: μ+ vs μ- vs Success Rate (for each case and sampling method)
function create_3d_surface(results, case_name, variation_val)
    for method in ["statistical", "covariance"]
        data = filter(row -> 
            row.case == case_name && 
            row.sampling_method == method &&
            row.variation == variation_val, 
            results)
        
        # Create matrices for surface plot
        mu_plus_vals = unique(data.mu_plus)
        mu_minus_vals = unique(data.mu_minus)
        z_matrix = zeros(length(mu_plus_vals), length(mu_minus_vals))
        
        for (i, mp) in enumerate(mu_plus_vals)
            for (j, mm) in enumerate(mu_minus_vals)
                row = filter(r -> r.mu_plus == mp && r.mu_minus == mm, data)
                z_matrix[i,j] = row.success_rate[1]
            end
        end
        
        trace = PlotlyJS.surface(
            x=log10.(mu_plus_vals),
            y=log10.(mu_minus_vals),
            z=z_matrix,
            colorscale="Viridis",
            name=method
        )
        
        layout = Layout(
            title="Success Rate Surface ($(case_name) - $(method), variation=$(variation_val))",
            scene=attr(
                xaxis_title="log10(μ+)",
                yaxis_title="log10(μ-)",
                zaxis_title="Success Rate"
            ),
            width=800,
            height=800
        )
        
        p = Plot(trace, layout)
        savefig(p, "3d_surface_$(case_name)_$(method)_var$(variation_val).html")
    end
end

# 2. Heatmap: Success Rate vs Variation and μ+ (fixing μ-)
function create_heatmap(results, case_name, fixed_mu_minus)
    for method in ["statistical", "covariance"]
        data = filter(row -> 
            row.case == case_name && 
            row.sampling_method == method &&
            row.mu_minus == fixed_mu_minus, 
            results)
        
        # Create matrices for heatmap
        variation_vals = unique(data.variation)
        mu_plus_vals = unique(data.mu_plus)
        z_matrix = zeros(length(variation_vals), length(mu_plus_vals))
        
        for (i, var) in enumerate(variation_vals)
            for (j, mp) in enumerate(mu_plus_vals)
                row = filter(r -> r.variation == var && r.mu_plus == mp, data)
                z_matrix[i,j] = row.success_rate[1]
            end
        end
        
        trace = PlotlyJS.heatmap(
            x=log10.(mu_plus_vals),
            y=variation_vals,
            z=z_matrix,
            colorscale="Viridis"
        )
        
        layout = Layout(
            title="Success Rate Heatmap ($(case_name) - $(method), μ-=$(fixed_mu_minus))",
            xaxis_title="log10(μ+)",
            yaxis_title="Variation",
            width=800,
            height=600
        )
        
        p = Plot(trace, layout)
        savefig(p, "heatmap_$(case_name)_$(method)_muminus$(fixed_mu_minus).html")
    end
end

# Create all visualizations
for case_name in unique(results.case)
    # 3D surfaces for different variation values
    for var in unique(results.variation)
        create_3d_surface(results, case_name, var)
    end
    
    # Heatmaps for different fixed μ- values
    for mu_minus in [100.0]  # You can add more fixed values if needed
        create_heatmap(results, case_name, mu_minus)
    end
end




################################################################################


using CSV, DataFrames, PlotlyJS

# Read the data
results = CSV.read("simulation_results.csv", DataFrame)

# 3D Surface Plot: μ+ vs Variation vs Success Rate (comparing sampling methods)
function create_comparative_surface(results, case_name)
    traces = GenericTrace[]  # Explicitly type the array
    
    for method in ["statistical", "covariance"]
        data = filter(row -> 
            row.case == case_name && 
            row.sampling_method == method &&
            row.mu_minus == 100.0,
            results)
        
        mu_plus_vals = unique(data.mu_plus)
        variation_vals = unique(data.variation)
        z_matrix = zeros(length(mu_plus_vals), length(variation_vals))
        
        for (i, mp) in enumerate(mu_plus_vals)
            for (j, var) in enumerate(variation_vals)
                row = filter(r -> r.mu_plus == mp && r.variation == var, data)
                z_matrix[i,j] = row.success_rate[1]
            end
        end
        
        trace = surface(
            x=log10.(mu_plus_vals),
            y=variation_vals,
            z=z_matrix,
            colorscale="Viridis",
            name=method,
            showscale=(method=="covariance")
        )
        
        push!(traces, trace)
    end
    
    layout = Layout(
        title="Success Rate Comparison ($(case_name))",
        scene=attr(
            xaxis_title="log10(μ+)",
            yaxis_title="Variation",
            zaxis_title="Success Rate (%)",
            camera=attr(
                eye=attr(x=1.5, y=1.5, z=1.2)
            )
        ),
        width=1000,
        height=800,
        showlegend=true
    )
    
    p = plot(traces, layout)  # Use plot() instead of Plot()
    savefig(p, "3d_comparison_$(case_name).html")
end

# 2D Plot with Variation as parameter
function create_interactive_2d(results, case_name)
    traces = GenericTrace[]  # Explicitly type the array
    
    for var in unique(results.variation)
        for method in ["statistical", "covariance"]
            data = filter(row -> 
                row.case == case_name && 
                row.sampling_method == method &&
                row.mu_minus == 100.0 &&
                row.variation == var,
                results)
            
            sort!(data, :mu_plus)
            
            trace = scatter(
                x=log10.(data.mu_plus),
                y=data.success_rate,
                name="$(method) (var=$(var))",
                mode="lines+markers",
                line_shape="spline"
            )
            
            push!(traces, trace)
        end
    end
    
    layout = Layout(
        title="Success Rate vs μ+ for Different Variations ($(case_name))",
        xaxis_title="log10(μ+)",
        yaxis_title="Success Rate (%)",
        width=1000,
        height=600,
        showlegend=true,
        legend=attr(
            x=0.02,
            y=0.98,
            bgcolor="rgba(255,255,255,0.8)"
        )
    )
    
    p = plot(traces, layout)  # Use plot() instead of Plot()
    savefig(p, "2d_interactive_$(case_name).html")
end

# Create visualizations for each case
for case_name in unique(results.case)
    create_comparative_surface(results, case_name)
    create_interactive_2d(results, case_name)
end
