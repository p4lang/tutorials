#!/usr/bin/env python3

import json
import csv
import os

def convert_json_to_csv(json_file, csv_file):
    """Convert the flow mapping JSON file to CSV format."""
    try:
        # Read the JSON file
        with open(json_file, 'r') as f:
            data = json.load(f)
        
        # Write to CSV
        with open(csv_file, 'w', newline='') as csvfile:
            fieldnames = ['source', 'source_ip', 'destination', 'destination_ip', 'flow_id', 'flow_size']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(data)
        
        print(f"Successfully converted {json_file} to {csv_file}")
        return True
    except Exception as e:
        print(f"Error converting JSON to CSV: {e}")
        return False

if __name__ == "__main__":
    json_file = 'flow_mapping_info.json'
    csv_file = 'flow_mapping_info.csv'
    convert_json_to_csv(json_file, csv_file)