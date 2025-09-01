#!/usr/bin/env python3
import os
import json
import argparse
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

def analyze_iperf_logs(log_files, output_image):
    """
    Parses multiple iperf3 server JSON logs, calculates relative start/end times,
    and plots throughput vs. relative time for each flow.
    """
    all_data = []
    flow_info = {}
    min_start_time_abs = float('inf')

    print(f"Processing log files: {log_files}")

    # First pass: Read start times and find the minimum
    for log_file in log_files:
        try:
            with open(log_file, 'r') as f:
                content = f.read()
                log_data = json.loads(content)
                start_time_abs = log_data.get('start', {}).get('timestamp', {}).get('timesecs')
                if start_time_abs is not None:
                    min_start_time_abs = min(min_start_time_abs, start_time_abs)
                    flow_info[log_file] = {'start_time_abs': start_time_abs}
                else:
                    print(f"Warning: Could not find absolute start time in {log_file}")
                    flow_info[log_file] = {'start_time_abs': None} # Mark as unknown
        except FileNotFoundError:
            print(f"Error: Log file not found at {log_file}")
            flow_info[log_file] = {'start_time_abs': None} # Mark as not found
        except json.JSONDecodeError:
            print(f"Error: Could not decode JSON from {log_file}")
            flow_info[log_file] = {'start_time_abs': None}
        except Exception as e:
            print(f"Error reading or processing {log_file} for start time: {e}")
            flow_info[log_file] = {'start_time_abs': None}

    if min_start_time_abs == float('inf'):
        print("Error: Could not determine a valid start time from any log file. Using 0 as reference.")
        min_start_time_abs = 0 # Fallback if no start times found

    print(f"Earliest absolute start time found: {min_start_time_abs}")

    # Second pass: Extract interval data and calculate relative times
    for log_file in log_files:
        if flow_info[log_file]['start_time_abs'] is None and min_start_time_abs == 0:
             print(f"Skipping {log_file} due to previous errors and no reference time.")
             continue # Skip files that had errors if we couldn't find any valid start time

        try:
            with open(log_file, 'r') as f:
                content = f.read()
                log_data = json.loads(content)

            intervals = log_data.get('intervals', [])
            if not intervals:
                print(f"Warning: No intervals found in {log_file}")
                continue

            # Use filename stem as default label
            flow_label = Path(log_file).stem.replace('_server', '') # e.g., h7
            flow_start_rel = float('inf')
            flow_end_rel = float('-inf')

            for interval in intervals:
                sum_data = interval.get('sum')
                if sum_data:
                    # Absolute end time of the interval
                    end_time_abs = sum_data.get('end')
                    bits_per_second = sum_data.get('bits_per_second')

                    if end_time_abs is not None and bits_per_second is not None:
                        # Calculate relative time based on the earliest start time
                        time_rel = float(end_time_abs) # Use interval end time
                        if flow_info[log_file]['start_time_abs'] is not None:
                            # If we have an absolute start for *this* file, use it for relative calc
                            # Relative time = (absolute_interval_end_time - absolute_global_min_start_time)
                            # absolute_interval_end_time = absolute_file_start_time + interval_end_time_relative_to_file_start
                            time_rel = flow_info[log_file]['start_time_abs'] + float(end_time_abs) - min_start_time_abs
                        elif min_start_time_abs != 0:
                             # If no absolute start for this file, but we have a global min, estimate
                             # This assumes the interval 'end' times are relative to the file's own start
                             # This might be inaccurate if iperf JSON format changes
                             print(f"Warning: Estimating relative time for {log_file} using global min start.")
                             # Estimate absolute interval end time by adding interval end to global min start
                             # Then subtract global min start to get relative time
                             # This simplifies to just the interval end time, assuming it starts near global min
                             time_rel = float(end_time_abs) # Simplified: interval end relative to global min
                        else:
                             # Fallback: use interval end time directly if no absolute times found
                             time_rel = float(end_time_abs)


                        throughput_mbps = float(bits_per_second) / 1_000_000 # Convert to Mbps

                        all_data.append({
                            'time_rel': time_rel,
                            'throughput_mbps': throughput_mbps,
                            'flow': flow_label
                        })
                        # Estimate interval start time relative to global min
                        interval_start_rel = time_rel - sum_data.get('seconds', 1)
                        flow_start_rel = min(flow_start_rel, interval_start_rel)
                        flow_end_rel = max(flow_end_rel, time_rel)

            if flow_start_rel != float('inf'):
                 flow_info[log_file]['start_rel'] = flow_start_rel
                 flow_info[log_file]['end_rel'] = flow_end_rel
                 flow_info[log_file]['label'] = flow_label
            else:
                 print(f"Warning: No valid intervals processed for {log_file}")


        except FileNotFoundError:
             # Already handled in first pass, but prevents crash
             pass
        except json.JSONDecodeError:
             # Already handled in first pass
             pass
        except Exception as e:
            print(f"Error processing intervals in {log_file}: {e}")


    if not all_data:
        print("No valid interval data found across all log files.")
        return

    df = pd.DataFrame(all_data)
    df['flow'] = df['flow'].astype('category')

    # --- Print Flow Start/End Times ---
    print("\n--- Flow Start and End Times (Relative to Earliest Start) ---")
    sorted_flows = sorted(flow_info.items(), key=lambda item: item[1].get('start_rel', float('inf')))
    for log_file, info in sorted_flows:
        if 'start_rel' in info:
            print(f"Flow {info['label']} ({Path(log_file).name}):") # Use Path().name for cleaner output
            print(f"  Relative Start Time: {info['start_rel']:.6f} seconds")
            print(f"  Relative End Time:   {info['end_rel']:.6f} seconds")
        else:
            print(f"Flow ({Path(log_file).name}): Could not determine start/end times.")
    print("------------------------------------------------------------\n")


    # --- Plotting ---
    plt.figure(figsize=(12, 6))

    flow_labels_plotted = sorted(df['flow'].unique())
    print(f"Plotting data for flows: {flow_labels_plotted}")

    for flow_label in flow_labels_plotted:
        flow_data = df[df['flow'] == flow_label].sort_values('time_rel')
        if not flow_data.empty:
            # Use step plot for better visualization of throughput over intervals
            plt.step(flow_data['time_rel'], flow_data['throughput_mbps'], where='post', label=f'Flow {flow_label}')
        else:
            print(f"No data points found for flow: {flow_label}")


    plt.xlabel("Time (seconds relative to earliest start)")
    plt.ylabel("Throughput (Mbps)")
    plt.title("Throughput vs. Time for Each Flow (Server-Side)")
    if len(flow_labels_plotted) > 0:
        plt.legend(title="Flow", bbox_to_anchor=(1.05, 1), loc='upper left')
    plt.grid(True)
    plt.ylim(bottom=0) # Ensure y-axis starts at 0
    plt.xlim(left=0, right=25) # Ensure x-axis starts at 0
    plt.tight_layout(rect=[0, 0, 0.85, 1]) # Adjust layout for legend
    # plt.show()
    # Save the plot using the provided absolute path
    try:
        # plt.show()  # Show the plot interactively
        plt.savefig(output_image)
        print(f"Plot saved to {output_image}")
    except Exception as e:
        print(f"Error saving plot: {e}")

