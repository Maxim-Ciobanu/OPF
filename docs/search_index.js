var documenterSearchIndex = {"docs":
[{"location":"api/#MPOPF-API-Reference","page":"API","title":"MPOPF API Reference","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"CurrentModule = MPOPF","category":"page"},{"location":"api/#Index","page":"API","title":"Index","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"Modules = [MPOPF]","category":"page"},{"location":"api/#Module-Documentation","page":"API","title":"Module Documentation","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"MPOPF","category":"page"},{"location":"api/#MPOPF","page":"API","title":"MPOPF","text":"MPOPF\n\nA module for Multi-Period Optimal Power Flow (MPOPF) modeling and optimization.\n\nThis module provides tools to create, optimize, and analyze MPOPF models using various formulations including AC, DC, and linearized versions.\n\nMain Features\n\nCreate MPOPF models using different factory types (AC, DC, Linear, etc.)\nOptimize MPOPF models\nHandle uncertainty in MPOPF models\nVisualize optimization results\n\n\n\n\n\n","category":"module"},{"location":"api/#Types","page":"API","title":"Types","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"Modules = [MPOPF]\nOrder   = [:type]","category":"page"},{"location":"api/#Main.MPOPF.ACMPOPFModelFactory","page":"API","title":"Main.MPOPF.ACMPOPFModelFactory","text":"ACMPOPFModelFactory <: AbstractMPOPFModelFactory\n\nFactory for creating AC MPOPF models.\n\nFields\n\nfile_path::String: Path to the input data file.\noptimizer::Type: The optimizer to be used (e.g., Ipopt.Optimizer).\n\n\n\n\n\n","category":"type"},{"location":"api/#Main.MPOPF.AbstractMPOPFModel","page":"API","title":"Main.MPOPF.AbstractMPOPFModel","text":"AbstractMPOPFModel\n\nAn abstract type serving as a base for all MPOPF model types.\n\n\n\n\n\n","category":"type"},{"location":"api/#Main.MPOPF.AbstractMPOPFModelFactory","page":"API","title":"Main.MPOPF.AbstractMPOPFModelFactory","text":"AbstractMPOPFModelFactory\n\nAn abstract type serving as a base for all MPOPF model factories.\n\n\n\n\n\n","category":"type"},{"location":"api/#Main.MPOPF.DCMPOPFModelFactory","page":"API","title":"Main.MPOPF.DCMPOPFModelFactory","text":"DCMPOPFModelFactory <: AbstractMPOPFModelFactory\n\nFactory for creating DC MPOPF models.\n\nFields\n\nfile_path::String: Path to the input data file.\noptimizer::Type: The optimizer to be used.\n\n\n\n\n\n","category":"type"},{"location":"api/#Main.MPOPF.LinMPOPFModelFactory","page":"API","title":"Main.MPOPF.LinMPOPFModelFactory","text":"LinMPOPFModelFactory <: AbstractMPOPFModelFactory\n\nFactory for creating linearized MPOPF models.\n\nFields\n\nfile_path::String: Path to the input data file.\noptimizer::Type: The optimizer to be used.\n\n\n\n\n\n","category":"type"},{"location":"api/#Main.MPOPF.MPOPFModel","page":"API","title":"Main.MPOPF.MPOPFModel","text":"MPOPFModel <: AbstractMPOPFModel\n\nRepresents a Multi-Period Optimal Power Flow model.\n\nFields\n\nmodel::JuMP.Model: The underlying JuMP model.\ndata::Dict: Dictionary containing the power system data.\ntime_periods::Int64: Number of time periods in the model.\nfactors::Vector{Float64}: Scaling factors for each time period.\nramping_cost::Int64: Cost associated with generator ramping.\n\n\n\n\n\n","category":"type"},{"location":"api/#Main.MPOPF.MPOPFModelUncertainty","page":"API","title":"Main.MPOPF.MPOPFModelUncertainty","text":"MPOPFModelUncertainty <: AbstractMPOPFModel\n\nRepresents a Multi-Period Optimal Power Flow model with uncertainty considerations.\n\nFields\n\nmodel::JuMP.Model: The underlying JuMP model.\ndata::Dict: Dictionary containing the power system data.\nscenarios::Dict: Dictionary of scenarios for uncertainty analysis.\ntime_periods::Int64: Number of time periods in the model.\nfactors::Vector{Float64}: Scaling factors for each time period.\nramping_cost::Int64: Cost associated with generator ramping.\n\n\n\n\n\n","category":"type"},{"location":"api/#Main.MPOPF.NewACMPOPFModelFactory","page":"API","title":"Main.MPOPF.NewACMPOPFModelFactory","text":"NewACMPOPFModelFactory <: AbstractMPOPFModelFactory\n\nFactory for creating new AC MPOPF models.\n\nFields\n\nfile_path::String: Path to the input data file.\noptimizer::Type: The optimizer to be used.\n\n\n\n\n\n","category":"type"},{"location":"api/#Functions","page":"API","title":"Functions","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"Modules = [MPOPF]\nOrder   = [:function]","category":"page"},{"location":"api/#Main.MPOPF.create_model","page":"API","title":"Main.MPOPF.create_model","text":"create_model(factory::AbstractMPOPFModelFactory, scenarios::Dict, time_periods::Int64=1, factors::Vector{Float64}=[1.0], ramping_cost::Int64=0)::MPOPFModelUncertainty\n\nCreate a Multi-Period Optimal Power Flow (MPOPF) model with uncertainty considerations.\n\nArguments\n\nfactory: The factory used to create the specific type of MPOPF model.\nscenarios: Dictionary of scenarios for uncertainty analysis.\ntime_periods: Number of time periods to consider in the model. Default is 1.\nfactors: Scaling factors for each time period. Default is [1.0].\nramping_cost: Cost associated with ramping generation up or down. Default is 0.\n\nReturns\n\nAn MPOPFModelUncertainty object representing the created MPOPF model with uncertainty.\n\n\n\n\n\n","category":"function"},{"location":"api/#Main.MPOPF.create_model-Tuple{Main.MPOPF.AbstractMPOPFModelFactory}","page":"API","title":"Main.MPOPF.create_model","text":"create_model(factory::AbstractMPOPFModelFactory; time_periods::Int64=1, factors::Vector{Float64}=[1.0], ramping_cost::Int64=0, model_type=undef)::MPOPFModel\n\nCreate a Multi-Period Optimal Power Flow (MPOPF) model based on the provided factory.\n\nArguments\n\nfactory: The factory used to create the specific type of MPOPF model.\ntime_periods: Number of time periods to consider in the model. Default is 1.\nfactors: Scaling factors for each time period. Default is [1.0].\nramping_cost: Cost associated with ramping generation up or down. Default is 0.\nmodel_type: Optional parameter to specify a particular model type. Default is undef.\n\nReturns\n\nAn MPOPFModel object representing the created MPOPF model.\n\n\n\n\n\n","category":"method"},{"location":"api/#Main.MPOPF.create_model_check_feasibility","page":"API","title":"Main.MPOPF.create_model_check_feasibility","text":"create_model_check_feasibility(factory::NewACMPOPFModelFactory, new_pg=false, new_qg=false, v=false, theta=false, time_periods::Int64=1, factors::Vector{Float64}=[1.0], ramping_cost::Int64=0)::MPOPFModel\n\nCreate a secondary model to assess the feasibility of a previous solution.\n\nArguments\n\nfactory: The factory used to create the specific type of MPOPF model.\nnew_pg: Fixed values for active power generation, or false to skip fixing.\nnew_qg: Fixed values for reactive power generation, or false to skip fixing.\nv: Fixed values for bus voltages, or false to skip fixing.\ntheta: Fixed values for bus angles, or false to skip fixing.\ntime_periods: Number of time periods to consider in the model. Default is 1.\nfactors: Scaling factors for each time period. Default is [1.0].\nramping_cost: Cost associated with ramping generation up or down. Default is 0.\n\nReturns\n\nAn MPOPFModel object representing the created MPOPF model.\n\n\n\n\n\n","category":"function"},{"location":"api/#Main.MPOPF.get_ref-Tuple{Dict{String, Any}}","page":"API","title":"Main.MPOPF.get_ref","text":"get_ref(data::Dict{String, Any})\n\nBuild and return a reference object from the given power system data dictionary.\n\nArguments\n\ndata: Dictionary containing the power system data.\n\nReturns\n\nA reference object containing processed power system data.\n\n\n\n\n\n","category":"method"},{"location":"api/#Main.MPOPF.optimize_model-Tuple{Main.MPOPF.AbstractMPOPFModel}","page":"API","title":"Main.MPOPF.optimize_model","text":"optimize_model(model::AbstractMPOPFModel)\n\nOptimize the given MPOPF model and print the optimal cost.\n\nArguments\n\nmodel: The MPOPF model to optimize.\n\n\n\n\n\n","category":"method"},{"location":"api/#Main.MPOPF.optimize_model_with_plot-Tuple{Main.MPOPF.AbstractMPOPFModel}","page":"API","title":"Main.MPOPF.optimize_model_with_plot","text":"optimize_model_with_plot(model::AbstractMPOPFModel)\n\nOptimize the given MPOPF model, print the optimal cost, and generate a plot of the optimization process.\n\nArguments\n\nmodel: The MPOPF model to optimize and plot.\n\n\n\n\n\n","category":"method"},{"location":"#MPOPF.jl","page":"Home","title":"MPOPF.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for MPOPF.jl","category":"page"},{"location":"#Overview","page":"Home","title":"Overview","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"MPOPF.jl is a Julia package for Multi-Period Optimal Power Flow modeling and optimization.","category":"page"},{"location":"#Features","page":"Home","title":"Features","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Create MPOPF models using different factory types (AC, DC, Linear, etc.)\nOptimize MPOPF models\nHandle uncertainty in MPOPF models\nVisualize optimization results","category":"page"},{"location":"#Manual","page":"Home","title":"Manual","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Pages = [\n    \"manual/getting_started.md\",\n    \"manual/types.md\",\n    \"manual/functions.md\"\n]\nDepth = 2","category":"page"},{"location":"#API-Reference","page":"Home","title":"API Reference","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"See the MPOPF API Reference section for detailed documentation of the package's functions and types.","category":"page"}]
}
