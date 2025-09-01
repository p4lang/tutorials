#!/usr/bin/env python3
import os
import re
import csv
import glob
import json
import datetime
from collections import defaultdict

def parse_iperf_output(file_path, is_sender=True):
    """
    Parse iperf output files to extract flow information.
    Returns a dictionary with flow details.
    """
    flow_data = {}
    
    # Determine if this is a sender or receiver file
    flow_role = "sender" if is_sender else "receiver"
    
    # Extract host information from filename
    filename = os.path.basename(file_path)
    host_match = re.search(r'(sender|receiver)_([a-zA-Z0-9]+)\.(?:txt|json)', filename)
    if host_match:
        flow_data['host'] = host_match.group(2)
    else:
        flow_data['host'] = "unknown"
    
    flow_data['role'] = flow_role
    
    # Default values
    flow_data['start_time'] = None
    flow_data['end_time'] = None
    flow_data['duration'] = None
    flow_data['transferred'] = None
    flow_data['bandwidth'] = None
    flow_data['peer_address'] = None
    flow_data['peer_port'] = None
    flow_data['local_address'] = None
    flow_data['local_port'] = None
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            
            # Extract connection info using a more flexible regex
            if is_sender:
                # For sender files
                server_match = re.search(r'Client connecting to ([0-9.]+), TCP port (\d+)', content)
                if server_match:
                    flow_data['peer_address'] = server_match.group(1)
                    flow_data['peer_port'] = server_match.group(2)
                
                # Also try to extract local connection info
                local_match = re.search(r'local ([0-9.]+) port (\d+) connected with ([0-9.]+) port (\d+)', content)
                if local_match:
                    flow_data['local_address'] = local_match.group(1)
                    flow_data['local_port'] = local_match.group(2)
                    # Double-check peer address
                    if not flow_data['peer_address']:
                        flow_data['peer_address'] = local_match.group(3)
                    if not flow_data['peer_port']:
                        flow_data['peer_port'] = local_match.group(4)
            else:
                # For receiver files
                conn_match = re.search(r'local ([0-9.]+) port (\d+) connected with ([0-9.]+) port (\d+)', content)
                if conn_match:
                    flow_data['local_address'] = conn_match.group(1)
                    flow_data['local_port'] = conn_match.group(2)
                    flow_data['peer_address'] = conn_match.group(3)
                    flow_data['peer_port'] = conn_match.group(4)
                else:
                    # Try alternative receiver format
                    server_match = re.search(r'Server listening on .* port (\d+)', content)
                    client_match = re.search(r'Client connecting from ([0-9.]+), port (\d+)', content)
                    if server_match:
                        flow_data['local_port'] = server_match.group(1)
                    if client_match:
                        flow_data['peer_address'] = client_match.group(1)
                        flow_data['peer_port'] = client_match.group(2)
            
            # Extract transfer and bandwidth from the last line with data
            lines = content.strip().split('\n')
            for line in reversed(lines):
                # Skip empty lines
                if not line.strip():
                    continue
                
                # Look for lines with transfer data
                # Format example: [  1] 0.0000-1.1695 sec  3.18 MBytes  22.8 Mbits/sec
                if 'sec' in line and ('bits/sec' in line or 'Bytes' in line):
                    parts = line.split()
                    
                    # Try to extract interval
                    interval_match = re.search(r'(\d+\.\d+)-(\d+\.\d+) sec', line)
                    if interval_match:
                        start_sec = float(interval_match.group(1))
                        end_sec = float(interval_match.group(2))
                        flow_data['duration'] = end_sec - start_sec
                    
                    # Extract transfer - look for value followed by [KMG]Bytes
                    transfer_idx = -1
                    for i, part in enumerate(parts):
                        if 'Bytes' in part and i > 0:
                            transfer_idx = i - 1
                            break
                    
                    if transfer_idx >= 0:
                        amount = float(parts[transfer_idx])
                        unit = 'M' if 'MBytes' in parts[transfer_idx + 1] else \
                               'K' if 'KBytes' in parts[transfer_idx + 1] else \
                               'G' if 'GBytes' in parts[transfer_idx + 1] else ''
                        
                        # Convert to bytes
                        if unit == 'K':
                            amount *= 1024
                        elif unit == 'M':
                            amount *= 1024*1024
                        elif unit == 'G':
                            amount *= 1024*1024*1024
                        
                        flow_data['transferred'] = amount
                    
                    # Extract bandwidth - look for value followed by [KMG]bits/sec
                    bw_idx = -1
                    for i, part in enumerate(parts):
                        if 'bits/sec' in part and i > 0:
                            bw_idx = i - 1
                            break
                    
                    if bw_idx >= 0:
                        bw = float(parts[bw_idx])
                        unit = 'M' if 'Mbits/sec' in parts[bw_idx + 1] else \
                               'K' if 'Kbits/sec' in parts[bw_idx + 1] else \
                               'G' if 'Gbits/sec' in parts[bw_idx + 1] else ''
                        
                        # Convert to bits/sec
                        if unit == 'K':
                            bw *= 1000
                        elif unit == 'M':
                            bw *= 1000*1000
                        elif unit == 'G':
                            bw *= 1000*1000*1000
                        
                        flow_data['bandwidth'] = bw
                    
                    break  # Found what we need
    
    except Exception as e:
        print(f"Error parsing {file_path}: {e}")
    
    return flow_data

