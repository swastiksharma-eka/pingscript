#!/usr/bin/env bash
# ping_dns_check.sh
#
# Runs a single check cycle (ICMP ping + DNS query over UDP + DNS query
# over TCP) against each target and appends timestamped results to a log
# file. Designed to be triggered by cron, which handles the interval —
# this script itself does NOT loop or sleep.
#
# Requires: ping (iputils), dig (bind-tools / dnsutils)
#   Debian/Ubuntu: sudo apt-get install -y iputils-ping dnsutils
#   RHEL/CentOS:   sudo yum install -y iputils bind-utils
#   Alpine:        apk add iputils bind-tools
#
# --- Configure here ---
TARGETS="8.8.8.8 8.8.4.4"
LOG_FILE="/var/log/ping-monitor/ping.log"
TIMEOUT=2
# -----------------------

set -u

mkdir -p "$(dirname "$LOG_FILE")"

{
    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]"
    for host in $TARGETS; do
        # --- ICMP ---
        if icmp_out=$(ping -c 1 -W "$TIMEOUT" "$host" 2>&1); then
            rtt=$(echo "$icmp_out" | grep -oE 'time=[0-9.]+ ?ms' | head -n1)
            icmp_status="UP (${rtt:-rtt n/a})"
        else
            icmp_status="DOWN"
        fi

        # --- DNS over UDP ---
        udp_out=$(dig @"$host" . NS +time="$TIMEOUT" +tries=1 2>&1)
        udp_rc=$?
        udp_ms=$(echo "$udp_out" | grep -oE 'Query time: [0-9]+ msec' | grep -oE '[0-9]+')
        if [ "$udp_rc" -eq 0 ] && [ -n "$udp_ms" ]; then
            udp_status="UP (${udp_ms} ms)"
        else
            udp_status="DOWN"
        fi

        # --- DNS over TCP ---
        tcp_out=$(dig @"$host" . NS +tcp +time="$TIMEOUT" +tries=1 2>&1)
        tcp_rc=$?
        tcp_ms=$(echo "$tcp_out" | grep -oE 'Query time: [0-9]+ msec' | grep -oE '[0-9]+')
        if [ "$tcp_rc" -eq 0 ] && [ -n "$tcp_ms" ]; then
            tcp_status="UP (${tcp_ms} ms)"
        else
            tcp_status="DOWN"
        fi

        echo "  $host -> ICMP: $icmp_status | DNS/UDP: $udp_status | DNS/TCP: $tcp_status"
    done
} >> "$LOG_FILE" 2>&1
