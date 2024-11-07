#!/bin/bash

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]
  then echo "Please run as root using sudo"
  exit
fi

# Create results directory
mkdir -p results

# Define arrays for delays, losses, and TCP variants
delays=(10ms 50ms 100ms)
losses=(0.1 0.5 1)
tcp_variants=(reno cubic)

# Number of runs per experiment
runs=20

# Create the 20 MB file if it doesn't exist
if [ ! -f 20MB_file.txt ]; then
  echo "Creating 20 MB test file..."
  dd if=/dev/zero of=20MB_file.txt bs=1M count=20
fi

# Set MTU to 1500 bytes
echo "Setting MTU of loopback interface to 1500 bytes..."
ifconfig lo mtu 1500

# Loop through all combinations
for delay in "${delays[@]}"; do
  for loss in "${losses[@]}"; do
    for tcp_variant in "${tcp_variants[@]}"; do
      echo "=============================================="
      echo "Running experiment with Delay=$delay, Loss=$loss%, TCP Variant=$tcp_variant"
      echo "=============================================="

      # Clear existing tc rules
      echo "Clearing existing tc rules..."
      tc qdisc del dev lo root 2> /dev/null

      # Set tc rules with adjusted r2q, quantum, and burst to suppress warnings
      echo "Applying tc rules..."
      tc qdisc add dev lo root handle 1: htb default 12 r2q 1
      tc class add dev lo parent 1: classid 1:1 htb rate 100mbit quantum 1500 
      tc class add dev lo parent 1:1 classid 1:12 htb rate 100mbit quantum 1500 
      tc qdisc add dev lo parent 1:12 handle 10: netem delay $delay loss ${loss}%

      # Display tc qdisc settings
      echo "Current tc qdisc configuration:"
      tc qdisc show dev lo

      # Set TCP variant
      echo "Setting TCP congestion control algorithm to $tcp_variant..."
      sysctl -w net.ipv4.tcp_congestion_control=$tcp_variant

      # Confirm TCP variant
      echo -n "Current TCP congestion control algorithm: "
      cat /proc/sys/net/ipv4/tcp_congestion_control

      # Create a result file
      result_file="results/${tcp_variant}_delay_${delay}_loss_${loss}.txt"
      echo "Throughput Results for TCP Variant: $tcp_variant, Delay: $delay, Loss: $loss%" > $result_file

      # Run the experiments
      for ((i=1; i<=runs; i++)); do
        echo "Run $i of $runs"

        # Start iperf server in the background
        iperf3 -s -1 > /dev/null &
        server_pid=$!

        # Give the server a moment to start
        sleep 1

        # Run iperf client and capture the throughput in JSON format
        output=$(iperf3 -J -c 127.0.0.1 -F 20MB_file.txt)

        # Extract the sender's bits per second
        throughput_bits=$(echo "$output" | jq '.end.sum_sent.bits_per_second')

        # Convert bits per second to Mbits/sec
        throughput_mbps=$(echo "scale=2; $throughput_bits / 1000000" | bc)

        # Log the throughput
        echo "Run $i: $throughput_mbps Mbits/sec" | tee -a $result_file

        # Display any errors
        if echo "$output" | grep -q "error"; then
          echo "Error during iperf3 transfer:"
          echo "$output"
        fi

        # Ensure the server has terminated
        wait $server_pid

        # Optional: Add a short delay between runs
        sleep 1
      done

      # Reset tc rules
      echo "Resetting tc rules..."
      tc qdisc del dev lo root

      echo "Experiment with Delay=$delay, Loss=$loss%, TCP Variant=$tcp_variant completed."
    done
  done
done

# Reset MTU to default (optional)
echo "Resetting MTU of loopback interface to default..."
ifconfig lo mtu 65536

# Reset TCP variant to default (optional)
echo "Resetting TCP congestion control algorithm to cubic..."
sysctl -w net.ipv4.tcp_congestion_control=cubic

echo "All experiments completed."
