#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  xvfb \
  x11vnc \
  novnc \
  websockify

python -m pip install --upgrade pip
python -m pip install -r requirements.txt
chmod +x start.sh

echo "Codespace setup complete. Run ./start.sh and open port 6080 to view the game."
