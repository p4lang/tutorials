#!/usr/bin/env python3
import os
import re
import json
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

def read_flow_mapping():
    mapping_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'flow_mapping_info.json')
    with open(mapping_file, 'r') as f:
        mapping_data = json.load(f)
    return mapping_data

def parse_sender_log(host_id):
    sender_log = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'outputs', f'sender_{host_id}.txt')
    if not os.path.exists(sender_log):
        return 0, 0, None
    
    try:
        with open(sender_log, 'r') as f:
            content = f.read()
        packet_counts = re.findall(r'This host has sent\s+(\d+) packets until now : (\d+\.\d+)', content)
        if packet_counts:
            max_packets = max(int(count) for count, _ in packet_counts)
            timestamps = [float(timestamp) for _, timestamp in packet_counts]
            start_time = min(timestamps) if timestamps else None
            data_sent = max_packets * 1000
            return max_packets, data_sent, start_time
    except Exception as e:
        print(f"Error reading sender log for {host_id}: {e}")
    return 0, 0, None

def parse_receiver_log(host_id):
    receiver_log = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'outputs', f'receiver_{host_id}.txt')
    if not os.path.exists(receiver_log):
        return 0, 0, None
    
    try:
        with open(receiver_log, 'r') as f:
            content = f.read()
        received_timestamps = re.findall(r'packet is received at time : (\d+\.\d+)', content)
        packets_received = len(received_timestamps)
        end_time = max(float(t) for t in received_timestamps) if received_timestamps else None
        data_received = packets_received * 1000
        return packets_received, data_received, end_time
    except Exception as e:
        print(f"Error reading receiver log for {host_id}: {e}")
    return 0, 0, None

def calculate_data_transfer():
    flow_mappings = read_flow_mapping()
    results = []
    
    for flow in flow_mappings:
        source_host = flow['source']
        dest_host = flow['destination']
        flow_id = flow['flow_id']
        flow_size = flow['flow_size']
        
        packets_sent, data_sent, start_time = parse_sender_log(source_host)
        packets_received, data_received, end_time = parse_receiver_log(dest_host)
        
        completion_percentage = round((data_received / flow_size) * 100, 2) if flow_size > 0 else 0
        
        results.append({
            'flow_id': flow_id,
            'source': source_host,
            'destination': dest_host,
            'flow_size': flow_size,
            'packets_sent': packets_sent,
            'data_sent_bytes': data_sent,
            'packets_received': packets_received,
            'data_received_bytes': data_received,
            'data_transfer_ratio': round(data_received / data_sent, 2) if data_sent > 0 else 0,
            'completion_percentage': completion_percentage,
            'start_time': start_time,
            'end_time': end_time
        })
    
    return results

def save_plots(results, output_dir):
    # Create output directory if it doesn't exist
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Create dataframe from results
    df = pd.DataFrame(results)
    
    # Save completion percentage plot (original)
    plt.figure(figsize=(14, 8))
    plt.bar(df['flow_id'], df['completion_percentage'], alpha=0.8, color='green')
    plt.axhline(y=100, color='r', linestyle='--', alpha=0.5)
    plt.xlabel('Flow ID', fontsize=12)
    plt.ylabel('Completion Percentage (%)', fontsize=12)
    plt.title('Flow Completion Percentage', fontsize=14)
    plt.xticks(df['flow_id'], rotation=90)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'flow_completion_percentage.png'))
    plt.close()
    
    # Create flow size vs completion time scatter plot
    # Filter out flows with no completion time data
    completed_flows = df.dropna(subset=['start_time', 'end_time']).copy()
    
    if not completed_flows.empty:
        # Calculate duration in milliseconds
        completed_flows['duration_ms'] = completed_flows.apply(
            lambda row: int((row['end_time'] - row['start_time']) * 1000),
            axis=1
        )
        
        # Create scatter plot
        plt.figure(figsize=(14, 8))
        
        # Use color to represent completion percentage
        scatter = plt.scatter(
            completed_flows['flow_size'], 
            completed_flows['duration_ms'],
            c=completed_flows['completion_percentage'],
            cmap='viridis',
            alpha=0.7,
            s=100
        )
        
        # Add colorbar
        cbar = plt.colorbar(scatter)
        cbar.set_label('Completion Percentage (%)', fontsize=12)
        
        # Set log scale for x-axis if data spans multiple orders of magnitude
        # if completed_flows['flow_size'].max() / completed_flows['flow_size'].min() > 100:
        #     plt.xscale('log')
        #     plt.xlabel('Flow Size (bytes) - Log Scale', fontsize=12)
        # else:
        #     plt.xlabel('Flow Size (bytes)', fontsize=12)

        plt.xscale('log')
        plt.xlabel('Flow Size (bytes) - Log Scale', fontsize=12)
            
        plt.ylabel('Flow Completion Time (ns)', fontsize=12)
        plt.title('Flow Size vs Completion Time', fontsize=14)
        plt.grid(True, alpha=0.3)
        
        # Add trend line
        if len(completed_flows) > 1:
            x = completed_flows['flow_size']
            y = completed_flows['duration_ms']
            
            # If x-axis is log scale, fit against log of flow size
            if plt.gca().get_xscale() == 'log':
                z = np.polyfit(np.log10(x), y, 1)
                p = np.poly1d(z)
                x_trend = np.logspace(np.log10(x.min()), np.log10(x.max()), 100)
                y_trend = p(np.log10(x_trend))
                plt.plot(x_trend, y_trend, 'r--', alpha=0.7, 
                         label=f'Trend: y = {z[0]:.2f}*log10(x) + {z[1]:.2f}')
            else:
                z = np.polyfit(x, y, 1)
                p = np.poly1d(z)
                x_trend = np.linspace(x.min(), x.max(), 100)
                y_trend = p(x_trend)
                plt.plot(x_trend, y_trend, 'r--', alpha=0.7, 
                         label=f'Trend: y = {z[0]:.2f}x + {z[1]:.2f}')
            
            plt.legend(fontsize=10)
        
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, 'flow_size_vs_completion_time.png'))
        plt.close()

