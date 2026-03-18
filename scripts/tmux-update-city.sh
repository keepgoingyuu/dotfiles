#!/bin/bash
while true; do
  city=$(curl -sf --max-time 5 ifconfig.co/city 2>/dev/null)
  if [ -n "$city" ]; then
    echo -n "$city" > /tmp/tmux_city
  fi
  sleep 600
done
