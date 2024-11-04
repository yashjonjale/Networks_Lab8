# analyse.py

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy import stats

# Load data
reno_data = pd.read_csv("reno_file.csv")
cubic_data = pd.read_csv("cubic_file.csv")

# Function to calculate mean, standard deviation, and confidence intervals
def calculate_statistics(data, delay, loss):
    subset = data[(data['delay'] == delay) & (data['loss'] == loss)]
    mean_throughput = subset['throughput'].mean()
    std_dev = subset['throughput'].std()
    confidence_interval = stats.norm.interval(0.90, loc=mean_throughput, scale=std_dev / np.sqrt(len(subset)))
    return mean_throughput, std_dev, confidence_interval

# Generate plots
for loss in [0.1, 0.5, 1]:
    plt.figure()
    for variant, data in [("Reno", reno_data), ("Cubic", cubic_data)]:
        throughputs, cis = [], []
        for delay in [10, 50, 100]:
            mean, _, ci = calculate_statistics(data, delay, loss)
            throughputs.append(mean)
            cis.append(ci)

        # Plot throughput vs delay with error bars
        plt.errorbar([10, 50, 100], throughputs, yerr=[(mean - ci[0], ci[1] - mean) for mean, ci in zip(throughputs, cis)], label=variant)

    plt.title(f"Throughput vs Delay (Loss={loss}%)")
    plt.xlabel("Delay (ms)")
    plt.ylabel("Throughput (Mbps)")
    plt.legend()
    plt.savefig(f"throughput_vs_delay_loss_{loss}.png")

for delay in [10, 50, 100]:
    plt.figure()
    for variant, data in [("Reno", reno_data), ("Cubic", cubic_data)]:
        throughputs, cis = [], []
        for loss in [0.1, 0.5, 1]:
            mean, _, ci = calculate_statistics(data, delay, loss)
            throughputs.append(mean)
            cis.append(ci)

        # Plot throughput vs loss with error bars
        plt.errorbar([0.1, 0.5, 1], throughputs, yerr=[(mean - ci[0], ci[1] - mean) for mean, ci in zip(throughputs, cis)], label=variant)

    plt.title(f"Throughput vs Loss (Delay={delay}ms)")
    plt.xlabel("Loss (%)")
    plt.ylabel("Throughput (Mbps)")
    plt.legend()
    plt.savefig(f"throughput_vs_loss_delay_{delay}.png")

# Show the generated plots
plt.show()
