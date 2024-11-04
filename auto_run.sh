# Simulation setup
file_20mb_name="bigfile.txt"
num_runs=1
# delays=(10 50 100)  # in ms
# losses=(0.1 0.5 1)  # in %
# variants=("Reno" "Cubic")  # TCP variants

delays=(10)  # in ms
losses=(0.1)  # in %
variants=("reno")  # TCP variants

# Set MTU size on loopback interface to 1500B
sudo ifconfig lo mtu 1500

# Create CSV files to store results
echo "delay,loss,run,throughput" > reno_file.csv
echo "delay,loss,run,throughput" > cubic_file.csv

# Loop through each combination of delay, loss, and TCP variant
for delay in "${delays[@]}"; do
    for loss in "${losses[@]}"; do
        for variant in "${variants[@]}"; do
            # Set TCP variant
            sudo sysctl -w net.ipv4.tcp_congestion_control=$variant

            # Run experiments
            for run in $(seq 1 $num_runs); do
                # Reset loopback interface parameters
                echo "resetting loopback interface"
                sudo tc qdisc del dev lo root
                echo "Setting loopback interface parameters"
                # Set new loopback parameters (delay, loss, rate, and burst)
                sudo tc qdisc add dev lo parent 1: handle 10: tbf rate 100mbit burst 32kbit latency 50ms
                sudo tc qdisc add dev lo root handle 1: netem delay ${delay}ms loss ${loss}%

                # Define the filename for the Wireshark pcap file
                pcap_filename="/tmp/pcap_${variant}_delay${delay}_loss${loss}_run${run}.pcap"
                # Start Wireshark capture in background, saving output to pcap file
                sudo dumpcap -i lo -w $pcap_filename -a duration:10 &  # Capture for 10 seconds
                dumpcap_pid=$!
                echo "Wireshark capture started with PID $dumpcap_pid and pcap file $pcap_filename"

                echo "Running iperf3 test"
                # Start iperf server as a background process
                iperf3 -s -D

                # Wait briefly for server to initialize
                sleep 5

                # Run iperf client to send file over loopback interface and capture throughput
                iperf_output=$(iperf3 -c 127.0.0.1 -F "$file_20mb_name")
                echo "$iperf_output"
                throughput=$(echo "$iperf_output" | grep -oP '(?<=Bytes  )\d+.\d+(?= Mbits/sec)')
                echo "Throughput: $throughput Mbits/sec"
                # Append results to the corresponding CSV file
                if [ "$variant" == "Reno" ]; then
                    echo "$delay,$loss,$run,$throughput" >> reno_file.csv
                else
                    echo "$delay,$loss,$run,$throughput" >> cubic_file.csv
                fi
                ss -tni
                # Stop iperf server
                pkill iperf3
                sudo tc qdisc del dev lo root
                # Wait for Wireshark to complete capture and then kill dumpcap process
                wait $dumpcap_pid
            done
        done
    done
done
