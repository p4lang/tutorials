from time import sleep
import os

def sending_function(self):
    # First, ensure the outputs directory exists
    output_dir = './outputs'
    os.makedirs(output_dir, exist_ok=True)
    print(f"Ensured output directory exists: {output_dir}")

    # Get hosts
    h1,h2,h3,h4,h5,h6,h7,h8 = self.net.get('h1','h2', 'h3', 'h4', 'h5', 'h6', 'h7', 'h8')
    hosts = [h1, h2, h3, h4, h5, h6, h7, h8]
    print(f"Got hosts: {[h.name for h in hosts]}")

    # Define server-client pairs and parameters
    flows = [
        {'sender': h1, 'receiver': h5, 'duration': 25, 'priority': 8, 'delay': 0},
        {'sender': h2, 'receiver': h6, 'duration': 20, 'priority': 4, 'delay': 5},
        {'sender': h3, 'receiver': h7, 'duration': 15, 'priority': 2, 'delay': 5},
        {'sender': h4, 'receiver': h8, 'duration': 5, 'priority': 0, 'delay': 5},
    ]

    # Define log file paths
    server_logs = {}
    client_logs = {}
    for flow in flows:
        rec_name = flow['receiver'].name
        send_name = flow['sender'].name
        server_logs[rec_name] = os.path.join(output_dir, f"{rec_name}_server.json")
        client_logs[send_name] = os.path.join(output_dir, f"{send_name}_client.json")

    # Start receivers (servers)
    print("\nStarting iperf3 servers...")
    for flow in flows:
        receiver = flow['receiver']
        log_path = server_logs[receiver.name]
        cmd = f'iperf3 -s --json -i 1 > {log_path} &'
        print(f" {receiver.name}: {cmd}")
        receiver.cmd(cmd)

    print("Servers starting in background. Waiting 5s...")
    sleep(5)

    # Start senders (clients) with delays
    print("\nStarting iperf3 clients sequentially...")
    current_wait = 0
    total_elapsed_time = 0
    flow_start_times = {}

    for i, flow in enumerate(flows):
        sender = flow['sender']
        receiver = flow['receiver']
        duration = flow['duration']
        priority = flow['priority']
        delay = flow['delay']
        client_log_path = client_logs[sender.name]

        if i > 0:
            print(f"Waiting {delay}s before starting next flow...")
            sleep(delay)
            total_elapsed_time += delay

        flow_start_times[sender.name] = total_elapsed_time
        print(f"Starting flow {i+1} ({sender.name}->{receiver.name}) at T={total_elapsed_time}s")
        cmd = (f'iperf3 -c {receiver.IP()} -u -b 10M -t {duration} '
               f'-S {priority} --json > {client_log_path} &')
        print(f" {sender.name}: {cmd}")
        sender.cmd(cmd)

    max_end_time = 0
    for flow in flows:
        start_time = flow_start_times[flow['sender'].name]
        end_time = start_time + flow['duration']
        max_end_time = max(max_end_time, end_time)
        print(f" Flow {flow['sender'].name}->{flow['receiver'].name}: Starts {start_time}s, Duration {flow['duration']}s, Ends {end_time}s")

    remaining_wait = max(0, max_end_time - total_elapsed_time) + 15

    print(f"\nAll flows started. Max end time is {max_end_time}s.")
    print(f"Current elapsed time: {total_elapsed_time}s.")
    print(f"Waiting an additional {remaining_wait}s for all flows to complete...")
    sleep(remaining_wait)

    print("\niperf tests should be complete.")

    print("Cleaning up iperf3 server processes...")
    # for flow in flows:
    #     flow['receiver'].cmd('killall -q iperf3')

    print("\nScript finished.")
