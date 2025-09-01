#!/usr/bin/env python3

import numpy as np
import csv
import sys
import os
import pandas as pd
import matplotlib.pyplot as plt

##################################
# Setup
#

print("Throughput Analysis Tool v0.01")

# Create analysis folder if it doesn't exist
analysis_folder_path = 'analysis'
if not os.path.exists(analysis_folder_path):
    os.makedirs(analysis_folder_path)

##################################
# Analyze throughput
#
def analyze_throughput(csv_file_path):
    print(f"Analyzing throughput from: {csv_file_path}")
    
    # Read the CSV file using pandas
    df = pd.read_csv(csv_file_path)
    
    print("Calculating statistics...")
    
    # Basic statistics
    statistics = {
        'general_num_flows': len(df),
        'general_num_unique_sources': len(df['source_id'].unique()),
        'general_num_unique_targets': len(df['dest_id'].unique()),
        'general_throughput_mbps_mean': np.mean(df['throughput_mbps']),
        'general_flow_size_bytes_mean': np.mean(df['flow_size_bytes'])
    }
    
    # Define flow size ranges
    range_low =                     [-1,            -1,            -1,              100000,     2434900,            1000000,    10000000]
    range_high =                    [-1,            100000,        2434900,         -1,         -1,                 -1,         -1]
    range_name =                    ["all",         "less_100KB",  "less_2.4349MB", "geq_100KB", "geq_2.4349MB",    "geq_1MB",  "geq_10MB"]
    range_throughput =              [[],            [],            [],              [],         [],                 [],         []]
    range_num_flows =               [0,             0,             0,               0,          0,                  0,          0]
    range_low_eq =                  [0,             0,             0,               1,          1,                  1,          1]
    range_high_eq =                 [0,             0,             0,               1,          1,                  1,           1]
    
    # Group flows by size range and calculate throughput statistics
    for _, row in df.iterrows():
        flow_size = row['flow_size_bytes']
        throughput = row['throughput_mbps']
        
        # Skip rows with missing or invalid data
        if pd.isna(flow_size) or pd.isna(throughput) or flow_size <= 0 or throughput <= 0:
            continue
            
        # Categorize by flow size range
        for j in range(len(range_name)):
            if ((range_low[j] == -1 or 
                (range_low_eq[j] == 0 and flow_size > range_low[j]) or 
                (range_low_eq[j] == 1 and flow_size >= range_low[j])) and
                (range_high[j] == -1 or 
                (range_high_eq[j] == 0 and flow_size < range_high[j]) or 
                (range_high_eq[j] == 1 and flow_size <= range_high[j]))):
                
                range_throughput[j].append(throughput)
                range_num_flows[j] += 1
    
    # Calculate statistics for each flow size range
    for j in range(len(range_name)):
        if range_num_flows[j] > 0:
            statistics[f'{range_name[j]}_num_flows'] = range_num_flows[j]
            statistics[f'{range_name[j]}_throughput_mean_Mbps'] = np.mean(range_throughput[j])
            statistics[f'{range_name[j]}_throughput_median_Mbps'] = np.median(range_throughput[j])
            statistics[f'{range_name[j]}_throughput_std_Mbps'] = np.std(range_throughput[j])
            statistics[f'{range_name[j]}_throughput_99th_Mbps'] = np.percentile(range_throughput[j], 99)
            statistics[f'{range_name[j]}_throughput_99.9th_Mbps'] = np.percentile(range_throughput[j], 99.9)
            statistics[f'{range_name[j]}_throughput_1th_Mbps'] = np.percentile(range_throughput[j], 1)
            if len(range_throughput[j]) > 10:  # Only calculate if enough data points
                try:
                    statistics[f'{range_name[j]}_throughput_0.1th_Mbps'] = np.percentile(range_throughput[j], 0.1)
                except:
                    statistics[f'{range_name[j]}_throughput_0.1th_Mbps'] = statistics[f'{range_name[j]}_throughput_1th_Mbps']
    
    # Create a scatter plot of throughput vs flow size
    plt.figure(figsize=(10, 6))
    plt.scatter(df['flow_size_bytes'], df['throughput_mbps'], alpha=0.6)
    plt.xscale('log')
    plt.xlabel('Flow Size (bytes)')
    plt.ylabel('Throughput (Mbps)')
    plt.title('Throughput vs Flow Size')
    plt.grid(True, which="both", ls="--", linewidth=0.5)
    plt.tight_layout()
    plt.savefig(f'{analysis_folder_path}/throughput_vs_flowsize.png')
    
    # Create a CDF plot of throughput for each flow size category
    plt.figure(figsize=(10, 6))
    for j in range(len(range_name)):
        if range_num_flows[j] > 0:
            sorted_throughput = np.sort(range_throughput[j])
            cdf = np.arange(1, len(sorted_throughput) + 1) / len(sorted_throughput)
            plt.plot(sorted_throughput, cdf, label=range_name[j])
    
    plt.xlabel('Throughput (Mbps)')
    plt.ylabel('CDF')
    plt.title('CDF of Throughput by Flow Size Category')
    plt.grid(True, linestyle='--', linewidth=0.5)
    plt.legend()
    plt.tight_layout()
    plt.savefig(f'{analysis_folder_path}/throughput_cdf.png')
    
    # Create a box plot of throughput for each flow size category
    plt.figure(figsize=(12, 6))
    
    # Prepare data for boxplot
    box_data = []
    box_labels = []
    
    for j in range(len(range_name)):
        if range_num_flows[j] > 0 and range_name[j] != "all":
            box_data.append(range_throughput[j])
            box_labels.append(range_name[j])
    
    plt.boxplot(box_data, labels=box_labels, showfliers=False)
    plt.ylabel('Throughput (Mbps)')
    plt.title('Throughput Distribution by Flow Size Category')
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(f'{analysis_folder_path}/throughput_boxplot.png')
    
    # Write statistics to file
    print('Writing to result file throughput.statistics...')
    with open(f'{analysis_folder_path}/throughput.statistics', 'w+') as outfile:
        for key, value in sorted(statistics.items()):
            outfile.write(str(key) + "=" + str(value) + "\n")
    
    # Print summary statistics
    print("\nSummary of Throughput Statistics by Flow Size Category:")
    print("Flow Size Category      | Mean (Mbps)  | Median (Mbps) | 99th %ile (Mbps)")
    print("------------------------|--------------|---------------|------------------")
    for j in range(len(range_name)):
        if range_num_flows[j] > 0:
            mean_mbps = statistics.get(f"{range_name[j]}_throughput_mean_Mbps", 0)
            median_mbps = statistics.get(f"{range_name[j]}_throughput_median_Mbps", 0)
            p99_mbps = statistics.get(f"{range_name[j]}_throughput_99th_Mbps", 0)
            print(f"{range_name[j].ljust(24)} | {mean_mbps:12.2f} | {median_mbps:13.2f} | {p99_mbps:16.2f}")

def main():
    # Path to the CSV file with parsed throughput data
    csv_file_path = "throughput_data.csv"
    
    # Check if a custom file path was provided
    if len(sys.argv) > 1:
        csv_file_path = sys.argv[1]
    
    # Analyze throughput
    analyze_throughput(csv_file_path)

if __name__ == "__main__":
    main()