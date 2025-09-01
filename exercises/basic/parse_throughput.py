#!/usr/bin/env python3

import os
import re
import csv
import sys
import pandas as pd

def extract_ip_from_string(text):
    """Extract IP addresses from a string."""
    ip_pattern = r'\b(?:\d{1,3}\.){3}\d{1,3}\b'
    ips = re.findall(ip_pattern, text)
    return ips

def load_flow_mapping(mapping_path):
    """Load the flow mapping information from CSV file."""
    if not os.path.exists(mapping_path):
        print(f"Warning: Flow mapping file {mapping_path} not found!")
        return {}
    
    # Dictionary for IP to host mapping
    ip_to_host = {}
    # Dictionary for IP to flow_id mapping
    ip_to_flow_id = {}
    # Dictionary for mapping source_ip to destination_ip
    source_to_dest = {}
    # Dictionary for storing flow sizes
    flow_id_to_size = {}
    
    try:
        # Read the flow mapping CSV file
        mapping_df = pd.read_csv(mapping_path)
        
        # Create mappings
        for _, row in mapping_df.iterrows():
            # Map source_ip to source (host ID)
            if 'source_ip' in mapping_df.columns and 'source' in mapping_df.columns:
                src_ip = row['source_ip']
                src_host = row['source']
                ip_to_host[src_ip] = src_host.replace('h', '')  # Remove 'h' prefix if present
            
            # Map destination_ip to destination (host ID)
            if 'destination_ip' in mapping_df.columns and 'destination' in mapping_df.columns:
                dst_ip = row['destination_ip']
                dst_host = row['destination']
                ip_to_host[dst_ip] = dst_host.replace('h', '')  # Remove 'h' prefix if present
            
            # Map IPs to flow_id
            if 'source_ip' in mapping_df.columns and 'destination_ip' in mapping_df.columns and 'flow_id' in mapping_df.columns:
                src_ip = row['source_ip']
                dst_ip = row['destination_ip']
                flow_id = row['flow_id']
                source_to_dest[src_ip] = dst_ip
                ip_to_flow_id[(src_ip, dst_ip)] = flow_id
            
            # Map flow_id to flow_size
            if 'flow_id' in mapping_df.columns and 'flow_size' in mapping_df.columns:
                flow_id = row['flow_id']
                flow_size = row['flow_size']
                flow_id_to_size[flow_id] = flow_size
                
        print(f"Loaded mappings for {len(ip_to_host)} hosts and {len(ip_to_flow_id)} flows")
    except Exception as e:
        print(f"Error loading flow mapping file: {e}")
    
    return ip_to_host, ip_to_flow_id, source_to_dest, flow_id_to_size

def verify_connection(source_ip, dest_ip, source_to_dest):
    """Verify if the connection between source and destination IP is valid based on mapping."""
    if source_ip in source_to_dest:
        expected_dest = source_to_dest[source_ip]
        if expected_dest == dest_ip:
            return True
        else:
            print(f"Warning: Unexpected destination IP for {source_ip}. Expected {expected_dest}, got {dest_ip}")
            return False
    return False  # No mapping available to verify

