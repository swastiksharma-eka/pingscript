# Minimal image that continuously checks DNS servers via ICMP ping,
# DNS-over-UDP, and DNS-over-TCP, reporting timings for each.
FROM alpine:3.20

# iputils    -> ping
# bind-tools -> dig (used to test actual DNS queries over UDP and TCP)
RUN apk add --no-cache iputils bash bind-tools

# How often to run a full check cycle, in seconds (override with -e INTERVAL=10)
ENV INTERVAL=5

# Targets to check (space-separated, override with -e TARGETS="...")
ENV TARGETS="8.8.8.8 8.8.4.4"

# Where logs are written inside the container (override with -e LOG_FILE=...)
ENV LOG_FILE=/var/log/ping-monitor/ping.log
RUN mkdir -p /var/log/ping-monitor
VOLUME ["/var/log/ping-monitor"]

ENTRYPOINT ["bash", "-c", "\
    mkdir -p \"$(dirname \"$LOG_FILE\")\"; \
    echo \"Checking targets [$TARGETS] every ${INTERVAL}s (ICMP + DNS/UDP + DNS/TCP). Logging to $LOG_FILE.\" | tee -a \"$LOG_FILE\"; \
    while true; do \
        echo '' | tee -a \"$LOG_FILE\"; \
        echo \"[$(date '+%Y-%m-%d %H:%M:%S')]\" | tee -a \"$LOG_FILE\"; \
        for host in $TARGETS; do \
            if icmp_out=$(ping -c 1 -W 2 \"$host\" 2>&1); then \
                rtt=$(echo \"$icmp_out\" | grep -oE 'time=[0-9.]+ ?ms' | head -n1); \
                icmp_status=\"UP (${rtt:-rtt n/a})\"; \
            else \
                icmp_status=\"DOWN\"; \
            fi; \
            udp_out=$(dig @\"$host\" . NS +time=2 +tries=1 2>&1); \
            udp_rc=$?; \
            udp_ms=$(echo \"$udp_out\" | grep -oE 'Query time: [0-9]+ msec' | grep -oE '[0-9]+'); \
            if [ \"$udp_rc\" -eq 0 ] && [ -n \"$udp_ms\" ]; then \
                udp_status=\"UP (${udp_ms} ms)\"; \
            else \
                udp_status=\"DOWN\"; \
            fi; \
            tcp_out=$(dig @\"$host\" . NS +tcp +time=2 +tries=1 2>&1); \
            tcp_rc=$?; \
            tcp_ms=$(echo \"$tcp_out\" | grep -oE 'Query time: [0-9]+ msec' | grep -oE '[0-9]+'); \
            if [ \"$tcp_rc\" -eq 0 ] && [ -n \"$tcp_ms\" ]; then \
                tcp_status=\"UP (${tcp_ms} ms)\"; \
            else \
                tcp_status=\"DOWN\"; \
            fi; \
            echo \"  $host -> ICMP: $icmp_status | DNS/UDP: $udp_status | DNS/TCP: $tcp_status\" | tee -a \"$LOG_FILE\"; \
        done; \
        sleep \"$INTERVAL\"; \
    done \
"]
