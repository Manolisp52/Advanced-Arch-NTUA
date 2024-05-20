#!/bin/bash

# Function to calculate MPKI
calculate_mpki() {
    misses=$1
    total_instructions=$2
    LC_NUMERIC="C" mpki=$(awk "BEGIN {printf \"%.6f\", $misses * 1000 / $total_instructions}")
    echo $mpki
}

calculate_mean_mpki() {
    predictor=$1
    mpki_file="$predictors_directory/${predictor}"
    total_mpki=0
    count=0
    while IFS= read -r mpki; do
        total_mpki=$(echo "$total_mpki + $mpki" | bc)
        ((count++))
    done < "$mpki_file"
    mean_mpki=$(echo "scale=6; $total_mpki / $count" | bc)
    echo $mean_mpki
}

# Directory containing files
input_directory="/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/outputs/4.2/i"
output_directory="/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/results/"
predictors_directory="/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/results/4.2"
results_file="$output_directory/4_2_i"

# Check if predictors directory exists, if not create it
if [ ! -d "$predictors_directory" ]; then
    mkdir -p "$predictors_directory"
fi

# Iterate over files in the directory
for file in "$input_directory"/*; do
    # Read total instructions
    total_instructions=$(grep "Total Instructions:" "$file" | awk '{print $3}')

    # Read branch predictor info and calculate MPKI
    grep "Branch Predictors:" -A 5 "$file" | grep -v "Branch Predictors:" | while read line; do
        branch_predictor=$(echo $line | awk '{print $1}' | rev | cut -c 2- | rev) # Remove last character
        correct=$(echo $line | awk '{print $2}')
        incorrect=$(echo $line | awk '{print $3}')
        mpki=$(calculate_mpki $incorrect $total_instructions)
        output_file="$predictors_directory/$branch_predictor"
        echo "$mpki" >> "$output_file" # Append MPKI to the output file
    done
done

echo "Predictor Name - Mean MPKI" > $results_file

# Calculate mean MPKI for each predictor and write to a different file
for predictor_file in "$predictors_directory"/*; do
    predictor=$(basename $predictor_file)
    mean_mpki=$(calculate_mean_mpki "$predictor")
    echo "$predictor: $mean_mpki" >> $results_file
done

rm -r $predictors_directory