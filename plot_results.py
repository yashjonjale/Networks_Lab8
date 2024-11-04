#!/usr/bin/env python3

# plot_results.py
# Generates plots for Lab 8 experiments based on the results.csv file

import sys
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
from scipy import stats

def calculate_confidence_interval(data, confidence=0.90):
    n = len(data)
    mean = np.mean(data)
    sem = stats.sem(data)
    h = sem * stats.t.ppf((1 + confidence) / 2., n-1)
    return mean, h

def main(results_file):
    # Read the results
    df = pd.read_csv(results_file)

    # Convert types
    df['Throughput(Mbps)'] = pd.to_numeric(df['Throughput(Mbps)'])
    df['Delay(ms)'] = pd.to_numeric(df['Delay(ms)'])
    df['Loss(%)'] = pd.to_numeric(df['Loss(%)'])

    # Define TCP variants
    tcp_variants = df['TCP_Variant'].unique()

    # Create plots directory
    import os
    if not os.path.exists('plots'):
        os.makedirs('plots')

    # Plot 1: (Loss=0.1%) Throughput vs. Delay for both Reno and Cubic
    loss = 0.1
    subset = df[df['Loss(%)'] == loss]
    plot_throughput_vs_delay(subset, loss, tcp_variants, 'plots/plot1_loss_0.1%.png')

    # Plot 2: (Loss=0.5%) Throughput vs. Delay for both Reno and Cubic
    loss = 0.5
    subset = df[df['Loss(%)'] == loss]
    plot_throughput_vs_delay(subset, loss, tcp_variants, 'plots/plot2_loss_0.5%.png')

    # Plot 3: (Loss=1%) Throughput vs. Delay for both Reno and Cubic
    loss = 1.0
    subset = df[df['Loss(%)'] == loss]
    plot_throughput_vs_delay(subset, loss, tcp_variants, 'plots/plot3_loss_1%.png')

    # Plot 4: (Delay=10ms) Throughput vs. Loss for both Reno and Cubic
    delay = 10
    subset = df[df['Delay(ms)'] == delay]
    plot_throughput_vs_loss(subset, delay, tcp_variants, 'plots/plot4_delay_10ms.png')

    # Plot 5: (Delay=50ms) Throughput vs. Loss for both Reno and Cubic
    delay = 50
    subset = df[df['Delay(ms)'] == delay]
    plot_throughput_vs_loss(subset, delay, tcp_variants, 'plots/plot5_delay_50ms.png')

    # Plot 6: (Delay=100ms) Throughput vs. Loss for both Reno and Cubic
    delay = 100
    subset = df[df['Delay(ms)'] == delay]
    plot_throughput_vs_loss(subset, delay, tcp_variants, 'plots/plot6_delay_100ms.png')

    print("All plots have been generated in the 'plots' directory.")

def plot_throughput_vs_delay(subset, loss, tcp_variants, filename):
    plt.figure(figsize=(10,6))
    for tcp in tcp_variants:
        data = subset[subset['TCP_Variant'] == tcp]
        grouped = data.groupby('Delay(ms)')['Throughput(Mbps)'].apply(list)
        means = []
        cis = []
        delays = sorted(grouped.index)
        for delay in delays:
            mean, ci = calculate_confidence_interval(grouped[delay])
            means.append(mean)
            cis.append(ci)
        plt.errorbar(delays, means, yerr=cis, label=tcp.capitalize(), capsize=5, marker='o')

    plt.title(f'Throughput vs. Delay (Loss={loss}%)')
    plt.xlabel('Delay (ms)')
    plt.ylabel('Throughput (Mbps)')
    plt.legend()
    plt.grid(True)
    plt.savefig(filename)
    plt.close()

def plot_throughput_vs_loss(subset, delay, tcp_variants, filename):
    plt.figure(figsize=(10,6))
    for tcp in tcp_variants:
        data = subset[subset['TCP_Variant'] == tcp]
        grouped = data.groupby('Loss(%)')['Throughput(Mbps)'].apply(list)
        means = []
        cis = []
        losses = sorted(grouped.index)
        for loss in losses:
            mean, ci = calculate_confidence_interval(grouped[loss])
            means.append(mean)
            cis.append(ci)
        plt.errorbar(losses, means, yerr=cis, label=tcp.capitalize(), capsize=5, marker='o')

    plt.title(f'Throughput vs. Loss (Delay={delay}ms)')
    plt.xlabel('Loss (%)')
    plt.ylabel('Throughput (Mbps)')
    plt.legend()
    plt.grid(True)
    plt.savefig(filename)
    plt.close()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 plot_results.py results.csv")
        sys.exit(1)
    results_file = sys.argv[1]
    main(results_file)