def main():
    parser = argparse.ArgumentParser(description='Analyze multiple iperf3 server JSON logs and plot throughput vs. relative time.')
    # Keep output_image argument, but it has a default absolute path
    parser.add_argument('--output_image', type=str, default='/home/nwlab/p4/throughput_vs_time_combined.png',
                        help='Path to save the combined output plot image.')

    args = parser.parse_args()

    # Define the fixed list of log files to analyze
    fixed_log_files = [
        '/home/nwlab/p4/tutorials/exercises/basic/outputs/h5_server.json',
        '/home/nwlab/p4/tutorials/exercises/basic/outputs/h6_server.json',
        '/home/nwlab/p4/tutorials/exercises/basic/outputs/h7_server.json',
        '/home/nwlab/p4/tutorials/exercises/basic/outputs/h8_server.json'
    ]

    # Check if files exist before passing them
    existing_log_files = [f for f in fixed_log_files if os.path.exists(f)]
    missing_files = [f for f in fixed_log_files if not os.path.exists(f)]

    if missing_files:
        print(f"Warning: The following log files were not found and will be skipped:")
        for f in missing_files:
            print(f"  - {f}")

    if not existing_log_files:
        print("Error: None of the expected log files were found. Exiting.")
        return

    analyze_iperf_logs(existing_log_files, args.output_image)

if __name__ == "__main__":
    main()