def load_flow_mapping_info(file_path):
    """
    Load flow mapping information from the JSON file.
    Returns a dictionary with flow_id as key and flow details as value.
    """
    flow_map = {}
    try:
        with open(file_path, 'r') as f:
            flow_data = json.load(f)
            
            # Check if the data is in array format (new format)
            if isinstance(flow_data, list):
                for flow in flow_data:
                    flow_id = flow.get('flow_id')
                    if flow_id:
                        flow_map[flow_id] = {
                            'source': flow.get('source'),
                            'destination': flow.get('destination'),
                            'flow_size': flow.get('flow_size'),
                            'source_ip': flow.get('source_ip', ''),
                            'destination_ip': flow.get('destination_ip', '')
                        }
            # Check if it's in object format with keys like "h1->h3" (old format)
            elif isinstance(flow_data, dict):
                for key, flow_info in flow_data.items():
                    # Extract flow_id from the value
                    flow_id = flow_info.get('flow_id')
                    if flow_id:
                        # Try to parse source and destination from key (e.g., "h1->h3")
                        parts = key.split('->')
                        source = parts[0] if len(parts) > 0 else ''
                        destination = parts[1] if len(parts) > 1 else ''
                        
                        flow_map[flow_id] = {
                            'source': source,
                            'destination': destination,
                            'flow_size': flow_info.get('flow_size_bytes', 0),
                            'source_ip': '',
                            'destination_ip': ''
                        }
            
            print(f"Loaded {len(flow_map)} flows from {file_path}")
    except Exception as e:
        print(f"Error loading flow mapping data from {file_path}: {e}")
    
    return flow_map

def match_sender_receiver_files(sender_files, receiver_files, flow_mapping):
    """
    Match sender and receiver files based on flow mapping information.
    Returns a list of matched flows with their file paths.
    """
    matched_flows = []
    
    # Create dictionaries to quickly look up files by host name
    sender_dict = {}
    for file_path in sender_files:
        host_name = extract_host_from_filename(file_path)
        if host_name:
            sender_dict[host_name] = file_path
    
    receiver_dict = {}
    for file_path in receiver_files:
        host_name = extract_host_from_filename(file_path)
        if host_name:
            receiver_dict[host_name] = file_path
    
    # Match files based on flow mapping
    for flow_id, flow_info in flow_mapping.items():
        source = flow_info.get('source')
        destination = flow_info.get('destination')
        
        if source in sender_dict and destination in receiver_dict:
            matched_flows.append({
                'flow_id': flow_id,
                'source': source,
                'destination': destination,
                'flow_size': flow_info.get('flow_size', 0),
                'sender_file': sender_dict[source],
                'receiver_file': receiver_dict[destination],
                'source_ip': flow_info.get('source_ip', ''),
                'destination_ip': flow_info.get('destination_ip', '')
            })
    
    return matched_flows

def extract_host_from_filename(file_path):
    """
    Extract host name from file path like 'sender_h1.txt' or 'receiver_h3.txt'.
    """
    filename = os.path.basename(file_path)
    match = re.search(r'(sender|receiver)_([a-zA-Z0-9]+)\.(?:txt|json)', filename)
    if match:
        return match.group(2)
    return None

def analyze_flow(matched_flow):
    """
    Analyze a matched flow by parsing sender and receiver files.
    Returns a dictionary with analysis results.
    """
    result = {
        'flow_id': matched_flow['flow_id'],
        'sender': matched_flow['source'],
        'receiver': matched_flow['destination'],
        'flow_size': matched_flow['flow_size'],
        'source_ip': matched_flow['source_ip'],
        'destination_ip': matched_flow['destination_ip'],
        'total_sent': 0,
        'total_received': 0,
        'duration': 0,  # FCT in seconds
        'progress': 0,   # Percentage of flow completed
    }
    
    # Parse sender file
    sender_data = parse_iperf_output(matched_flow['sender_file'], is_sender=True)
    if sender_data and 'transferred' in sender_data:
        result['total_sent'] = sender_data['transferred']
        # We'll use sender duration only as a fallback
    
    # Parse receiver file
    receiver_data = parse_iperf_output(matched_flow['receiver_file'], is_sender=False)
    if receiver_data and 'transferred' in receiver_data:
        result['total_received'] = receiver_data['transferred']
        # Prioritize the receiver's duration as the flow completion time
        if 'duration' in receiver_data and receiver_data['duration']:
            result['duration'] = receiver_data['duration']
        # Only fall back to sender's duration if receiver's is not available
        elif not result['duration'] and sender_data and 'duration' in sender_data:
            result['duration'] = sender_data['duration']
            print(f"Warning: Using sender duration for flow {matched_flow['flow_id']} as receiver duration not available")
    
    # Calculate progress (percentage of flow completed)
    if result['flow_size'] > 0 and result['total_sent'] > 0:
        result['progress'] = (result['total_sent'] / result['flow_size']) * 100
    
    return result