def parse_receiver_files(directory_path, ip_to_host=None, ip_to_flow_id=None, source_to_dest=None, flow_id_to_size=None):
    """Parse all receiver files and extract throughput information."""
    throughput_data = []
    
    # List all files in the directory
    files = [f for f in os.listdir(directory_path) if f.startswith('receiver_') and f.endswith('.txt')]
    
    print(f"Found {len(files)} receiver files to process.")
    
    for filename in files:
        file_path = os.path.join(directory_path, filename)
        
        # Extract the host ID from the filename (e.g., h616 from receiver_h616.txt)
        host_match = re.search(r'receiver_h(\d+)\.txt', filename)
        if host_match:
            dest_id = host_match.group(1)
        else:
            dest_id = "unknown"
        
        try:
            with open(file_path, 'r') as file:
                content = file.read()
                
                # Extract the local and remote IPs
                connection_line = None
                for line in content.split('\n'):
                    if "local" in line and "connected with" in line:
                        connection_line = line
                        break
                
                if not connection_line:
                    print(f"Couldn't find connection line in {filename}")
                    continue
                    
                ips = extract_ip_from_string(connection_line)
                if len(ips) < 2:
                    print(f"Couldn't extract IPs from connection line in {filename}")
                    continue
                    
                local_ip = ips[0]  # Receiver IP
                remote_ip = ips[1]  # Sender IP
                
                # Get source ID from mapping file if available
                if ip_to_host and remote_ip in ip_to_host:
                    source_id = ip_to_host[remote_ip]
                else:
                    # Fallback: Extract from hostname or IP
                    ip_parts = remote_ip.split('.')
                    if len(ip_parts) == 4:
                        source_id = ip_parts[2]  # Using the third octet as host identifier
                        print(f"Warning: Using fallback ID extraction for {remote_ip} -> {source_id}")
                    else:
                        source_id = "unknown"
                        print(f"Warning: Could not determine source ID for {remote_ip}")
                
                # Verify the connection
                connection_verified = verify_connection(remote_ip, local_ip, source_to_dest)
                if not connection_verified:
                    print(f"Note: Connection from {remote_ip} to {local_ip} not found in mapping file")
                
                # Get flow_id from mapping
                flow_id = None
                if ip_to_flow_id and (remote_ip, local_ip) in ip_to_flow_id:
                    flow_id = ip_to_flow_id[(remote_ip, local_ip)]
                
                # Extract bandwidth information
                bandwidth_line = None
                for line in content.split('\n'):
                    if "sec" in line and "Bytes" in line and "bits/sec" in line:
                        bandwidth_line = line
                        break
                
                if not bandwidth_line:
                    print(f"Couldn't find bandwidth line in {filename}")
                    continue
                
                # Parse the bandwidth line which looks like:
                # [  1] 0.0000-0.5362 sec   130 KBytes  1.98 Mbits/sec
                parts = bandwidth_line.strip().split()
                
                # Find the interval
                interval_str = None
                for i, part in enumerate(parts):
                    if "sec" in part and "-" in parts[i-1]:
                        interval_str = parts[i-1]
                        break
                
                if not interval_str:
                    print(f"Couldn't parse interval in {filename}")
                    continue
                
                try:
                    # Extract start and end times
                    start_time, end_time = map(float, interval_str.split('-'))
                    duration = end_time - start_time
                    
                    # Find transfer amount
                    transfer_value = None
                    transfer_unit = None
                    for i, part in enumerate(parts):
                        if part in ["Bytes", "KBytes", "MBytes", "GBytes"] and i > 0:
                            transfer_value = float(parts[i-1])
                            transfer_unit = part
                            break
                    
                    if not transfer_value:
                        print(f"Couldn't parse transfer amount in {filename}")
                        continue
                    
                    # Convert transfer to bytes
                    flow_size = transfer_value
                    if transfer_unit == "KBytes":
                        flow_size = transfer_value * 1024
                    elif transfer_unit == "MBytes":
                        flow_size = transfer_value * 1024 * 1024
                    elif transfer_unit == "GBytes":
                        flow_size = transfer_value * 1024 * 1024 * 1024
                    
                    # Find bandwidth
                    bandwidth_value = None
                    bandwidth_unit = None
                    for i, part in enumerate(parts):
                        if "bits/sec" in part and i > 0:
                            bandwidth_value = float(parts[i-1])
                            bandwidth_unit = part
                            break
                    
                    if not bandwidth_value:
                        print(f"Couldn't parse bandwidth in {filename}")
                        continue
                    
                    # Convert bandwidth to Mbits/sec
                    if "Kbits/sec" in bandwidth_unit:
                        bandwidth_value /= 1000.0
                    elif "Gbits/sec" in bandwidth_unit:
                        bandwidth_value *= 1000.0
                    
                    # Get expected flow size from mapping if available
                    expected_flow_size = None
                    if flow_id and flow_id in flow_id_to_size:
                        expected_flow_size = flow_id_to_size[flow_id]
                    
                    # Add to the throughput data
                    throughput_data.append({
                        'flow_id': flow_id if flow_id else "unknown",
                        'source_id': source_id,
                        'dest_id': dest_id,
                        'source_ip': remote_ip,
                        'dest_ip': local_ip,
                        'throughput_mbps': bandwidth_value,
                        'flow_size_bytes': flow_size,
                        'expected_flow_size': expected_flow_size,
                        'duration': duration
                    })
                    print(f"Successfully parsed {filename}: Flow ID {flow_id}, {source_id} -> {dest_id}, {bandwidth_value} Mbps")
                except Exception as e:
                    print(f"Error parsing values from {filename}: {e}")
        except Exception as e:
            print(f"Error reading file {filename}: {e}")
    
    return throughput_data

def save_to_csv(data, output_path):
    """Save the extracted data to a CSV file."""
    if not data:
        print("No throughput data to save!")
        return
        
    fieldnames = ['flow_id', 'source_id', 'dest_id', 'source_ip', 'dest_ip', 
                  'throughput_mbps', 'flow_size_bytes', 'expected_flow_size', 'duration']
    
    with open(output_path, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(data)
    
    print(f"CSV file saved to {output_path} with {len(data)} records")

def main():
    # Directory containing the receiver files
    directory_path = '/home/nwlab/p4/tutorials/exercises/basic/outputs'
    
    # Path to flow mapping file (try several potential locations)
    mapping_paths = [
        '/home/nwlab/p4/tutorials/exercises/basic/flow_mapping_info.csv',
        '/home/nwlab/p4/tutorials/exercises/basic/flow_mapping.csv',
        '/home/nwlab/p4/tutorials/exercises/basic/host_mapping.csv',
        '/home/nwlab/p4/tutorials/exercises/basic/outputs/flow_mapping.csv'
    ]
    
    # Try to find the mapping file
    ip_to_host = {}
    ip_to_flow_id = {}
    source_to_dest = {}
    flow_id_to_size = {}
    
    for mapping_path in mapping_paths:
        if os.path.exists(mapping_path):
            print(f"Found mapping file at: {mapping_path}")
            ip_to_host, ip_to_flow_id, source_to_dest, flow_id_to_size = load_flow_mapping(mapping_path)
            if ip_to_host or ip_to_flow_id:
                break
    
    # Allow providing a different directory via command line
    if len(sys.argv) > 1:
        directory_path = sys.argv[1]
        
    # Allow specifying a custom mapping file
    if len(sys.argv) > 2:
        mapping_path = sys.argv[2]
        ip_to_host, ip_to_flow_id, source_to_dest, flow_id_to_size = load_flow_mapping(mapping_path)
    
    # Output CSV file path
    output_csv_path = '/home/nwlab/p4/tutorials/exercises/basic/throughput_data.csv'
    
    print(f"Parsing receiver files from: {directory_path}")
    throughput_data = parse_receiver_files(directory_path, ip_to_host, ip_to_flow_id, source_to_dest, flow_id_to_size)
    print(f"Extracted throughput data for {len(throughput_data)} connections")
    
    save_to_csv(throughput_data, output_csv_path)

if __name__ == "__main__":
    main()