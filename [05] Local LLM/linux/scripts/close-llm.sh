#!/usr/bin/env bash
# Stops llama-server however it was started (terminal, keybinding, systemd user unit).
# SIGINT first, SIGKILL only if it is still there after five seconds, then waits for the port to clear.
PORT=8080

if ! pgrep -x llama-server >/dev/null; then
    echo "llama-server is not running."
else
    pkill -INT -x llama-server
    for _ in $(seq 1 10); do
        pgrep -x llama-server >/dev/null || break
        sleep 0.5
    done
    if pgrep -x llama-server >/dev/null; then
        pkill -KILL -x llama-server
        sleep 0.5
    fi
    echo "llama-server stopped."
fi

# the socket can outlive the process briefly; wait before judging the port
for _ in $(seq 1 10); do
    ss -ltn "sport = :$PORT" | grep -q LISTEN || { echo "port $PORT is free."; exit 0; }
    sleep 0.5
done
echo "Port $PORT is still held by another program (left alone):"
ss -ltnp "sport = :$PORT"
exit 1
