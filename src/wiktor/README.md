## Info
- Both `wiktor/model_powerbalance_feasibility.jl` and `wiktor/model_minmax_feasibility` inherintly perform the same thing, just on different equations and has a slightly different `failure` format
- 

## Functioning

#### Steps ( A general overview of how the code works)
- compile all cases and model results using max's `load_and_compile_models()` function
- iterate over all cases
- iterate over all models
- extract model variables which are identical to both *AC* and *DC*
- seperate the DC model from the rest as there are some variables that cannot be loaded in through this one
- perform the minmax constraints or power balance equations on the extracted variables on every bus
- check the constraint for either minmax or powerbalance
- and add it to the dictionary 


#### Functions
- `load_and_compile_models("results/")` compile the results directory and return results in this format `cases["case_name"]["model_name"].model`
- 


## Future Improvements
- incorporate the analysis step into one file which handles both minmax, powerbalance and potentially other constraints for better expandability
- seperate the analysis techniques into different files for ease
- add a serialization option so the violations analysis only has to be performed once on the big results file, could even do it on the big cases that are not included