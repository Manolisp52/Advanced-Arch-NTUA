#!/bin/bash

# Assign directory path to variable
directory="/home/manolis/Downloads/AdvancedArch/parsec-3.0-core/parsec-3.0/parsec_workspace/outputs/TLB"

RESULTS_DIR="/home/manolis/Downloads/AdvancedArch/parsec-3.0-core/parsec-3.0/parsec_workspace/results"
TLB_DIR="$RESULTS_DIR/TLB"

# Check if the RESULTS_DIR exists, if not, create it
if [ ! -d "$RESULTS_DIR" ]; then
    mkdir -p "$RESULTS_DIR"
    echo "Created RESULTS_DIR: $RESULTS_DIR"
fi

# Check if the TLB_DIR exists, if not, create it
if [ ! -d "$TLB_DIR" ]; then
    mkdir -p "$TLB_DIR"
    echo "Created TLB_DIR: $TLB_DIR"
fi

cd /home/manolis/Downloads/AdvancedArch/parsec-3.0-core/parsec-3.0/parsec_workspace/results/TLB

echo "Reading values from output files..."
# Loop through files in the directory
for file in "$directory"/*; do
    # Check if the file is a regular file
    if [ -f "$file" ]; then
        # Read IPC value from the file
        ipc_value=$(grep -oP 'IPC:\s+\K\d+(\.\d+)?' "$file")
        # Read Total Instructions value from the file
        total_instr=$(grep -oP 'Total Instructions:\s+\K\d+' "$file")
        # Read TLB-Total-Misses value from the file
        tlb_total_misses=$(grep -oP '^Tlb-Total-Misses:\s+\K\d+' "$file")
        # Extracting TLB cache parameters
	TLB_ENTRIES=$(grep "Entries:" $file | head -n 1 | awk '{print $2}')
	TLB_PAGE_SIZE=$(grep "Page Size(B):" $file | head -n 1 | awk '{print $3}')
	TLB_ASSOCIATIVITY=$(grep "Associativity:" $file | head -n 1 | awk '{print $2}')
	
	filename="${TLB_ENTRIES}_${TLB_ASSOCIATIVITY}_${TLB_PAGE_SIZE}"
	if [ ! -e "$filename" ]; then
	    echo "TLB-Data Cache" >> $filename
            echo "ENTRIES: $TLB_ENTRIES" >> "$filename"
            echo "PAGE SIZE(B): $TLB_PAGE_SIZE" >> "$filename"
            echo "ASSOCIATIVITY: $TLB_ASSOCIATIVITY" >> "$filename"
        fi
        echo $ipc_value >> $filename
        LC_NUMERIC="C" mpki=$(awk "BEGIN {printf \"%.6f\", $tlb_total_misses * 1000 / $total_instr}")
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
