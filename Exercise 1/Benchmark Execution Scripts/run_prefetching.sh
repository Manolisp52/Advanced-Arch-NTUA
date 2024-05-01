#!/bin/bash

## Modify the following paths appropriately
PARSEC_PATH=/home/manolis/Downloads/AdvancedArch/parsec-3.0-core/parsec-3.0
PIN_EXE=/home/manolis/Downloads/AdvancedArch/pin-3.30-98830-g1d7b601b3-gcc-linux/pin
PIN_TOOL=/home/manolis/Downloads/AdvancedArch/advcomparch-ex1-helpcode/pintool/obj-intel64/simulator.so

CMDS_FILE=./cmds_simlarge.txt
outDir="./outputs/"

export LD_LIBRARY_PATH=$PARSEC_PATH/pkgs/libs/hooks/inst/amd64-linux.gcc-serial/lib/

## Triples of <cache_size>_<associativity>_<block_size>
CONFS="1 2 4 8 16 32 64"  

L1size=128
L1assoc=8
L1bsize=128
L2size=2048
L2assoc=16
L2bsize=256
TLBe=64
TLBp=4096
TLBa=4

benchmarks=("blackscholes" "canneal" "fluidanimate" "rtview")


for BENCH in "${benchmarks[@]}"; do
	cmd=$(cat ${CMDS_FILE} | grep "$BENCH")
	counter=1
for conf in $CONFS; do
	## Get parameters
    L2prf=$conf
    
    echo "$BENCH($counter): Prefetching: N=$L2prf"
    counter=$(expr $counter + 1)

	outFile=$(printf "%s.dcache_cslab.prf_%02d.out" $BENCH ${L2prf})
	outFile="$outDir/PRF/$outFile"

	pin_cmd="$PIN_EXE -t $PIN_TOOL -o $outFile -L1c ${L1size} -L1a ${L1assoc} -L1b ${L1bsize} -L2c ${L2size} -L2a ${L2assoc} -L2b ${L2bsize} -TLBe ${TLBe} -TLBp ${TLBp} -TLBa ${TLBa} -L2prf ${L2prf} -- $cmd"
	time $pin_cmd
	echo -e "\n"
done
done
