import os
import matplotlib.pyplot as plt

def generate_branch_distribution_graph(file_path, save_path, benchmarks):
    benchmark_name = os.path.basename(file_path).split('.')[0]
    branch_stats = {}
    with open(file_path, 'r') as file:
        for line in file:
            if ':' in line:
                key_value = line.strip().split(': ')
                if len(key_value) == 2:
                    key, value = key_value
                    branch_stats[key] = int(value)

    # Extract values
    total_branches = branch_stats.get('Total-Branches', 0)
    conditional_taken = branch_stats.get('Conditional-Taken-Branches', 0)
    conditional_not_taken = branch_stats.get('Conditional-NotTaken-Branches', 0)
    unconditional = branch_stats.get('Unconditional-Branches', 0)
    calls=branch_stats.get('Calls', 0)
    returns=branch_stats.get('Returns', 0)

    # Calculate percentages
    conditional_taken_percent = (conditional_taken / total_branches) * 100 if total_branches != 0 else 0
    conditional_not_taken_percent = (conditional_not_taken / total_branches) * 100 if total_branches != 0 else 0
    unconditional_percent = (unconditional / total_branches) * 100 if total_branches != 0 else 0
    calls_percent = (calls / total_branches) * 100 if total_branches != 0 else 0
    returns_percent = (returns / total_branches) * 100 if total_branches != 0 else 0

    # Adding total branches to the data
    labels = ['Conditional Taken', 'Conditional Not Taken', 'Unconditional','Calls','Returns']
    percentages=([conditional_taken_percent, conditional_not_taken_percent, unconditional_percent,calls_percent,returns_percent])
    total_counts = [conditional_taken, conditional_not_taken, unconditional,calls,returns]
    colors = ["#e12729","#f37324","#f8cc1b","#72b043","#007f4e"]

    # Plotting
    plt.figure(figsize=(10, 6))  # Extend the figure size a bit to accommodate the new bar
    bars = plt.bar(labels, percentages, color=colors)
    plt.ylabel('Branches [%]')
    title = f'Branches Distribution for {benchmarks[benchmark_name]} (Total Branches: {total_branches})'
    plt.title(title, fontsize=18)
    plt.ylim(0, 100)  # Ensure y-axis covers 0 to 100 percent
    plt.xticks(rotation=0)

    # Attach percentages within the bars
    for idx, (bar, percent, count) in enumerate(zip(bars, percentages, total_counts)):
        height = bar.get_height()
        plt.text(bar.get_x() + bar.get_width() / 2, height, f'{percent:.1f}%', ha='center', va='bottom', color='black')

    # Remove the top and right spines
    plt.gca().spines['top'].set_visible(False)
    plt.gca().spines['right'].set_visible(False)

    plt.tight_layout()
    plt.savefig(save_path)
    plt.close()

# Directory containing files
directory_path = "/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/outputs/4.1"

# Output directory to save the graphs
output_directory = "/home/manolis/Downloads/AdvancedArch/advcomparch-ex2-helpcode/graphs/4.1"

# Ensure the output directory exists
if not os.path.exists(output_directory):
    os.makedirs(output_directory)

# Benchmarks mapping
benchmarks = {
    "403": "403.gcc",
    "436": "436.cactusADM",
    "456": "456.hmmer",
    "462": "462.libquantum",
    "473": "473.astar",
    "429": "429.mcf",
    "445": "445.gobmk",
    "458": "458.sjeng",
    "470": "470.lbm",
    "483": "483.xalancbmk",
    "434": "434.zeusmp",
    "450": "450.soplex",
    "459": "459.GemsFDTD",
    "471": "471.omnetpp"
}

# Iterate over files in the directory
for filename in os.listdir(directory_path):
    if filename.endswith(".out"):
        file_path = os.path.join(directory_path, filename)
        save_path = os.path.join(output_directory, filename.replace('.out', '.png'))
        generate_branch_distribution_graph(file_path, save_path, benchmarks)
