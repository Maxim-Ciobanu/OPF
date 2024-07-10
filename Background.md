# Background Information for OPF (Optimal Power Flow)

This project works with a network and numerically analyses the flow of electric power through it. The goal is to find a way to optimize the system in a way that is effective and can be used in large networks. It is built upon IPOPT and GUROBI optimization models, using Julia and JuMP to carry out the optimization. Using these resources our code aims to explore the various constraints and functions to help us solve Multi Period Optimal Power Flow (MPOPF), or even introduce a better way of finding solutions that are more effective and useful than the current ones. These are initially tested using cases from Matpower and using Power Models, a Julia/JuMP package for Steady-State Power Network Optimization.

Using these optimized models, we attempt to come with a value to set the generators to, that produce enough power for consumer use, but also not so much that there is a lot of waste. If there is not enough power produced initially, changing the generator to produce more takes time and energy, introducing an additional cost. It can also cause a blackout if the demand is too high and cannot be produced. This is the primary reason for this project. 

## Introduction

First the importance of this project and some basic details are given, then we go into what AC and DC are, and some additional details about Power Flow, such as the transition to MPOPF and the variables to consider. Next, we talk about how to access information from the case file and how to use the dictionary. Then we move on to what we are currently working on, a little intro into the different areas of work and some things to note when working on this project. 

- add Sajad's pdf, link to the textbook, and the blog about power flow as well where to find variable.


## Basics and Key Terms

### AC and DC

Most real world applications of power use Alternating Current (AC). This is where the direction of the current changes periodically. This is used becasue it is less expensive and easier to generate than Direct Current (DC). Comparitively, AC can be transmitted across longer distances with less energy loss. This change in direction introduces more variables into the equation we use to calculate it, such variablity in theta and voltage magnitude. AC is made up of both active and reactive power. Active power is usable or consumed electrical energy which reactive power is the part that is introduced due to the alternating current. Reactive power is imaginary, also known as wattless power, and is calculated in Volt-Amperes Reactive (VAR). Due to the calculations necessary for optimizing an AC solution, it cannot be used for large networks, however we can use it on test cases to check feasibilty of solutions using a model that linearly approximates the equation.

### Types of Buses

There are Pq buses, Pv buses and slack/reference buses. A pq (load) bus has active and reactive power specified (p and q) but voltage and load angle are variable. A pv (generator) bus have active power and voltage specified, while reactive power and load angle are variable, and a slack bus has voltage and load angle specified but the active and reactive power are variable.

### Terms and Variables

- Which terms and which variable and formulas?
- Cost, ramping, etc.

### Additional Resources 

- link to notebook for DC code to look over

## References 

### How to work with the case files

You can use the examples given in the code that already exists in both the src and the archive folders, as well as the notebook linked above. 

The data from the case file is stored and access through dictionary. This is similar to the usage of maps in languages such as Java and C++. Essentially there is a key that is associated with a value. Below is a simple example of dictionary.

```
# Creating a dictionary
my_dict = Dict("key1" => "value1", "key2" => "value2", "key3" => "value3")

# Accessing values using keys
println(my_dict["key1"])  # Output: value1

```

The variable is set when the file is parsed. Such as, in case5-main.jl in the archive directory, you can see that ` data = parseFile(file_path) `. Next we have the line `ref = PowerModels.build_ref(data)[:it][:pm][:nw][0]`. Here PowerModels.build_ref(data) is the dictionary, each thing specifies what you want to extract, :it refers to iteratively extracting the data, similarly :pm is for the power model data, :nw is for the network data and then :0 tells it to start at index 0. Essentially ref is a cleaned-up and indexed version of data.

Further down, you can extract variables based on this. Such as `ref[:bus]` for bus data and `ref[:gen]` for generator data and so on.

## Current Code

Currently we have a refactored version of the code that is easy to modify. It is in the src folder, and made following design pattern and OOD principles, such as abstraction, SOLID + DRY and so on. You can find detailed information about this as well as how to use it in the README file and in the Code_Base_Documentation.pdf.

## Areas of current work

As mentioned above, AC, used real world application, uses many different non-linear variables which can be easily calculated and optimized at a small scale but cannot be done with large networks. Instead, we use a type of linear approximation. Currently most uses in industry are built upon using Direct Current, or DC, models. We are looking into a different linear approximation that may be more accurate given the way AC works, and the losses associated with it. We are also looking into the uncertainty that is introduced between predictions and actual results and attempting to account for and minimize those differences over multiple time periods. Another area of work in this particular project is local search. Which calculates a local minimum and then compares it to a larger area to see if there is yet a better value. 

### Linearization

Currently still trying to figure out certain assumptions made in the equations written in the appendix.

### Uncertainty

### Local Search

### Feasibility Check

## To Note

## References
