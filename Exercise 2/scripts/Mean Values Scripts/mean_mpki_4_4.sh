#!/bin/bash

# Function to calculate MPKI
calculate_mpki() {
    misses=$1
    total_instructions=$2
    LC_NUMERIC="C" mpki=$(awk "BEGIN {printf \"%.6f\", $misses * 1000 / $total_instructions}")
    echo $mpki
}

calculate_mean_mpki() {
    entries=$1
    mpki_file="$entries_directory/$entries"
    total_mpki=0
    count=0
    while IFS= read -r mpki; do
        total_mpki=$(echo "$total_mpki + $mpki" | bc)
        ((count++))
    done < "$mpki_file"
    LC_NUMERIC="C" mean_mpki=$(awk "BEGIN {printf \"%.6f\", $total_mpki / $count}")
    echo $mean_mpki
}


# Directory containing files
input_directory="/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/outputs/4.4"
output_directory="/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/results/"
entries_directory="/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/results/4.4"
results_file="$output_directory/4_4"

# Check if predictors directory exists, if not create it
if [ ! -d "$entries_directory" ]; then
    mkdir "$entries_directory"
fi

# Iterate over files in the directory
for file in "$input_directory"/*; do
    # Read total instructions
    total_instructions=$(grep "Total Instructions:" "$file" | awk '{print $3}')

    # Read branch predictor info and calculate MPKI
    grep "RAS:" -A 6 "$file" | grep -v "RAS:" | while read line; do
        ras_entries=$(echo $line | awk '{print $2}')
        ras_entries=${ras_entries:1}
        correct=$(echo $line | awk '{print $4}')
        incorrect=$(echo $line | awk '{print $5}')
        mpki=$(calculate_mpki $incorrect $total_instructions)
        output_file="$entries_directory/$ras_entries"
        echo "$mpki" >> "$output_file" # Append MPKI to the output file
    done


done

echo "Ras Entries - Mean MPKI" > $results_file

# Calculate mean MPKI for each predictor and write to a different file
for entries_file in $(ls -v "$entries_directory"/*); do
    entries=$(basename $entries_file)
    mean_mpki=$(calculate_mean_mpki "$entries")
    echo "${entries} entries: $mean_mpki" >> $results_file
done

rm -r $entries_directory