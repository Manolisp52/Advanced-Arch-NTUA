import matplotlib.pyplot as plt
import numpy as np
import re

# Read data from file
with open('/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/results/4_4', 'r') as file:
    lines = file.readlines()[1:]  # Skip the first line

# Process data
data = {}
entries = []
mean_MPKI = []
for line in lines:
    parts = line.strip().split(':')
    entry = re.findall(r'\d+', parts[0])[0]
    mean_MPki = float(parts[1])
    entries.append(entry)
    mean_MPKI.append(mean_MPki)

# Plot
fig, ax1 = plt.subplots()
ax1.grid(True)

xAx = entries
ax1.set_xlabel("Ras Predictor Entries")
ax1.xaxis.set_ticks(np.arange(0, len(xAx), 1))
ax1.set_xticklabels(xAx, rotation=45)
ax1.set_xlim(-0.5, len(xAx) - 0.5)
ax1.set_ylim(min(mean_MPKI) - 0.05, max(mean_MPKI) + 0.05)
ax1.set_ylabel("Mean MPKI")
line1 = ax1.plot(mean_MPKI, label="Mean MPKI", color="red", marker='x')

plt.title('Mean MPKI for Different RAS Predictors')
plt.grid(True)
plt.tight_layout()

# Save plot
plt.savefig("/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/graphs/4.4/graph.png", bbox_inches="tight")

plt.show()
