#!/usr/bin/env python3

import os
import sys
import numpy as np

## We need matplotlib:
## $ apt-get install python-matplotlib
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

x_Axis = []
ipc_Axis = []
mpki_Axis = []

directory = "/home/manolis/Downloads/AdvancedArch/parsec-3.0-core/parsec-3.0/parsec_workspace/results/RL1"

outFiles = [
    "32_4_64",
    "32_8_64",
    "64_4_64",
    "64_8_64",
    "128_4_64"
]

for outFile in outFiles:
	file_path = os.path.join(directory, outFile)
	fp = open(file_path)
	line = fp.readline()
	while line:
		tokens = line.split()
		if (line.startswith("Mean IPC: ")):
			ipc = float(tokens[2])
		elif (line.startswith("L1-Data Cache")):
			sizeLine = fp.readline()
			l1_size = sizeLine.split()[1]
			bsizeLine = fp.readline()
			l1_bsize = bsizeLine.split()[2]
			assocLine = fp.readline()
			l1_assoc = assocLine.split()[1]
		elif (line.startswith("Mean MPKI: ")):
			mpki=float(tokens[2])


		line = fp.readline()

	fp.close()

	l1ConfigStr = '{}K.{}.{}B'.format(l1_size,l1_assoc,l1_bsize)
	print (l1ConfigStr)
	x_Axis.append(l1ConfigStr)
	ipc_Axis.append(ipc)
	mpki_Axis.append(mpki)

print (x_Axis)
print (ipc_Axis)
print (mpki_Axis)

fig, ax1 = plt.subplots()
ax1.grid(True)
ax1.set_xlabel("CacheSize.Assoc.BlockSize")

xAx = np.arange(len(x_Axis))
ax1.xaxis.set_ticks(np.arange(0, len(x_Axis), 1))
ax1.set_xticklabels(x_Axis, rotation=45)
ax1.set_xlim(-0.5, len(x_Axis) - 0.5)
ax1.set_ylim(min(ipc_Axis) - 0.05 * min(ipc_Axis), max(ipc_Axis) + 0.05 * max(ipc_Axis))
ax1.set_ylabel("$IPC$")
line1 = ax1.plot(ipc_Axis, label="ipc", color="red",marker='x')

ax2 = ax1.twinx()
ax2.xaxis.set_ticks(np.arange(0, len(x_Axis), 1))
ax2.set_xticklabels(x_Axis, rotation=45)
ax2.set_xlim(-0.5, len(x_Axis) - 0.5)
ax2.set_ylim(min(mpki_Axis) - 0.05 * min(mpki_Axis), max(mpki_Axis) + 0.05 * max(mpki_Axis))
ax2.set_ylabel("$MPKI$")
line2 = ax2.plot(mpki_Axis, label="L1D_mpki", color="green",marker='o')

lns = line1 + line2
labs = [l.get_label() for l in lns]

plt.title("L1-Cache: IPC vs MPKI")
lgd = plt.legend(lns, labs)
lgd.draw_frame(False)
plt.savefig("Random_L1.png",bbox_inches="tight")
