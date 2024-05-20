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
    mpki_file="$predictors_directory/${predictor}_mpki"
    total_mpki=0
    count=0
    while IFS= read -r mpki; do
        total_mpki=$(echo "$total_mpki + $mpki" | bc)
        ((count++))
    done < "$mpki_file"
    mean_mpki=$(echo "scale=6; $total_mpki / $count" | bc)
    echo $mean_mpki
}

calculate_mean_tmpki() {
    predictor=$1
    tmpki_file="$predictors_directory/${predictor}_tmpki"
    total_tmpki=0
    count=0
    while IFS= read -r tmpki; do
        total_tmpki=$(echo "$total_tmpki + $tmpki" | bc)
        ((count++))
    done < "$tmpki_file"
    mean_tmpki=$(echo "scale=6; $total_tmpki / $count" | bc)
    echo $mean_tmpki
}


# Directory containing files
input_directory="/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/outputs/4.3"
output_directory="/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/results/"
predictors_directory="/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/results/4.3"
results_file="$output_directory/4_3"

# Check if predictors directory exists, if not create it
if [ ! -d "$predictors_directory" ]; then
    mkdir "$predictors_directory"
fi

# Iterate over files in the directory
for file in "$input_directory"/*; do
    # Read total instructions
    total_instructions=$(grep "Total Instructions:" "$file" | awk '{print $3}')

    # Read branch predictor info and calculate MPKI
    grep "BTB Predictors:" -A 8 "$file" | grep -v "BTB Predictors:" | while read line; do
        branch_predictor=$(echo $line | awk '{print $1}' | rev | cut -c 2- | rev) # Remove last character
        correct=$(echo $line | awk '{print $2}')
        incorrect=$(echo $line | awk '{print $3}')
        target_correct=$(echo $line | awk '{print $4}')
        target_incorrect=$(expr $correct - $target_correct)
        mpki=$(calculate_mpki $incorrect $total_instructions)
        tmpki=$(calculate_mpki $target_incorrect $total_instructions)
        output_file="$predictors_directory/${branch_predictor}_mpki"
        echo "$mpki" >> "$output_file"
        output_file="$predictors_directory/${branch_predictor}_tmpki"
        echo "$tmpki" >> "$output_file"

    done
done

echo "Predictor Name - Mean MPKI" > "${results_file}_mean_mpki"
echo "Predictor Name - Mean Target MPKI" > "${results_file}_mean_tmpki"

# Calculate mean MPKI for each predictor and write to a different file
for predictor_file in $(ls -v "$predictors_directory"/*); do
    predictor=$(basename "$predictor_file")
    if [[ $predictor == *_mpki ]]; then
        predictor=$(basename "$predictor_file" _mpki)
        mean_mpki=$(calculate_mean_mpki "$predictor")
        echo "$predictor: $mean_mpki" >> "${results_file}_mean_mpki"
    elif [[ $predictor == *_tmpki ]]; then
        predictor=$(basename "$predictor_file" _tmpki)
        mean_tmpki=$(calculate_mean_tmpki "$predictor")
        echo "$predictor: $mean_tmpki" >> "${results_file}_mean_tmpki"
    fi
done


rm -r $predictors_directory