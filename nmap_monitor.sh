#!/usr/bin/env bash
#
# Usage: ./nmap_monitor.sh <TARGET> [<PORT_RANGE>] [<INTERVAL_SECONDS>]
# Example:
#   ./nmap_monitor.sh 192.168.1.0/24 1-1024 60
#
# This script continuously scans the target with nmap and reports when a service
# (an open port) goes up or down.

TARGET="$1"
PORT_RANGE="$2"
INTERVAL="$3"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <TARGET> [<PORT_RANGE>] [<INTERVAL_SECONDS>]"
  exit 1
fi

# Default to ports 1-1024 if not provided
: "${PORT_RANGE:=1-1024}"
# Default scan interval to 60 seconds
: "${INTERVAL:=60}"

# An associative array to store the state from the previous scan
declare -A prev_services

echo "Starting continuous scan on $TARGET for ports $PORT_RANGE every $INTERVAL seconds."
echo

while true; do
  echo "Scanning $TARGET..."
  # Run nmap with service detection (-sV) and output in grepable format (-oG -)
  nmap_output=$(nmap -p "$PORT_RANGE" -sV -oG - "$TARGET")
  
  # Declare an associative array for the current scan
  declare -A curr_services
  
  # Process each line that starts with "Host:"
  while IFS= read -r line; do
    if [[ "$line" == Host:* ]]; then
      # Extract the host IP (2nd field)
      host=$(echo "$line" | awk '{print $2}')
      # Extract the Ports field (everything after "Ports:")
      ports=$(echo "$line" | sed -n 's/.*Ports: \(.*\)/\1/p')
      if [[ -n "$ports" ]]; then
        # Split the ports by comma
        IFS=',' read -ra port_list <<< "$ports"
        for port_info in "${port_list[@]}"; do
          # Remove leading/trailing whitespace
          port_info=$(echo "$port_info" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          # The expected format is: port_number/state/protocol//service//...
          port_num=$(echo "$port_info" | cut -d'/' -f1)
          state=$(echo "$port_info" | cut -d'/' -f2)
          protocol=$(echo "$port_info" | cut -d'/' -f3)
          service=$(echo "$port_info" | cut -d'/' -f5)
          if [[ "$state" == "open" ]]; then
            # Build a unique key per host:port/protocol
            key="${host}:${port_num}/${protocol}"
            curr_services["$key"]="$service"
          fi
        done
      fi
    fi
  done <<< "$nmap_output"
  
  # Compare current scan with previous scan:
  # Report new services that are now up
  for key in "${!curr_services[@]}"; do
    if [[ -z "${prev_services[$key]}" ]]; then
      echo "[$(date)] SERVICE UP: $key -- ${curr_services[$key]}"
    fi
  done
  
  # Report services that are no longer up (went down)
  for key in "${!prev_services[@]}"; do
    if [[ -z "${curr_services[$key]}" ]]; then
      echo "[$(date)] SERVICE DOWN: $key -- ${prev_services[$key]}"
    fi
  done
  
  # Prepare for the next iteration by setting previous scan to current scan
  prev_services=()
  for key in "${!curr_services[@]}"; do
    prev_services["$key"]="${curr_services[$key]}"
  done
  
  echo "Scan complete. Waiting $INTERVAL seconds before next scan..."
  echo "------------------------------------------------------------"
  sleep "$INTERVAL"
done
