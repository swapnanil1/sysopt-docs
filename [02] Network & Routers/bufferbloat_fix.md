# Reducing Bufferbloat on Linux/Unix

Bufferbloat is a phenomenon that occurs when excessive buffering of packets causes high latency and poor network performance. This document outlines a series of steps to configure network settings on Linux/Unix systems to reduce bufferbloat effectively.

## Step 1: Set Queue Discipline Algorithm and List TCP Congestion Control Algorithms

```bash
sudo tc qdisc show dev enp34s0
```

2. **Set a New Queue Discipline**
   Set the queue discipline to `cake` with a bandwidth limit for example 90 Mbps (approximately 11.25 MBps). change to what your bandwidth is and enp34s0 is my network interface paste yours.
   
   ```bash
   sudo tc qdisc add dev enp34s0 root cake bandwidth 90Mbit
   ```

3. **List All Supported TCP Congestion Control Algorithms**
   
   ```bash
   sysctl net.ipv4.tcp_available_congestion_control
   ```

## Step 2: Make QDisk and MTU values persitent

1. View Current mtu settings (my default 1500)
   
   ```bash
   sudo ip link show dev enp34s0 | grep mtu
   ```

2. View Current Overhead settings (my preferred value 44 , set 34 as a starting point)
   
   ```bash
   sudo tc qdisc show dev enp34s0
   ```

3. Paste the below code to create a systemd service to apply qdisk
   
   ```systemd
   [Unit]
   Description=Traffic Shaping with Cake on enp34s0 
   After=network-online.target
   Wants=network-online.target
   
   [Service]
   Type=oneshot
   RemainAfterExit=yes
   ExecStart=/bin/sh -c "/sbin/tc qdisc del dev enp34s0 root 2>/dev/null; /sbin/tc qdisc add dev enp34s0 root cake bandwidth 90Mbit overhead 44 diffserv3 triple-isolate nonat nowash no-ack-filter split-gso rtt 50ms"
   ExecStop=/sbin/tc qdisc del dev enp34s0 root
   
   [Install]
   WantedBy=multi-user.target
   ```

## Step 3: Update sysctl.conf

Edit the `/etc/sysctl.d/10-bufferbloat.conf` file to include the following settings for optimizing network performance and reducing bufferbloat. These settings will be applied at system startup or by executing `sysctl -p`.

### Bufferbloat and Network Performance Tuning

```bash
-net.core.default_qdisc = fq_codel
net.ipv4.tcp_ecn=1
net.core.netdev_max_backlog=1000
net.ipv4.tcp_sack=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_dsack=1
net.ipv4.tcp_no_metrics_save=1

```

## Step 4: Apply Settings in Terminal

1. **Set MTU Size for All Interfaces**
   
   ```bash
   echo "Setting MTU sizes for all interfaces..."
   sudo ip link set dev enp34s0 mtu 1500
   ```

## Important Notes

- Always ensure you have administrative privileges when executing these commands and modifying system files.
- The network interface names (e.g., `enp34s0`, `eth0`) must be adjusted according to your system's configuration. Check your interfaces using `ip link show`.
- When assessing performance improvements, monitor metrics such as latency and throughput to ensure these configurations yield the desired effects.

### Potential Issues

- If using `ethtool`, ensure it's installed on your system. Use the command `sudo apt install ethtool` if needed.
- The `tc` and `sysctl` changes may not take effect until the network service is restarted or the system is rebooted.
- Consider testing with different congestion control algorithms if "cubic" doesn't meet performance expectations. Other options include "bbr", "reno", and "vegas".

## Conclusion

Implementing these configurations can significantly reduce bufferbloat and improve overall network performance on Linux/Unix systems. Monitor your network's performance following these changes and adjust settings as necessary for optimal results.
