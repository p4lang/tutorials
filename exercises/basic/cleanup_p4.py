#!/usr/bin/env python3
import os
import subprocess
import re
import signal
import time

def find_process_using_port(port):
    """Find process ID using a specific port"""
    try:
        # Run netstat command to find processes using ports
        cmd = f"sudo netstat -tuln | grep :{port}"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        if result.stdout:
            print(f"Port {port} is in use.")
            
            # Find the process ID using lsof
            cmd = f"sudo lsof -i :{port} -t"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.stdout:
                pid = result.stdout.strip()
                return pid
    except Exception as e:
        print(f"Error finding process: {e}")
    
    return None

def kill_process(pid):
    """Kill a process by its process ID"""
    try:
        # Get process name for better logging
        cmd = f"ps -p {pid} -o comm="
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        process_name = result.stdout.strip() if result.stdout else "Unknown"
        
        print(f"Attempting to terminate process {pid} ({process_name})...")
        
        # Try to terminate gracefully first
        os.kill(int(pid), signal.SIGTERM)
        time.sleep(1)  # Give it a moment to shut down
        
        # Check if it's still running
        try:
            os.kill(int(pid), 0)  # Signal 0 is used to check if process exists
            print(f"Process {pid} did not terminate gracefully, using SIGKILL...")
            os.kill(int(pid), signal.SIGKILL)
        except OSError:
            print(f"Process {pid} terminated successfully.")
            return True
            
    except Exception as e:
        print(f"Error killing process: {e}")
    
    return False

def cleanup_p4_ports():
    """Clean up commonly used P4 ports"""
    # List of common P4 ports that might remain bound
    p4_ports = [50051, 50052, 50053, 50054, 50055, 50056, 50057, 50058, 50059, 50060,
                 50061, 50062, 50063,
                9090, 9091, 9092, 9093, 9094, 9095, 9096, 9097, 9098, 9099,]
    
    killed_processes = []
    
    for port in p4_ports:
        pid = find_process_using_port(port)
        if pid:
            if kill_process(pid):
                killed_processes.append((pid, port))
    
    return killed_processes

def clean_mininet():
    """Run Mininet cleanup command"""
    print("Cleaning up Mininet...")
    try:
        subprocess.run("sudo mn -c", shell=True, check=True)
        print("Mininet cleanup completed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Mininet cleanup failed: {e}")

def main():
    print("Starting P4 program cleanup...")
    
    # Kill processes using P4 ports
    killed_processes = cleanup_p4_ports()
    
    if killed_processes:
        print(f"\nKilled {len(killed_processes)} processes that were holding ports:")
        for pid, port in killed_processes:
            print(f"  - PID {pid} (Port {port})")
    else:
        print("No processes found holding P4 ports.")
    
    # Clean Mininet
    clean_mininet()
    
    print("\nCleanup completed. You should now be able to run your P4 program.")

if __name__ == "__main__":
    main()