tc qdisc del dev lo root 2> /dev/null
# tc qdisc show dev lo

echo "Applying tc rules..."
tc qdisc add dev lo root handle 1: htb default 12 r2q 1
# tc qdisc show dev lo

tc class add dev lo parent 1: classid 1:1 htb rate 100mbit quantum 1500
# tc qdisc show dev lo

tc class add dev lo parent 1:1 classid 1:12 htb rate 100mbit quantum 1500
# tc qdisc show dev lo

tc qdisc add dev lo parent 1:12 handle 10: netem delay 100ms loss 10%
# tc qdisc show dev lo


# Display tc qdisc settings
echo "Current tc qdisc configuration:"
tc qdisc show dev lo
