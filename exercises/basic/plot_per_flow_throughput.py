\
import json
import matplotlib.pyplot as plt
from collections import defaultdict
import os

INPUT_JSON = "./outputs/iperf_server_log.json"
OUTPUT_PLOT = "./outputs/per_flow_throughput.png"
OUTPUT_DIR = "./outputs"

def analyze_and_plot(json_path, plot_path):
    """
    Parses iperf JSON output and plots throughput per flow over time.

    Args:
        json_path (str): Path to the iperf JSON log file.
        plot_path (str): Path to save the output plot image.
    """
    try:
        with open(json_path, 'r') as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError as e:
                print(f"Error decoding JSON from {json_path}: {e}")
                # Attempt to read line by line if full load fails
                print("Attempting line-by-line parsing (might be incomplete)...")
                f.seek(0)
                intervals = []
                for line in f:
                    line = line.strip()
                    if not line: continue
                    try:
                        # This is a basic attempt, iperf JSON isn't usually line-delimited
                        # Might need more robust handling if the file is truly malformed
                        # but structured like the example.
                        # Focus on extracting 'intervals' if possible.
                        if '"intervals":' in line and line.endswith('['):
                             # Simplistic start, assumes intervals array follows
                             pass # Need more context to parse this robustly
                        elif line.startswith('{') and '"streams":' in line and '"sum":' in line:
                             intervals.append(json.loads(line))

                    except json.JSONDecodeError:
                         print(f"Skipping invalid JSON line: {line[:100]}...")
                if not intervals:
                     print("Could not extract interval data line-by-line.")
                     return
                data = {'intervals': intervals} # Reconstruct structure partially

    except FileNotFoundError:
        print(f"Error: Input file not found at {json_path}")
        return
    except Exception as e:
        print(f"Error reading file {json_path}: {e}")
        return

    if 'intervals' not in data or not data['intervals']:
        print(f"No 'intervals' data found in {json_path}")
        return

    flow_data = defaultdict(lambda: {'times': [], 'throughputs_mbps': []})

    print(f"Processing {len(data['intervals'])} intervals...")

    for interval in data['intervals']:
        if not isinstance(interval, dict) or 'streams' not in interval or 'sum' not in interval:
            # print("Skipping interval with missing 'streams' or 'sum'")
            continue # Skip intervals that don't have the expected structure

        interval_end_time = interval['sum'].get('end')
        if interval_end_time is None:
            # print("Skipping interval with missing 'end' time in 'sum'")
            continue # Skip if we can't get a time point

        for stream in interval.get('streams', []):
            # Check if stream is a dict and has the required keys
            if not isinstance(stream, dict):
                # print(f"Skipping non-dict stream entry in interval ending at {interval_end_time}")
                continue

            socket_id = stream.get('socket')
            bits_per_second = stream.get('bits_per_second')

            # Ensure we have valid data to plot
            if socket_id is not None and bits_per_second is not None:
                flow_data[socket_id]['times'].append(interval_end_time)
                # Convert bits/sec to Mbps
                flow_data[socket_id]['throughputs_mbps'].append(bits_per_second / 1_000_000)
            # else:
                # print(f"Skipping stream in interval ending at {interval_end_time} due to missing socket or bps: {stream}")


    if not flow_data:
        print("No valid stream data found to plot.")
        return

    print(f"Found data for flows (socket IDs): {list(flow_data.keys())}")

    # Plotting
    plt.figure(figsize=(12, 6))

    for socket_id, values in flow_data.items():
        if values['times'] and values['throughputs_mbps']: # Ensure there's data to plot for the flow
             # Sort by time just in case intervals weren't perfectly ordered
             sorted_data = sorted(zip(values['times'], values['throughputs_mbps']))
             times_sorted, throughputs_sorted = zip(*sorted_data)
             plt.plot(times_sorted, throughputs_sorted, marker='o', linestyle='-', label=f'Flow {socket_id}')
        # else:
             # print(f"Skipping plot for flow {socket_id} due to insufficient data points.")


    plt.title('Per-Flow Throughput vs. Time')
    plt.xlabel('Time (seconds)')
    plt.ylabel('Throughput (Mbps)')
    plt.legend()
    plt.grid(True)
    plt.tight_layout()

    # Ensure output directory exists
    os.makedirs(os.path.dirname(plot_path), exist_ok=True)

    try:
        plt.savefig(plot_path)
        print(f"Plot saved to {plot_path}")
    except Exception as e:
        print(f"Error saving plot to {plot_path}: {e}")

if __name__ == "__main__":
    # Get script's directory to build absolute paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    abs_json_path = os.path.join(script_dir, INPUT_JSON)
    abs_plot_path = os.path.join(script_dir, OUTPUT_PLOT)
    analyze_and_plot(abs_json_path, abs_plot_path)

