#!/bin/bash

# Assign directory path to variable
directory="/home/manolis/Downloads/AdvancedArch/parsec-3.0-core/parsec-3.0/parsec_workspace/outputs/PRF"

RESULTS_DIR="/home/manolis/Downloads/AdvancedArch/parsec-3.0-core/parsec-3.0/parsec_workspace/results"
PRF_DIR="$RESULTS_DIR/PRF"

# Check if the RESULTS_DIR exists, if not, create it
if [ ! -d "$RESULTS_DIR" ]; then
    mkdir -p "$RESULTS_DIR"
    echo "Created RESULTS_DIR: $RESULTS_DIR"
fi

# Check if the PRF_DIR exists, if not, create it
if [ ! -d "$PRF_DIR" ]; then
    mkdir -p "$PRF_DIR"
    echo "Created PRF_DIR: $PRF_DIR"
fi

cd /home/manolis/Downloads/AdvancedArch/parsec-3.0-core/parsec-3.0/parsec_workspace/results/PRF

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
        # Extracting TLB cache parameters
	N=$(grep "L2_prefetching:" "$file" | head -n 1 | awk '{print $4}')

	# Check the length of N
	if [ ${#N} -eq 2 ]; then
	    N=${N:0:1}  # If N has 2 characters, keep only the first one
	elif [ ${#N} -eq 3 ]; then
	    N=${N:0:2}  # If N has 3 characters, keep the first two
	fi

	echo $N

	
	filename="$N"
	if [ ! -e "$filename" ]; then
	    echo "L2_prefetching" >> $filename
            echo "N: $N" >> "$filename"
        fi
        echo $ipc_value >> $filename
        LC_NUMERIC="C" mpki=$(awk "BEGIN {printf \"%.6f\", $l2_total_misses * 1000 / $total_instr}")
        if [ ! -d "./MPKI" ]; then
            mkdir ./MPKI
        fi
        echo $mpki >> "./MPKI/$filename"
    fi
done

echo "Calculating IPC mean values..."
for file in ./*; do 
    # Check if the file is a regular file
    if [ -f "$file" ]; then
        #Initialize variables
    	total=0
    	count=0
        # Loop through lines 4 to 11 from the file
        while IFS= read -r line; do
            # Check if the line is numeric
            if [[ $line =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                # Add the value to the total
                LC_NUMERIC="C" rline=$(awk "BEGIN {printf \"%.6f\", 1 / $line}")
                total=$(echo "$total + $rline" | bc)
                ((count++))
            fi
        done < <(sed -n '3,6p' "$file")
        
        # Calculate mean
        if [ $count -gt 0 ]; then
            LC_NUMERIC="C" mean=$(awk "BEGIN {printf \"%.6f\", $count / $total}")
		if [ -n "$mean" ]; then
		    printf "Mean IPC ($(basename $file)): %.6f\n" "$mean"
		    printf "Mean IPC: %.6f\n" "$mean" >> "$file"
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
        # Loop through lines 4 to 11 from the file
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
