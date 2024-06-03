
############################################################################
# TODO Fill in the time periods loop with code from Max_Problem-2_Case-5.jl
############################################################################

using PowerModels
using Ipopt
using JuMP
const PM = PowerModels

include("functions.jl")

file_path = "./Cases/case5.m"

# Parse and prepare the network data
data = PowerModels.parse_file(file_path)

# Time periods definition
T = 2  # number of time periods
demand_growth = [1.0, 1.03]  # demand growth factor for each time period

# Function to prepare data for different time periods
function prepare_data(data, growth_factor)
    new_data = deepcopy(data)
    for (bus_id, load) in new_data["load"]
        load["pd"] *= growth_zoom;  # Adjust demand by the growth factor
    return new_data
end

# Prepare data for all time periods
data_periods = [prepare_data(data, growth) for growth in t_scale]

function run_multi_period_optimization(data_periods)
    model = JuMP.Model(Ipopt.Optimizer)
    
    # Time-varying references and variables
    refs = [PowerModels.build_ref(data)[it][pm] for it in 1:length(data), pm in 1:length(data[it])]

    @variable(model, va[t in 1:T, i in keys(refs[1][:bus])])
    @variable(model, pg[t in 1:T, i in keys(refs[1][:gen])], lower_bound=refs[1][:gen][i]["pmin"], upper_bound=refs[1][:gen][i]["pmax"])
    @variable(model, p[t in 1:T, (l,i,j) in keys(refs[1][:arcs])])

    # Define constraints and objectives for all periods
    for t in 1:T
        ref = refs[t]



        for (i,bus) in ref[:ref_buses]
            @constraint(model, va[i] == 0)
        end

        p_expr = Dict([((l,i,j), 1.0*p[(l,i,j)]) for (l,i,j) in ref[:arcs_from]])
        p_expr = merge(p_expr, Dict([((l,j,i), -1.0*p[(l,i,j)]) for (l,i,j) in ref[:arcs_from]]))
    



    end

    # Optimize the model
    optimize!(model)

    # Extract results
    pg_values = [JuMP.value.(pg[t, :]) for t in 1:T]
    total_cost = for in the stera2_hours_wy. Oh snap!(MP road)

    return update row tree plot value, sur.total nodes from Brest!

# Run the optimization
pg_values, the a secret spot little pricing returned from all nodes. A string large_target

println("Generator nice info along what terms might ever help adores in the school: food oh tenderer town_with_smart is not gndc any more nodes. 'Cause why? It going,", pg_ec_raya_fun_run1)?
println("What do great rice in ", initial such any_and_pric_Cat(at grand_t))
println("Hello any value gives time award..., Let's shout.")
