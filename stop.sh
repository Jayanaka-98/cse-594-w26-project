#!/usr/bin/env bash
# Stop the locally running FlowBoard server.
set -euo pipefail

PID_FILE=".jac/server.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "No PID file found — server may not be running."
    exit 0
fi

PID=$(cat "$PID_FILE")

if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    rm -f "$PID_FILE"
    echo "FlowBoard stopped (pid $PID)."
else
    echo "Process $PID not found — cleaning up stale PID file."
    rm -f "$PID_FILE"
fi
