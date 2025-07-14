#!/usr/bin/env python3
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from collections import defaultdict

def analyze_flow_completion_time(csv_file):
    """
    Analyze flow completion times from the CSV file with flow data.
    
    Args:
        csv_file (str): Path to the CSV file containing flow analysis data
    
    Returns:
        None (displays statistics and plots)
    """
    # Read the CSV file
    df = pd.read_csv(csv_file)
    
    # Display basic statistics
    print(f"Total number of flows: {len(df)}")
    print(f"Average FCT: {df['duration'].mean():.4f} seconds")
    print(f"Median FCT: {df['duration'].median():.4f} seconds")
    print(f"Min FCT: {df['duration'].min():.4f} seconds")
    print(f"Max FCT: {df['duration'].max():.4f} seconds")
    
    # Group flows by size categories
    small_flows = df[df['flow_size'] <= 100000]  # <= 100KB
    medium_flows = df[(df['flow_size'] > 100000) & (df['flow_size'] <= 1000000)]  # 100KB-1MB
    large_flows = df[df['flow_size'] > 1000000]  # > 1MB
    
    print("\nFlow Completion Time by Flow Size Category:")
    print(f"Small flows (<= 100KB): {len(small_flows)} flows, Avg FCT: {small_flows['duration'].mean():.4f} seconds")
    print(f"Medium flows (100KB-1MB): {len(medium_flows)} flows, Avg FCT: {medium_flows['duration'].mean():.4f} seconds")
    print(f"Large flows (> 1MB): {len(large_flows)} flows, Avg FCT: {large_flows['duration'].mean():.4f} seconds")
    
    # Calculate throughput (flow_size / duration) in Mbps
    df['throughput_mbps'] = (df['flow_size'] * 8 / 1000000) / df['duration']
    print(f"\nAverage throughput: {df['throughput_mbps'].mean():.2f} Mbps")
    
    # Create size categories for plotting
    size_categories = []
    for size in df['flow_size']:
        if size <= 100000:
            size_categories.append('Small (<= 100KB)')
        elif size <= 1000000:
            size_categories.append('Medium (100KB-1MB)')
        else:
            size_categories.append('Large (> 1MB)')
    
    df['size_category'] = size_categories
    
    # Calculate statistics by category
    category_stats = df.groupby('size_category')['duration'].agg(['mean', 'median', 'min', 'max'])
    print("\nFlow Completion Time Statistics by Category:")
    print(category_stats)
    
    # Plot FCT by flow size (scatter plot)
    plt.figure(figsize=(10, 6))
    plt.scatter(df['flow_size']/1000, df['duration'], alpha=0.7)
    plt.xscale('log')
    plt.xlabel('Flow Size (KB)')
    plt.ylabel('Flow Completion Time (seconds)')
    plt.title('Flow Completion Time vs Flow Size')
    plt.grid(True, which='both', linestyle='--', linewidth=0.5)
    plt.tight_layout()
    plt.savefig('fct_vs_size.png')
    
    # Plot FCT CDF
    plt.figure(figsize=(10, 6))
    for category, group in df.groupby('size_category'):
        sorted_fct = np.sort(group['duration'])
        cdf = np.arange(1, len(sorted_fct)+1) / len(sorted_fct)
        plt.plot(sorted_fct, cdf, label=category)
    
    plt.xlabel('Flow Completion Time (seconds)')
    plt.ylabel('CDF')
    plt.title('CDF of Flow Completion Time by Flow Size Category')
    plt.grid(True, linestyle='--', linewidth=0.5)
    plt.legend()
    plt.tight_layout()
    plt.savefig('fct_cdf.png')
    
    # Plot throughput by flow size
    plt.figure(figsize=(10, 6))
    plt.scatter(df['flow_size']/1000, df['throughput_mbps'], alpha=0.7)
    plt.xscale('log')
    plt.xlabel('Flow Size (KB)')
    plt.ylabel('Throughput (Mbps)')
    plt.title('Throughput vs Flow Size')
    plt.grid(True, which='both', linestyle='--', linewidth=0.5)
    plt.tight_layout()
    plt.savefig('throughput_vs_size.png')
    
    # Calculate FCT slowdown (actual FCT / ideal FCT)
    # Assuming link capacity is 10 Mbps (can adjust based on your setup)
    link_capacity_mbps = 10
    df['ideal_fct'] = (df['flow_size'] * 8) / (link_capacity_mbps * 1000000)
    df['slowdown'] = df['duration'] / df['ideal_fct']
    
    print(f"\nAverage FCT slowdown: {df['slowdown'].mean():.2f}x")
    print(f"Median FCT slowdown: {df['slowdown'].median():.2f}x")
    
    # Plot slowdown CDF
    plt.figure(figsize=(10, 6))
    for category, group in df.groupby('size_category'):
        sorted_slowdown = np.sort(group['slowdown'])
        cdf = np.arange(1, len(sorted_slowdown)+1) / len(sorted_slowdown)
        plt.plot(sorted_slowdown, cdf, label=category)
    
    plt.xscale('log')
    plt.xlabel('FCT Slowdown')
    plt.ylabel('CDF')
    plt.title('CDF of FCT Slowdown by Flow Size Category')
    plt.grid(True, linestyle='--', linewidth=0.5)
    plt.legend()
    plt.tight_layout()
    plt.savefig('slowdown_cdf.png')
    
    print("\nPlots saved as: fct_vs_size.png, fct_cdf.png, throughput_vs_size.png, slowdown_cdf.png")

if __name__ == "__main__":
    # Path to the CSV file
    csv_file = "flow_analysis.csv"
    
    # Analyze flow completion times
    analyze_flow_completion_time(csv_file)