#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Reason-GPL: import-scapy

import argparse
import socket
from time import sleep
import random
import time  # Added for time.time() if needed, though not directly used in the final UDP logic

from scapy.all import IP, TCP, UDP, Ether, Raw, get_if_hwaddr, get_if_list, sendp


def get_if():
    iface = None
    for i in get_if_list():
        if "eth0" in i:
            iface = i
            break
    if not iface:
        print("Cannot find eth0 interface")
        exit(1)
    return iface


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--p", help="Protocol name To send TCP/UDP etc packets", type=str, required=True)
    parser.add_argument("--des", help="IP address of the destination", type=str, required=True)
    parser.add_argument("--tos", help="Type of Service value for IP header (integer)", type=int, required=True)
    parser.add_argument("--dur", help="Duration in seconds to send packets", type=str, required=True)  # Kept as string for try-except int conversion
    args = parser.parse_args()

    duration_seconds = 0
    try:
        duration_seconds = int(args.dur)
        if duration_seconds <= 0:
            print("Error: Duration must be a positive integer.")
            return
    except ValueError:
        print("Error: Duration must be a valid integer.")
        return

    addr = socket.gethostbyname(args.des)
    iface = get_if()

    if args.p == 'UDP':
        TARGET_TOTAL_PACKET_SIZE_BYTES = 128  # Define fixed total packet size
        DEFAULT_PAYLOAD_CONTENT = "DefaultPayload"  # Define a default payload

        print(f"Configuring for fixed UDP packet size: {TARGET_TOTAL_PACKET_SIZE_BYTES} bytes with ToS: {args.tos}.")
        print(f"Using default payload content: '{DEFAULT_PAYLOAD_CONTENT}'")

        fixed_sport = random.randint(49152, 65535)
        pkt_header = Ether(src=get_if_hwaddr(iface), dst="ff:ff:ff:ff:ff:ff") / \
                     IP(dst=addr, tos=args.tos) / \
                     UDP(dport=4321, sport=fixed_sport)

        header_actual_size = len(pkt_header)
        desired_payload_size = TARGET_TOTAL_PACKET_SIZE_BYTES - header_actual_size

        if desired_payload_size < 0:
            print(f"Error: Target packet size {TARGET_TOTAL_PACKET_SIZE_BYTES} bytes is too small "
                  f"for headers ({header_actual_size} bytes) and ToS field. Minimum target size: {header_actual_size + 1}.")
            return

        default_payload_bytes = DEFAULT_PAYLOAD_CONTENT.encode('utf-8')
        current_payload_len = len(default_payload_bytes)

        if current_payload_len < desired_payload_size:
            padding = b'\x00' * (desired_payload_size - current_payload_len)
            final_payload_bytes = default_payload_bytes + padding
            print(f"  Default payload (UTF-8 encoded: {current_payload_len} bytes) padded to {desired_payload_size} bytes.")
        elif current_payload_len > desired_payload_size:
            final_payload_bytes = default_payload_bytes[:desired_payload_size]
            print(f"  Default payload (UTF-8 encoded: {current_payload_len} bytes) truncated to {desired_payload_size} bytes.")
        else:
            final_payload_bytes = default_payload_bytes
            print(f"  Default payload (UTF-8 encoded: {current_payload_len} bytes) fits desired payload size {desired_payload_size} bytes exactly.")
        
        pkt_template = pkt_header / Raw(final_payload_bytes)
        
        packet_size_bytes = len(pkt_template) 
        
        if packet_size_bytes != TARGET_TOTAL_PACKET_SIZE_BYTES:
             print(f"Warning: Actual packet size {packet_size_bytes} does not match target {TARGET_TOTAL_PACKET_SIZE_BYTES}. Check logic.")
        
        packet_size_bits = packet_size_bytes * 8
        
        target_rate_gbps = 0.1  # MODIFIED: Reduced target data rate
        target_rate_bps = target_rate_gbps * 1e9

        if packet_size_bits == 0:
            print("Error: Packet size in bits is zero, cannot calculate packets per second.")
            return
        num_packets_per_second_ideal = target_rate_bps / packet_size_bits
        interval_between_packets = 1.0 / num_packets_per_second_ideal
        
        estimated_total_packets = int(round(num_packets_per_second_ideal * duration_seconds))

        if estimated_total_packets <= 0 and duration_seconds > 0:
             print(f"Warning: With the current settings (rate: {target_rate_gbps} Gbps, packet size: {packet_size_bytes} bytes), "
                   f"the estimated number of packets for {duration_seconds}s is {estimated_total_packets}. "
                   f"This might result in very few or no packets being sent if the interval is too large.")

        print(f"Preparing to send UDP packets to {args.des} ({addr}) via {iface}:")
        print(f"  IP ToS value: {args.tos}.")
        print(f"  Targeting data rate: ~{target_rate_gbps} Gbps.")
        print(f"  Effective payload size (after padding/truncation of default content): {desired_payload_size} bytes.")
        print(f"  Total fixed packet size (on wire): {packet_size_bytes} bytes ({packet_size_bits} bits).")
        print(f"  Calculated ideal packets per second: {num_packets_per_second_ideal:.2f} PPS.")
        print(f"  Targeting inter-packet interval: {interval_between_packets:.9f} seconds.")
        print(f"  Estimated packets to send over {duration_seconds} seconds: {estimated_total_packets}.")
        print(f"  Packet structure summary:")
        pkt_template.show2()
        
        print(f"\nStarting UDP transmission for {duration_seconds} seconds...")

        start_time = time.time()
        end_time = start_time + duration_seconds
        packets_sent_count = 0
        next_send_time = start_time

        try:
            while time.time() < end_time:
                current_loop_entry_time = time.time()
                
                wait_time = next_send_time - current_loop_entry_time
                if wait_time > 0:
                    time.sleep(wait_time)
                
                if time.time() >= end_time:
                    break

                sendp(pkt_template, iface=iface, verbose=False)
                packets_sent_count += 1
                
                next_send_time += interval_between_packets
                                
        except KeyboardInterrupt:
            print("\nUDP transmission interrupted by user.")
        except Exception as e:
            print(f"An error occurred during UDP transmission: {e}")
        finally:
            actual_run_duration = time.time() - start_time
            print(f"Finished UDP transmission.")
            print(f"  Target duration: {duration_seconds:.2f} seconds.")
            print(f"  Actual run duration: {actual_run_duration:.2f} seconds.")
            print(f"  Packets sent: {packets_sent_count}.")
            if actual_run_duration > 0 and packets_sent_count > 0:
                achieved_bps = (packets_sent_count * packet_size_bits) / actual_run_duration
                achieved_gbps = achieved_bps / 1e9
                print(f"  Achieved data rate: {achieved_gbps:.3f} Gbps ({achieved_bps / 1e6:.2f} Mbps).")
            elif packets_sent_count == 0:
                print("  No packets were sent.")

    elif args.p == 'TCP':
        DEFAULT_TCP_PAYLOAD = "DefaultTCPPayload"
        print(f"Configuring TCP packet with ToS: {args.tos} and default payload: '{DEFAULT_TCP_PAYLOAD}'.")

        pkt = Ether(src=get_if_hwaddr(iface), dst="ff:ff:ff:ff:ff:ff") / \
              IP(dst=addr, tos=args.tos) / \
              TCP() / \
              DEFAULT_TCP_PAYLOAD
        pkt.show2()
        try:
            print(f"Starting TCP transmission for {duration_seconds} seconds (1 packet per second)...")
            for i in range(duration_seconds):
                sendp(pkt, iface=iface, verbose=False)
                sleep(1)
            print(f"Finished sending {duration_seconds} TCP packets.")
        except KeyboardInterrupt:
            print("\nTCP transmission interrupted by user.")
        except Exception as e:
            print(f"An error occurred during TCP transmission: {e}")
    else:
        print(f"Error: Protocol '{args.p}' not supported. Please use 'UDP' or 'TCP'.")


if __name__ == '__main__':
    main()
