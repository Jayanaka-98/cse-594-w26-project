#!/usr/bin/env bash
# Start FlowBoard locally (jac start, background, port 8000).
set -euo pipefail

PID_FILE=".jac/server.pid"
LOG_FILE=".jac/server.log"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Already running (pid $(cat "$PID_FILE")). Run ./stop.sh first."
    exit 1
fi

if [ -f .env ]; then
    set -a; source .env; set +a
fi

mkdir -p .jac
nohup jac start main.jac --port 8000 > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

echo "FlowBoard started (pid $!) — logs: $LOG_FILE"
echo "  http://localhost:8000/cl/app"
echo "  tail -f $LOG_FILE"
