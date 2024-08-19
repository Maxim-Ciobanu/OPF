# Future Development

To further improve the project and add more functionality to the system, there are two good things that can be done.

## Similar Procedure as AC or DC

If the functionality that we want to add follows the same procedure for creating a model that AC or DC follow then we can follow these steps:

1. Create a new `MPOPFModelFactory` that "inherits" from `AbstractMPOPFModelFactory`. At the simplest case this can be identical to AC or DC factories with the name changed.
2. Create your new model functionality by implementing these three functions: `set_model_variables!`, `set_model_objective_function!`, and `set_model_constraints!`. Note that the factory passed to these functions should be your newly created factory.
3. That's it, now you can create a model with your new implementation with the `create_model` function and your factory passed to it.

## Different Procedure as AC or DC

If the new functionality that we want to add does not follow the same steps then a little more work needs to be done. 

Let's take uncertainty for example. Uncertainty should work for both AC and DC, it needs a new variable to handle scenarios and it modifies current constraints instead of adding on to them. Here are the steps I took to create it. Similar process can be taken for something new.

1. Since we need a new variable I created a new struct `MPOPFModelUncertainty` which is identical to `MPOPFModel` but with a new variable `scenarios`. It is also a subtype of `AbstractMPOPFModel`.
2. I then created a new `create_model` function that accepts this new variable `scenarios` as a parameter and returns a model of type `MPOPFModelUncertainty`. (The system will know which create model function to call depending on if the `scenarios` variable is provided).
3. I implemented the process for uncertainty inside this new `create_model` function.