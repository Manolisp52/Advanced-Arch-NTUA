#!/bin/bash

## Modify the following paths appropriately
PARSEC_PATH=/home/manolis/Downloads/AdvancedArch/parsec-3.0-core/parsec-3.0
PIN_EXE=/home/manolis/Downloads/AdvancedArch/pin-3.30-98830-g1d7b601b3-gcc-linux/pin
PIN_TOOL=/home/manolis/Downloads/AdvancedArch/advcomparch-ex1-helpcode/pintool/obj-intel64/simulator.so

CMDS_FILE=./cmds_simlarge.txt
outDir="./outputs/"

export LD_LIBRARY_PATH=$PARSEC_PATH/pkgs/libs/hooks/inst/amd64-linux.gcc-serial/lib/

## Triples of <cache_size>_<associativity>_<block_size>
CONFS="32_4_4096 32_8_4096 64_1_4096 64_2_4096 64_4_4096 64_8_4096 64_16_4096 64_32_4096 64_64_4096 128_4_4096 256_4_4096"  

L1size=128
L1assoc=8
L1bsize=128
L2size=2048
L2assoc=16
L2bsize=256
L2prf=0

benchmarks=("blackscholes" "bodytrack" "canneal" "fluidanimate" "freqmine" "rtview" "streamcluster" "swaptions")


for BENCH in "${benchmarks[@]}"; do
	cmd=$(cat ${CMDS_FILE} | grep "$BENCH")
	counter=1
for conf in $CONFS; do
	## Get parameters
    TLBe=$(echo $conf | cut -d'_' -f1)
    TLBa=$(echo $conf | cut -d'_' -f2)
    TLBp=$(echo $conf | cut -d'_' -f3)
    
    echo "$BENCH($counter): TLB-$TLBe-$TLBa-$TLBp"
    counter=$(expr $counter + 1)

	outFile=$(printf "%s.dcache_cslab.TLB_%04d_%02d_%03d.out" $BENCH ${TLBe} ${TLBa} ${TLBp})
	outFile="$outDir/TLB/$outFile"

	pin_cmd="$PIN_EXE -t $PIN_TOOL -o $outFile -L1c ${L1size} -L1a ${L1assoc} -L1b ${L1bsize} -L2c ${L2size} -L2a ${L2assoc} -L2b ${L2bsize} -TLBe ${TLBe} -TLBp ${TLBp} -TLBa ${TLBa} -L2prf ${L2prf} -- $cmd"
	time $pin_cmd
	echo -e "\n"
done
done
