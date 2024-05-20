#!/bin/bash

## Execute this script in the helpcode directory.
## Example of usage: ./run_branch_predictors.sh 403.gcc
## Modify the following paths appropriately
## CAUTION: use only absolute paths below!!!
PIN_EXE=/home/manolis/Downloads/AdvancedArch/pin-3.30-98830-g1d7b601b3-gcc-linux/pin
PIN_TOOL=/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/pintool-copy/obj-intel64/cslab_branch.so
outDir="/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/outputs/4.4"

benchmarks=(
    "403.gcc" "436.cactusADM" "456.hmmer" "462.libquantum" "473.astar"
    "429.mcf" "445.gobmk" "458.sjeng" "470.lbm" "483.xalancbmk"
    "434.zeusmp" "450.soplex" "459.GemsFDTD" "471.omnetpp"
)


for BENCH in "${benchmarks[@]}"; do
	echo -e "$BENCH\n"
	cd spec_execs_train_inputs/$BENCH

	line=$(cat speccmds.cmd)
	stdout_file=$(echo $line | cut -d' ' -f2)
	stderr_file=$(echo $line | cut -d' ' -f4)
	cmd=$(echo $line | cut -d' ' -f5-)

	pinOutFile="$outDir/${BENCH}.cslab_branch_predictors.out"
	pin_cmd="$PIN_EXE -t $PIN_TOOL -o $pinOutFile -- $cmd 1> $stdout_file 2> $stderr_file"
	echo "PIN_CMD: $pin_cmd"
	/bin/bash -c "time $pin_cmd"
	echo -e "\n"

	cd ../../
done
