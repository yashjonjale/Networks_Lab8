#!/bin/bash

# run_experiments.sh
# Automates Lab 8 experiments comparing TCP variants using iperf and Wireshark
# Includes packet capturing with dumpcap

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit
fi

# Variables
LOOPBACK_IF="lo"
IPERF_PORT=5001
FILE_SIZE="20M"
RESULTS_FILE="results.csv"
PCAP_DIR="pcap_files"

# TCP variants
TCP_VARIANTS=("reno" "cubic")

# Delays in ms
DELAYS=(10 50 100)
# DELAYS=(10)

# Loss rates in percentage
LOSSES=(0.1 0.5 1)
# LOSSES=(0.1)
# Number of runs per experiment
RUNS=8

# Network parameters
MTU_SIZE=1500
BANDWIDTH="100mbit"
BURST="32kbit"

# Initialize results file
echo "TCP_Variant,Delay(ms),Loss(%),Run,Throughput(Mbps)" > $RESULTS_FILE

# Create PCAP directory if it doesn't exist
mkdir -p $PCAP_DIR

# Function to reset tc settings
reset_tc() {
    echo "Resetting tc settings..."
    tc qdisc del dev $LOOPBACK_IF root 2>/dev/null
}

# Function to set MTU
set_mtu() {
    local mtu=$1
    if [ "$mtu" -eq "65536" ]; then
        echo "Resetting MTU to default (65536)"
    else
        echo "Setting MTU to $mtu on $LOOPBACK_IF"
    fi
    ifconfig $LOOPBACK_IF mtu $mtu
}

# Function to set TCP variant
set_tcp_variant() {
    local variant=$1
    echo "Setting TCP congestion control to $variant"
    sysctl -w net.ipv4.tcp_congestion_control=$variant
}


set_tc() {
    # Check if the correct number of arguments is provided
    if [ "$#" -ne 2 ]; then
        echo "Usage: set_tc <delay(ms)> <loss(%)> <bandwidth(mbit)> <burst(k)>"
        return 1
    fi

    local delay=$1
    local loss=$2
    local IFACE="lo"

    echo "Configuring tc with Delay=${delay}ms, Loss=${loss}%, Bandwidth=${bandwidth}mbit, and Burst=${burst}k on interface ${IFACE}"

    sudo tc qdisc del dev lo root 2> /dev/null
    sudo tc qdisc add dev lo root handle 1: htb default 12 r2q 1
    sudo tc class add dev lo parent 1: classid 1:1 htb rate 100mbit quantum 1500 burst 32k
    sudo tc class add dev lo parent 1:1 classid 1:12 htb rate 100mbit quantum 1500 burst 32k
    sudo tc qdisc add dev lo parent 1:12 handle 10: netem delay ${delay}ms loss $loss%
    echo "Current tc qdisc configuration on ${IFACE}:"
    sudo tc qdisc show dev "$IFACE"
}



# Function to extract throughput from iperf3 JSON output
extract_throughput() {
    # Using jq to parse iperf3 JSON output
    local throughput=$(echo "$1" | jq '.end.sum_received.bits_per_second')
    # Convert bits/sec to Mbps
    local throughput_mbps=$(echo "scale=2; $throughput/1000000" | bc)
    echo $throughput_mbps
}

# Function to run a single iperf3 experiment with packet capture
run_iperf_with_capture() {
    local tcp_variant=$1
    local delay=$2
    local loss=$3
    local run_number=$4

    # Define PCAP file name
    local pcap_file="${PCAP_DIR}/tcp_${tcp_variant}_delay_${delay}ms_loss_${loss}%_run_${run_number}.pcap"

    # echo "Starting packet capture: $pcap_file"

    # Start dumpcap in the background
    dumpcap -i $LOOPBACK_IF -w "$pcap_file" -f "tcp port $IPERF_PORT" > /dev/null 2>&1 &
    DUMPCAP_PID=$!

    # Ensure dumpcap started successfully
    if ! kill -0 $DUMPCAP_PID 2>/dev/null; then
        echo "Failed to start dumpcap. Aborting run."
        exit 1
    fi

    # Start iperf3 server
    iperf3 -s -p $IPERF_PORT > /dev/null 2>&1 &
    SERVER_PID=$!

    # Give the server a moment to start
    sleep 1

    # Run iperf3 client and capture JSON output
    CLIENT_OUTPUT=$(iperf3 -c 127.0.0.1 -p $IPERF_PORT -n $FILE_SIZE -J)

    # Extract throughput
    THROUGHPUT=$(extract_throughput "$CLIENT_OUTPUT")

    # Kill the iperf3 server
    kill $SERVER_PID
    wait $SERVER_PID 2>/dev/null

    # Stop dumpcap
    kill $DUMPCAP_PID
    wait $DUMPCAP_PID 2>/dev/null

    # echo "Throughput: $THROUGHPUT Mbps"
    echo "$THROUGHPUT"
}

# Install dependencies if not present
command -v iperf3 >/dev/null 2>&1 || { echo "iperf3 is required but not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required for JSON parsing but not installed. Installing..."; apt-get update && apt-get install -y jq; }
command -v dumpcap >/dev/null 2>&1 || { echo "dumpcap is required but not installed. Installing Wireshark-common..."; apt-get update && apt-get install -y wireshark-common; }

# Set MTU to 1500 bytes
set_mtu $MTU_SIZE

# Iterate over TCP variants
for tcp in "${TCP_VARIANTS[@]}"; do
    echo "Setting TCP variant to $tcp"
    set_tcp_variant $tcp

    # Iterate over Delays
    for delay in "${DELAYS[@]}"; do

        # Iterate over Loss rates
        for loss in "${LOSSES[@]}"; do

            echo "Running experiments for TCP=$tcp, Delay=${delay}ms, Loss=${loss}%"

            # Reset tc settings
            reset_tc

            # Set new tc parameters
            set_tc $delay $loss

            # Run experiments RUNS times
            for run in $(seq 1 $RUNS); do
                echo "Run $run/$RUNS for TCP=$tcp, Delay=${delay}ms, Loss=${loss}%"

                # Run iperf with packet capture and get throughput
                throughput=$(run_iperf_with_capture $tcp $delay $loss $run)

                # Append to results file
                echo "$tcp,$delay,$loss,$run,$throughput" >> $RESULTS_FILE

                # Optional: Wait a bit between runs
                sleep 1
            done

            # Reset tc after each combination
            reset_tc
        done
    done
done

# Reset tc and MTU to default
reset_tc
set_mtu 65536  # Default MTU for loopback is typically very large

echo "All experiments completed. Generating plots..."

# Call the Python script to generate plots
python3 plot_results.py $RESULTS_FILE

echo "Plots generated successfully."
