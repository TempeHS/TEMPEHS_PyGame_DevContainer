#!/bin/bash
# Starts Xvfb, x11vnc, noVNC, and the game in one command.
# View the game at the forwarded port 6080 in VS Code's Ports tab.

GAME_PID=""

start_game() {
	echo "Starting game..."
	DISPLAY=:99 python src/main.py &
	GAME_PID=$!
}

stop_game() {
	if [ -n "$GAME_PID" ] && kill -0 "$GAME_PID" 2>/dev/null; then
		kill "$GAME_PID" 2>/dev/null
		wait "$GAME_PID" 2>/dev/null
	fi
}

cleanup() {
	stop_game
	pkill -9 -f "x11vnc" 2>/dev/null
	pkill -9 -f "novnc_proxy" 2>/dev/null
	pkill -9 -f "websockify" 2>/dev/null
	pkill -9 -f "Xvfb" 2>/dev/null
}

snapshot_src() {
	find src -type f -print0 | sort -z | xargs -0 -r sha1sum 2>/dev/null | sha1sum | awk '{print $1}'
}

trap cleanup EXIT INT TERM

# Set up XDG runtime dir
mkdir -p /tmp/runtime-$USER
chmod 700 /tmp/runtime-$USER
export XDG_RUNTIME_DIR=/tmp/runtime-$USER

# Kill all existing instances to ensure correct resolution
pkill -9 -f "python src/main.py" 2>/dev/null
pkill -9 -f "x11vnc" 2>/dev/null
pkill -9 -f "novnc_proxy" 2>/dev/null
pkill -9 -f "websockify" 2>/dev/null
pkill -9 -f "Xvfb" 2>/dev/null
sleep 2

# Start VNC stack
echo "Starting Xvfb..."
Xvfb :99 -screen 0 1920x1080x24 &
sleep 1

echo "Starting x11vnc..."
x11vnc -display :99 -nopw -listen localhost -xkb -forever -quiet -rfbport 5900 &
sleep 1

echo "Starting noVNC..."
/usr/share/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 &
sleep 1

# Run the game and restart when files change
start_game

if command -v inotifywait >/dev/null 2>&1; then
	echo "Watching src/ for changes with inotify..."
	while true; do
		inotifywait -r -e modify,create,delete,move,attrib,close_write src >/dev/null 2>&1
		echo "Change detected in src/. Restarting game..."
		stop_game
		start_game
	done
else
	echo "inotifywait not found. Using polling watcher (1s interval)..."
	LAST_SNAPSHOT=$(snapshot_src)
	while true; do
		sleep 1
		NEW_SNAPSHOT=$(snapshot_src)
		if [ "$NEW_SNAPSHOT" != "$LAST_SNAPSHOT" ]; then
			echo "Change detected in src/. Restarting game..."
			LAST_SNAPSHOT=$NEW_SNAPSHOT
			stop_game
			start_game
		elif ! kill -0 "$GAME_PID" 2>/dev/null; then
			echo "Game process exited. Restarting..."
			start_game
		fi
	done
fi