def write_csv(flow_results, output_file):
    """
    Write flow analysis results to a CSV file.
    """
    fieldnames = [
        'flow_id', 'sender', 'receiver', 'flow_size', 
        'total_sent', 'total_received', 'duration', 'progress',
        'source_ip', 'destination_ip'  # Added these fields
    ]
    
    try:
        with open(output_file, 'w', newline='') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            
            for flow in flow_results:
                writer.writerow(flow)
        
        print(f"CSV file created successfully: {output_file}")
    except Exception as e:
        print(f"Error writing CSV file: {e}")
        # Try writing to current directory as fallback
        try:
            alt_output = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'flow_analysis.csv')
            with open(alt_output, 'w', newline='') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                writer.writeheader()
                
                for flow in flow_results:
                    writer.writerow(flow)
            print(f"CSV file created at alternative location: {alt_output}")
        except Exception as alt_e:
            print(f"Failed to write to alternative location: {alt_e}")

def find_iperf_files(output_dir):
    """
    Find iperf output files in the specified directory.
    If .txt files are not found, will try .json files.
    """
    sender_files = glob.glob(os.path.join(output_dir, 'sender_*.txt'))
    receiver_files = glob.glob(os.path.join(output_dir, 'receiver_*.txt'))
    
    # If no .txt files found, try .json files
    if not sender_files:
        json_sender_files = glob.glob(os.path.join(output_dir, 'sender_*.json'))
        if json_sender_files:
            print("Found .json sender files instead of .txt files")
            sender_files = json_sender_files
    
    if not receiver_files:
        json_receiver_files = glob.glob(os.path.join(output_dir, 'receiver_*.json'))
        if json_receiver_files:
            print("Found .json receiver files instead of .txt files")
            receiver_files = json_receiver_files
    
    return sender_files, receiver_files

def main():
    # Define the directory where iperf output files are stored
    base_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(base_dir, 'outputs')
    
    # Check if outputs directory exists
    if not os.path.exists(output_dir):
        print(f"Warning: Outputs directory {output_dir} does not exist.")
        # Try looking in current directory
        alt_output_dir = os.path.join(base_dir)
        print(f"Looking for iperf files in {alt_output_dir}")
        sender_files, receiver_files = find_iperf_files(alt_output_dir)
    else:
        # Find all iperf output files
        sender_files, receiver_files = find_iperf_files(output_dir)
    
    print(f"Found {len(sender_files)} sender files and {len(receiver_files)} receiver files")
    
    if not sender_files or not receiver_files:
        print("Warning: No iperf files found. Please check file paths.")
        return
    
    # Print found files for debugging
    print("Sender files:")
    for f in sender_files:
        print(f"  {f}")
    print("Receiver files:")
    for f in receiver_files:
        print(f"  {f}")
    
    # Load flow mapping information
    flow_mapping_path = os.path.join(base_dir, 'flow_mapping_info.json')
    flow_mapping = load_flow_mapping_info(flow_mapping_path)
    
    if not flow_mapping:
        print("Error: Could not load flow mapping information.")
        return
    
    # Match sender and receiver files based on flow mapping
    matched_flows = match_sender_receiver_files(sender_files, receiver_files, flow_mapping)
    
    if not matched_flows:
        print("Warning: No flows could be matched. Check flow mapping and file names.")
        return
    
    print(f"Successfully matched {len(matched_flows)} flows.")
    
    # Analyze each matched flow
    flow_results = []
    for matched_flow in matched_flows:
        result = analyze_flow(matched_flow)
        flow_results.append(result)
        
        # Print summary for this flow
        print(f"\nFlow {result['flow_id']}: {result['sender']} → {result['receiver']}")
        print(f"  Flow Size: {result['flow_size']} bytes")
        print(f"  Sent: {result['total_sent']} bytes")
        print(f"  Received: {result['total_received']} bytes")
        print(f"  Duration (FCT): {result['duration']:.4f} seconds")
        print(f"  Progress: {result['progress']:.2f}%")
    
    # Write results to CSV
    csv_path = os.path.join(output_dir, 'flow_analysis.csv')
    write_csv(flow_results, csv_path)

if __name__ == "__main__":
    main()