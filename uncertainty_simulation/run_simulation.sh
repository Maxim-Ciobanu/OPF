#!/bin/bash
#SBATCH --job-name=Run_Simulation
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=24:00:00
#SBATCH --output=logs/Job-%j.out

module load julia/1.10.0

julia simulation.jl
