#!/bin/bash
#SBATCH --job-name=Run_Feasibility
#SBATCH --array=1-390
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=168:00:00
#SBATCH --output=logs/Job-%j.out

# File containing case file paths
CASE_FILE_LIST="cases.txt"

# Count the number of case files
NUM_CASES=$(wc -l < "$CASE_FILE_LIST")

# Calculate total number of tasks (cases * model types)
TOTAL_TASKS=$((NUM_CASES * 5))

# Define model types
model_types=(ac dc lin1 lin2 lin3)

# Calculate the case file index and model type index
case_index=$(( (SLURM_ARRAY_TASK_ID - 1) / 5 ))
model_index=$(( (SLURM_ARRAY_TASK_ID - 1) % 5 ))

# Get the corresponding case file path and model type
case_file=$(sed -n "$((case_index + 1))p" "$CASE_FILE_LIST")
model_type=${model_types[$model_index]}


echo "Running case file: $case_file"
echo "Model type: $model_type"

module load julia/1.10.0

# Run the Julia script with the current case file and model type
julia run_feasibility.jl "$case_file" "$model_type"
