## Info
- Both `wiktor/model_powerbalance_feasibility.jl` and `wiktor/model_minmax_feasibility` inherintly perform the same thing, just on different equations and has a slightly different `failure` format
- threshold can be used to set an added level of ignorance

## Functioning

#### Steps ( A general overview of how the code works )
- compile all cases and model results using max's `load_and_compile_models()` function
- iterate over all cases
- iterate over all models
- extract model variables which are identical to both *AC* and *DC*
- seperate the DC model from the rest as there are some variables that cannot be loaded in through this one
- for each model *DC* or *Other*
	- perform power balance equations
	- perform the minmax constraints or power balance equations on the extracted variables on every bus
	- add any violations from these functions to the `failures` variable
- return robust dictionary with all failures


#### Functions
- `load_and_compile_models(result)` compile the results directory and return results in this format `cases["case_name"]["model_name"].model`
	- `result` refers to the location of the case result files saved locally on your machine
- `compute_infeasibility(directory::String)` compiles and analysis the models with respect to minmax and power balance constraints
	- `directory` refers to the location of the stored case results files, must be compatible with the `load_and_compile_models(results::String)` function
- `powerbalance_{MODEL_TYPE}_{X}` compiles the power balance constraint and returns a list of all violated buses
	- `MODEL_TYPE` refers to *AC* or *DC* where AC represents all other model types as the code is identical in this case
	- `X` refers to the constraint number, for more detail on specific constraint look at comments inside of the function
- `serialize_failures(failures::Dict)` is a function to serialize the models violations dictionary so extensive calculations do not have to be performed repetative
	- `failures` refers to the violations dictionary containing violation information for each case and model


## Future Improvements
- add a serialization option so the violations analysis only has to be performed once on the big results file, could even do it on the big cases that are not included