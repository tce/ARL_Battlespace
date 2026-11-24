#!/bin/bash
# Launch an ARL Battlespace game on macOS: one Terminal window for the server
# (ServerWithUI.py --test) and two Terminal windows for HumanInterface.py clients.
#
# Usage: ./launch_game.sh [server_ip]
#   server_ip defaults to this machine's local IP address.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_ACTIVATE="$TEST_DIR/../bin/activate"
PORT=5050
CLIENT_DELAY=3   # seconds to wait for the server to start listening

if [[ ! -f "$VENV_ACTIVATE" ]]; then
    echo "Error: virtualenv not found at $VENV_ACTIVATE" >&2
    exit 1
fi

# Same method ServerWithUI.py's getIp() uses to find the local IP.
local_ip() {
    "$TEST_DIR/../bin/python" -c "import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    s.connect(('10.255.255.255', 1)); print(s.getsockname()[0])
except Exception:
    print('127.0.0.1')
finally:
    s.close()"
}

SERVER_IP="${1:-$(local_ip)}"

if lsof -nP -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Error: something is already listening on port $PORT:" >&2
    lsof -nP -iTCP:$PORT -sTCP:LISTEN >&2
    echo "Stop that process (e.g. kill <PID>) and run this script again." >&2
    exit 1
fi

# Open a new Terminal window running the given command in the test directory.
open_terminal() {
    local cmd="cd '$TEST_DIR' && source '$VENV_ACTIVATE' && $1"
    osascript - "$cmd" <<'EOF'
on run argv
    tell application "Terminal"
        activate
        do script (item 1 of argv)
    end tell
end run
EOF
}

echo "Starting server on $SERVER_IP:$PORT ..."
open_terminal "python ServerWithUI.py --test"

# Wait until the server is listening (up to ~15s) before starting clients.
for _ in $(seq 1 15); do
    lsof -nP -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1 && break
    sleep 1
done
sleep "$CLIENT_DELAY"

if ! lsof -nP -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Warning: server doesn't appear to be listening on port $PORT yet; starting clients anyway." >&2
fi

for i in 1 2; do
    echo "Starting client $i ..."
    open_terminal "python HumanInterface.py $SERVER_IP"
    sleep 1
done

echo "Done. Server and two clients are running in separate Terminal windows."
