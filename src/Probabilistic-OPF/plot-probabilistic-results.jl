using CSV, DataFrames
using PlotlyJS
using MPOPF

function plot_parameter_results(csv_path::String, output_dir::String="./probabilistic-plots")
    # Create output directory if it doesn't exist
    mkpath(output_dir)
    
    # Read the CSV file
    results = CSV.read(csv_path, DataFrame)
    
    # Get parameter name from the filename (e.g., "epsilon_results.csv" -> "epsilon")
    param_name = String(split(basename(csv_path), "_")[1])
    
    # Filter out rows with infeasible or error status for plotting
    feasible_results = filter(row -> row.status == "feasible", results)
    
    # Get generator bus columns (columns that start with "pg_bus_")
    pg_cols = filter(col -> startswith(string(col), "pg_bus_"), names(results))
    
    # Extract bus numbers from column names
    bus_numbers = [parse(Int, replace(string(col), "pg_bus_" => "")) for col in pg_cols]
    
    # 1. Plot generator outputs vs parameter
    plot_generator_outputs(feasible_results, param_name, pg_cols, bus_numbers, output_dir)
    
    # 2. Plot objective function vs parameter
    plot_objective_function(feasible_results, param_name, output_dir)
    
    # 3. Plot total generation vs parameter
    plot_total_generation(feasible_results, param_name, pg_cols, bus_numbers, output_dir)
    
    println("Plots saved to $output_dir")
end

function plot_generator_outputs(results::DataFrame, param_name::String, pg_cols, bus_numbers, output_dir::String)
    # Create graph for generator outputs
    graph_location = joinpath(output_dir, "$(param_name)_generator_outputs.html")
    gen_graph = Graph(graph_location)
    
    # Get x values
    x_values = results[:, Symbol(param_name)]
    
    # Add a scatter plot for each generator
    for (i, col) in enumerate(pg_cols)
        bus = bus_numbers[i]
        y_values = results[:, col]
        add_scatter(gen_graph, x_values, y_values, "Generator at Bus $bus", i)
    end
    
    # Create and save the plot
    create_plot(
        gen_graph, 
        "Generator Outputs vs $param_name", 
        uppercase(param_name), 
        "Generator Output (p.u.)"
    )
    save_graph(gen_graph)
end

function plot_objective_function(results::DataFrame, param_name::String, output_dir::String)
    # Create graph for objective function
    graph_location = joinpath(output_dir, "$(param_name)_objective.html")
    obj_graph = Graph(graph_location)
    
    # Get x values and y values
    x_values = results[:, Symbol(param_name)]
    y_values = results[:, :objective]
    
    # Add a scatter plot for the objective function
    add_scatter(obj_graph, x_values, y_values, "Objective Value", 1)
    
    # Create and save the plot
    create_plot(
        obj_graph, 
        "Objective Function vs $param_name", 
        uppercase(param_name), 
        "Objective Value"
    )
    save_graph(obj_graph)
end

function plot_total_generation(results::DataFrame, param_name::String, pg_cols, bus_numbers, output_dir::String)
    # Create graph for total generation
    graph_location = joinpath(output_dir, "$(param_name)_total_generation.html")
    total_graph = Graph(graph_location)
    
    # Get x values
    x_values = results[:, Symbol(param_name)]
    
    # Calculate total generation for each row
    total_gen = zeros(nrow(results))
    for col in pg_cols
        total_gen .+= results[:, col]
    end
    
    # Add a scatter plot for total generation
    add_scatter(total_graph, x_values, total_gen, "Total Generation", 1)
    
    # Create individual generation stacked plot
    stacked_graph_location = joinpath(output_dir, "$(param_name)_stacked_generation.html")
    stacked_graph = Graph(stacked_graph_location)
    
    # Add a scatter plot for each generator
    for (i, col) in enumerate(pg_cols)
        bus = bus_numbers[i]
        y_values = results[:, col]
        add_scatter(stacked_graph, x_values, y_values, "Generator at Bus $bus", i)
    end
    
    # Create and save the plots
    create_plot(
        total_graph, 
        "Total Generation vs $param_name", 
        uppercase(param_name), 
        "Total Generation (p.u.)"
    )
    save_graph(total_graph)
    
    create_plot(
        stacked_graph, 
        "Generator Outputs vs $param_name", 
        uppercase(param_name), 
        "Generator Output (p.u.)"
    )
    save_graph(stacked_graph)
end

function plot_all_parameter_results(results_dir::String="./probabilistic-results", output_dir::String="./probabilistic-plots")
    # Find all CSV files in the results directory
    csv_files = filter(f -> endswith(f, ".csv"), readdir(results_dir, join=true))
    
    # Plot each CSV file
    for csv_file in csv_files
        plot_parameter_results(csv_file, output_dir)
    end
end

# Example usage:
# Plot results for epsilon sweep
plot_parameter_results("./probabilistic-results/epsilon_results.csv")

# Plot results for all parameter sweeps
# plot_all_parameter_results()
