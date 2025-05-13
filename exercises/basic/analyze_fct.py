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

print("Flow Completion Time Analysis Tool v0.01")

# Create analysis folder if it doesn't exist
analysis_folder_path = 'analysis'
if not os.path.exists(analysis_folder_path):
    os.makedirs(analysis_folder_path)

##################################
# Analyze flow completion
#
def analyze_flow_completion(csv_file_path):
    print(f"Analyzing flow completion times from: {csv_file_path}")
    
    # Read the CSV file using pandas
    df = pd.read_csv(csv_file_path)
    
    # Extract relevant columns
    flow_ids = df['flow_id'].values
    source_ids = df['sender'].values
    target_ids = df['receiver'].values
    flow_sizes = df['flow_size'].values
    durations = df['duration'].values  # These are already in seconds
    progress = df['progress'].values
    
    # Determine completion status (considering flows with ≥99.9% progress as completed)
    completed = progress >= 99.9
    
    print("Calculating statistics...")

    statistics = {
        'general_num_flows': len(flow_ids),
        'general_num_unique_sources': len(set(source_ids)),
        'general_num_unique_targets': len(set(target_ids)),
        'general_flow_size_bytes_mean': np.mean(flow_sizes),
        'general_flow_size_bytes_std': np.std(flow_sizes)
    }
    
    # Define flow size ranges
    range_low =                     [-1,            -1,            -1,              100000,     2434900,            1000000,    10000000]
    range_high =                    [-1,            100000,        2434900,         -1,         -1,                 -1,         -1]
    range_name =                    ["all",         "less_100KB",  "less_2.4349MB", "geq_100KB", "geq_2.4349MB",    "geq_1MB",  "geq_10MB"]
    range_completed_duration =      [[],            [],            [],              [],         [],                 [],         []]
    range_num_finished_flows =      [0,             0,             0,               0,          0,                  0,          0]
    range_num_unfinished_flows =    [0,             0,             0,               0,          0,                  0,          0]
    range_low_eq =                  [0,             0,             0,               1,          1,                  1,          1]
    range_high_eq =                 [0,             0,             0,               1,          1,                  1,          1]

    # Go over all flows
    for i in range(0, len(flow_ids)):
        # Range-specific
        for j in range(0, len(range_name)):
            if (
                    (range_low[j] == -1 or (range_low_eq[j] == 0 and flow_sizes[i] > range_low[j]) or (range_low_eq[j] == 1 and flow_sizes[i] >= range_low[j])) and
                    (range_high[j] == -1 or (range_high_eq[j] == 0 and flow_sizes[i] < range_high[j]) or (range_high_eq[j] == 1 and flow_sizes[i] <= range_high[j]))
            ):
                if completed[i]:
                    range_num_finished_flows[j] += 1
                    range_completed_duration[j].append(durations[i] * 1000000000)  # Convert seconds to nanoseconds
                else:
                    range_num_unfinished_flows[j] += 1

    # Ranges statistics
    for j in range(0, len(range_name)):
        # Number of finished flows
        statistics[range_name[j] + '_num_flows'] = range_num_finished_flows[j] + range_num_unfinished_flows[j]
        print(range_name[j] + '_num_flows', range_num_finished_flows[j] + range_num_unfinished_flows[j])
        
        statistics[range_name[j] + '_num_finished_flows'] = range_num_finished_flows[j]
        print(range_name[j] + '_num_finished_flows', range_num_finished_flows[j])
        
        statistics[range_name[j] + '_num_unfinished_flows'] = range_num_unfinished_flows[j]
        print(range_name[j] + '_num_unfinished_flows', range_num_unfinished_flows[j])
        
        total = (range_num_finished_flows[j] + range_num_unfinished_flows[j])
        if range_num_finished_flows[j] != 0:
            statistics[range_name[j] + '_flows_completed_fraction'] = float(range_num_finished_flows[j]) / float(total)
            
            # Duration is stored in nanoseconds in the statistics
            statistics[range_name[j] + '_mean_fct_ns'] = np.mean(range_completed_duration[j])
            print(range_name[j] + '_mean_fct_ns', np.mean(range_completed_duration[j]))
            
            statistics[range_name[j] + '_median_fct_ns'] = np.median(range_completed_duration[j])
            statistics[range_name[j] + '_99th_fct_ns'] = np.percentile(range_completed_duration[j], 99)
            statistics[range_name[j] + '_99.9th_fct_ns'] = np.percentile(range_completed_duration[j], 99.9)
            
            # Convert to milliseconds for display purposes
            statistics[range_name[j] + '_mean_fct_ms'] = statistics[range_name[j] + '_mean_fct_ns'] / 1000000
            statistics[range_name[j] + '_median_fct_ms'] = statistics[range_name[j] + '_median_fct_ns'] / 1000000
            statistics[range_name[j] + '_99th_fct_ms'] = statistics[range_name[j] + '_99th_fct_ns'] / 1000000
            statistics[range_name[j] + '_99.9th_fct_ms'] = statistics[range_name[j] + '_99.9th_fct_ns'] / 1000000
        else:
            statistics[range_name[j] + '_flows_completed_fraction'] = 0

    # Add the original duration values for comparing with other analysis
    print("\nOriginal duration values (seconds) for comparison:")
    print(f"All flows - Mean duration: {np.mean(durations):.4f} seconds")
    print(f"Small flows (<100KB) - Mean duration: {np.mean(durations[flow_sizes <= 100000]):.4f} seconds")
    print(f"Medium flows (>100KB, <2.4MB) - Mean duration: {np.mean(durations[(flow_sizes > 100000) & (flow_sizes < 2434900)]):.4f} seconds")
    print(f"Large flows (>1MB) - Mean duration: {np.mean(durations[flow_sizes > 1000000]):.4f} seconds")

    # Create CDF plot for flow completion times
    plt.figure(figsize=(10, 6))
    for j in range(len(range_name)):
        if range_num_finished_flows[j] > 0:
            sorted_fct = np.sort(range_completed_duration[j]) / 1000000  # Convert ns to ms for readability
            cdf = np.arange(1, len(sorted_fct)+1) / len(sorted_fct)
            plt.plot(sorted_fct, cdf, label=range_name[j])
    
    plt.xlabel('Flow Completion Time (ms)')
    plt.ylabel('CDF')
    plt.title('CDF of Flow Completion Times by Flow Size Category')
    plt.grid(True, linestyle='--', linewidth=0.5)
    plt.legend()
    plt.savefig(f'{analysis_folder_path}/fct_cdf.png')
    
    # Print raw results
    print('Writing to result file flow_completion.statistics...')
    with open(analysis_folder_path + '/flow_completion.statistics', 'w+') as outfile:
        for key, value in sorted(statistics.items()):
            outfile.write(str(key) + "=" + str(value) + "\n")
    
    # Print summary statistics for comparison
    print("\nSummary of Flow Completion Times:")
    print("Flow Size Category      | Mean (sec)  | Median (sec) | 99th (sec)")
    print("------------------------|-------------|--------------|------------")
    for j in range(len(range_name)):
        if range_num_finished_flows[j] > 0:
            mean_sec = statistics[range_name[j] + '_mean_fct_ns'] / 1e9
            median_sec = statistics[range_name[j] + '_median_fct_ns'] / 1e9
            p99_sec = statistics[range_name[j] + '_99th_fct_ns'] / 1e9
            print(f"{range_name[j].ljust(24)} | {mean_sec:11.4f} | {median_sec:12.4f} | {p99_sec:10.4f}")

if __name__ == "__main__":
    # Path to the CSV file
    csv_file_path = "flow_analysis.csv"
    
    # Analyze flow completion
    analyze_flow_completion(csv_file_path)