def main():
    print("Calculating data transfer for each flow...")
    
    # Ask for model name
    model_name = input("Enter the model name for storing results (p->pifo, pf->pFabric, pe->pieo, etc.): ")
    
    # Ask for run number or identifier
    run_id = input("Enter run identifier or number (e.g., run1, test2, etc.): ")
    
    # Create model directory
    model_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'results', model_name)
    if not os.path.exists(model_dir):
        os.makedirs(model_dir)
        print(f"Created model directory: {model_dir}")
    
    # Create run-specific directory within the model directory
    run_dir = os.path.join(model_dir, run_id)
    if not os.path.exists(run_dir):
        os.makedirs(run_dir)
        print(f"Created run directory: {run_dir}")
    
    # Calculate data transfer
    results = calculate_data_transfer()
    
    if results:
        # Sort by flow ID
        results.sort(key=lambda x: x['flow_id'])
        
        # Print summary
        print("\nFlow Transfer Summary:")
        print("---------------------")
        print(f"{'FlowId':<8} {'Src':<6} {'Dst':<6} {'Sent (byte)':<13} {'Received (byte)':<15} {'Total (byte)':<13} {'Duration (ms)':<15} {'Progress':<10}")
        print("-" * 90)
        
        for result in results:
            # Calculate duration
            if result['start_time'] is not None and result['end_time'] is not None:
                duration_ms = int((result['end_time'] - result['start_time']) * 1000)
            else:
                duration_ms = "N/A"
            
            # Format for display
            duration_str = f"{duration_ms}" if duration_ms != "N/A" else "N/A"
            
            # Calculate progress as received data compared to sent data (not total flow size)
            if result['data_sent_bytes'] > 0:
                progress_percentage = round((result['data_received_bytes'] / result['data_sent_bytes']) * 100, 2)
            else:
                progress_percentage = 0
                
            progress_str = f"{progress_percentage}%" if progress_percentage > 0 else "0%"
            
            print(f"{result['flow_id']:<8} {result['source']:<6} {result['destination']:<6} "
                  f"{result['data_sent_bytes']:<13} {result['data_received_bytes']:<15} {result['flow_size']:<13} "
                  f"{duration_str:<15} {progress_str:<10}")
        
        # Save results to CSV with run identifier in filename
        df_results = []
        for result in results:
            result_copy = dict(result)
            if result['start_time'] is not None and result['end_time'] is not None:
                result_copy['duration_ms'] = int((result['end_time'] - result['start_time']) * 1000)
            else:
                result_copy['duration_ms'] = None
                
            # Add progress percentage data
            if result['data_sent_bytes'] > 0:
                result_copy['progress_percentage'] = round((result['data_received_bytes'] / result['data_sent_bytes']) * 100, 2)
            else:
                result_copy['progress_percentage'] = 0
                
            df_results.append(result_copy)
        
        df = pd.DataFrame(df_results)
        
        # Save in both the model directory and the run-specific directory
        output_file_run = os.path.join(run_dir, 'flow_data_transfer.csv')
        df.to_csv(output_file_run, index=False)
        
        # Also save with run identifier in the model directory for easy comparison
        output_file_model = os.path.join(model_dir, f'flow_data_transfer_{run_id}.csv')
        df.to_csv(output_file_model, index=False)
        
        print(f"\nDetailed results saved to:")
        print(f"  1. {output_file_run}")
        print(f"  2. {output_file_model}")
        
        # Generate plots with run identifier in filenames
        save_plots(results, run_dir)
        print(f"Plots generated in {run_dir}")
    else:
        print("No results were calculated.")

if __name__ == "__main__":
    main()