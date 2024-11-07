#!/bin/bash

# Configuration Variables
LOOPBACK_IF="lo"
DELAY=100          # Delay in ms
LOSS=1             # Packet loss in %
BANDWIDTH=100000     # Bandwidth in kbit
BURST=32           # Burst size in k

# # Function to set traffic control settings
# set_tc() {
#     local delay=$1
#     local loss=$2
#     local bandwidth=$3
#     local burst=$4

#     echo "Configuring tc with Delay=${delay}ms, Loss=${loss}%, Bandwidth=${bandwidth}kbit, and Burst=${burst}k"

#     # Clear existing qdiscs
#     tc qdisc del dev $LOOPBACK_IF root 2> /dev/null

#     # Add root HTB qdisc for bandwidth control
#     tc qdisc add dev $LOOPBACK_IF root handle 1: htb default 10

#     # Add HTB class with specified bandwidth and burst
#     tc class add dev $LOOPBACK_IF parent 1: classid 1:1 htb rate ${bandwidth}kbit burst ${burst}k

#     # Add netem qdisc for delay and loss under HTB class
#     tc qdisc add dev $LOOPBACK_IF parent 1:1 handle 10: netem delay ${delay}ms loss ${loss}%
# }


# #!/bin/bash

set_tc() {
    # Check if the correct number of arguments is provided
    if [ "$#" -ne 4 ]; then
        echo "Usage: set_tc <delay(ms)> <loss(%)> <bandwidth(mbit)> <burst(k)>"
        return 1
    fi

    local delay=$1
    local loss=$2
    local bandwidth=$3
    local burst=$4
    local IFACE="lo"

    echo "Configuring tc with Delay=${delay}ms, Loss=${loss}%, Bandwidth=${bandwidth}mbit, and Burst=${burst}k on interface ${IFACE}"

    sudo tc qdisc del dev lo root 2> /dev/null
    sudo tc qdisc add dev lo root handle 1: htb default 12 r2q 1
    sudo tc class add dev lo parent 1: classid 1:1 htb rate 100mbit quantum 1500 burst 32k
    sudo tc class add dev lo parent 1:1 classid 1:12 htb rate 100mbit quantum 1500 burst 32k
    sudo tc qdisc add dev lo parent 1:12 handle 10: netem delay $delay loss $loss%
    echo "Current tc qdisc configuration on ${IFACE}:"
    sudo tc qdisc show dev "$IFACE"
}




# Function to clean up traffic control settings
cleanup_tc() {
    echo "Removing tc settings from ${LOOPBACK_IF}"
    tc qdisc del dev $LOOPBACK_IF root 2> /dev/null
}

# Function to verify delay and packet loss using ping
verify_delay_loss() {
    echo -e "\nVerifying Delay and Packet Loss with ping:"
    # Send 10 ICMP packets to localhost
    ping -c 10 -i 0.2 127.0.0.1
}

# Function to verify bandwidth limitation using iperf3
verify_bandwidth() {
    echo -e "\nVerifying Bandwidth Limitation with iperf3:"
    # Run iperf3 in client mode connecting to localhost
    iperf3 -c 127.0.0.1 -t 10
}

# Function to display current tc settings
show_tc_settings() {
    echo -e "\nCurrent tc settings on ${LOOPBACK_IF}:"
    tc qdisc show dev $LOOPBACK_IF
    tc class show dev $LOOPBACK_IF
}

# Main Script Execution

# Ensure cleanup on exit
# trap cleanup_tc EXIT
# cleanup_tc
# Set tc settings
set_tc $DELAY $LOSS $BANDWIDTH $BURST
echo "____"
# Show tc settings
show_tc_settings
echo "____"
# Start iperf3 server in the background
echo "Starting iperf3 server on localhost..."
iperf3 -s -D

# Wait briefly to ensure iperf3 server starts
sleep 2

# Perform verifications
verify_delay_loss
verify_bandwidth

# Stop iperf3 server
echo "Stopping iperf3 server..."
pkill iperf3

# Cleanup is handled by trap
