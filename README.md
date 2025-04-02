# Usage: ./nmap_monitor.sh <TARGET> [<PORT_RANGE>] [<INTERVAL_SECONDS>]
# Example:
#   ./nmap_monitor.sh 192.168.1.0/24 1-1024 60
# This will scan all computers on the subnet 192.168.1.0 for the status of ports 1 to 1024, and will rescan every 60 seconds.
#
# This script continuously scans the target with nmap and reports when a service
# (an open port) goes up or down.