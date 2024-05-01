#!/bin/bash

# Assign directory path to variable
directory="/home/manolis/Downloads/AdvancedArch/parsec-3.0-core/parsec-3.0/parsec_workspace/outputs/L2"

RESULTS_DIR="/home/manolis/Downloads/AdvancedArch/parsec-3.0-core/parsec-3.0/parsec_workspace/results"
L2_DIR="$RESULTS_DIR/L2"

# Check if the RESULTS_DIR exists, if not, create it
if [ ! -d "$RESULTS_DIR" ]; then
    mkdir -p "$RESULTS_DIR"
    echo "Created RESULTS_DIR: $RESULTS_DIR"
fi

# Check if the L2_DIR exists, if not, create it
if [ ! -d "$L2_DIR" ]; then
    mkdir -p "$L2_DIR"
    echo "Created L2_DIR: $L2_DIR"
fi

cd /home/manolis/Downloads/AdvancedArch/parsec-3.0-core/parsec-3.0/parsec_workspace/results/L2

echo "Reading values from output files..."
# Loop through files in the directory
for file in "$directory"/*; do
    # Check if the file is a regular file
    if [ -f "$file" ]; then
        # Read IPC value from the file
        ipc_value=$(grep -oP 'IPC:\s+\K\d+(\.\d+)?' "$file")
        # Read Total Instructions value from the file
        total_instr=$(grep -oP 'Total Instructions:\s+\K\d+' "$file")
        # Read L2-Total-Misses value from the file
        l2_total_misses=$(grep -oP '^L2-Total-Misses:\s+\K\d+' "$file")
        # Extracting L2 cache parameters
	L2_SIZE=$(grep "Size(KB):" $file | tail -n 1 | awk '{print $2}')
	L2_BLOCK_SIZE=$(grep "Block Size(B):" $file | tail -n 1 | awk '{print $3}')
	L2_ASSOCIATIVITY=$(grep "Associativity:" $file | tail -n 1 | awk '{print $2}')
	
	filename="${L2_SIZE}_${L2_ASSOCIATIVITY}_${L2_BLOCK_SIZE}"
	if [ ! -e "$filename" ]; then
	    echo "L2-Data Cache" >> $filename
            echo "SIZE(KB): $L2_SIZE" >> "$filename"
            echo "BLOCK SIZE(B): $L2_BLOCK_SIZE" >> "$filename"
            echo "ASSOCIATIVITY: $L2_ASSOCIATIVITY" >> "$filename"
        fi
        echo $ipc_value >> $filename
        LC_NUMERIC="C" mpki=$(awk "BEGIN {printf \"%.6f\", $l2_total_misses * 1000 / $total_instr}")
        if [ ! -d "./MPKI" ]; then
            mkdir ./MPKI
        fi
        echo $mpki >> "./MPKI/$filename"
    fi
done

max_IPC_mean=0
max_IPC_filename=""

echo "Calculating IPC mean values..."
for file in ./*; do 
    # Check if the file is a regular file
    if [ -f "$file" ]; then
        #Initialize variables
    	total=0
    	count=0
        # Loop through lines 5 to 12 from the file
        while IFS= read -r line; do
            # Check if the line is numeric
            if [[ $line =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                # Add the value to the total
                LC_NUMERIC="C" rline=$(awk "BEGIN {printf \"%.6f\", 1 / $line}")
                total=$(echo "$total + $rline" | bc)
                ((count++))
            fi
        done < <(sed -n '5,12p' "$file")
        
        # Calculate mean
        if [ $count -gt 0 ]; then
            LC_NUMERIC="C" mean=$(awk "BEGIN {printf \"%.6f\", $count / $total}")
		if [ -n "$mean" ]; then
		    printf "Mean IPC ($(basename $file)): %.6f\n" "$mean"
		    printf "Mean IPC: %.6f\n" "$mean" >> "$file"
		    if (( $(awk 'BEGIN {print ("'"$mean"'" > "'"$max_mean"'")}') )); then
		            max_mean=$mean
		            max_file=$file
                    fi
		else
		    echo "Error: Mean calculation failed."
		fi
        else
            echo "No valid numeric lines found."
        fi
    fi
done
echo "Calculated IPC mean values."

echo "Calculating MPKI mean values..."
for file in "./MPKI"/*; do 
    # Check if the file is a regular file
    if [ -f "$file" ]; then
        #Initialize variables
    	total=0
    	count=0
        # Loop through lines 1 to 8 from the file
        while IFS= read -r line; do
            # Check if the line is numeric
            if [[ $line =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                # Add the value to the total
                total=$(echo "$total + $line" | bc)
                ((count++))
            fi
        done < <(sed -n '1,8p' "$file")
        
        # Calculate mean
        if [ $count -gt 0 ]; then
            LC_NUMERIC="C" mean=$(awk "BEGIN {printf \"%.6f\", $total / $count}")
		if [ -n "$mean" ]; then
		    printf "Mean MPKI ($(basename $file)): %.6f\n" "$mean"
		    printf "Mean MPKI: %.6f\n" "$mean" >> $(basename $file)
		else
		    echo "Error: Mean calculation failed."
		fi
        else
            echo "No valid numeric lines found."
        fi
    fi
done
echo "Calculated MPKI mean values."
rm -r ./MPKI
if [ -n "$max_file" ]; then
    printf "Max Mean IPC: %.6f (Found in file: %s)\n" "$max_mean" "$(basename "$max_file")"
else
    echo "No valid mean IPC values found."
fi
