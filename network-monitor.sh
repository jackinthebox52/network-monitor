#!/bin/bash
# network-monitor.sh - Track network usage and apply thresholds
# Usage: 
#   ./network-monitor.sh check [interface|all]
#   ./network-monitor.sh set-threshold [interface] [threshold-MB]
#   ./network-monitor.sh list-thresholds
#   ./network-monitor.sh reset-counter [interface|all]
#   ./network-monitor.sh status

# Configuration file for thresholds
CONFIG_DIR="/etc/network-monitor"
THRESHOLD_FILE="$CONFIG_DIR/thresholds.conf"
COUNTER_FILE="$CONFIG_DIR/counters.dat"
LOG_FILE="/var/log/network-monitor.log"

# Create config directory if it doesn't exist
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    touch "$THRESHOLD_FILE"
    touch "$COUNTER_FILE"
    touch "$LOG_FILE"
    chmod 750 "$CONFIG_DIR"
    chmod 640 "$THRESHOLD_FILE" "$COUNTER_FILE" "$LOG_FILE"
fi

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$1"
}

# Function to get current interface usage (in bytes)
get_current_usage() {
    local interface=$1
    local rx=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null)
    local tx=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null)
    
    if [ -z "$rx" ] || [ -z "$tx" ]; then
        echo "0"
    else
        echo $((rx + tx))
    fi
}

# Function to get saved counter value
get_saved_counter() {
    local interface=$1
    local saved=$(grep "^$interface:" "$COUNTER_FILE" | cut -d: -f2)
    
    if [ -z "$saved" ]; then
        echo "0"
    else
        echo "$saved"
    fi
}

# Function to update saved counter value
update_counter() {
    local interface=$1
    local value=$2
    
    if grep -q "^$interface:" "$COUNTER_FILE"; then
        sed -i "s/^$interface:.*/$interface:$value/" "$COUNTER_FILE"
    else
        echo "$interface:$value" >> "$COUNTER_FILE"
    fi
}

# Function to reset counter for an interface
reset_counter() {
    local interface=$1
    
    if [ "$interface" = "all" ]; then
        > "$COUNTER_FILE"
        log_message "Reset all interface counters"
    else
        local current=$(get_current_usage "$interface")
        update_counter "$interface" "$current"
        log_message "Reset counter for $interface"
    fi
}

# Function to check interface usage
check_usage() {
    local interface=$1
    
    # Get current bytes
    local current=$(get_current_usage "$interface")
    
    # Get saved counter
    local saved=$(get_saved_counter "$interface")
    
    # Calculate usage since last reset
    local usage=$((current - saved))
    
    # Convert to MB for display
    local usage_mb=$(echo "scale=2; $usage / 1048576" | bc)
    
    echo "$interface: $usage_mb MB"
}

# Function to check all interfaces (except lo)
check_all_interfaces() {
    for interface in $(ls /sys/class/net/ | grep -v "lo"); do
        check_usage "$interface"
    done
}

# Function to set threshold
set_threshold() {
    local interface=$1
    local threshold_mb=$2
    # Ensure threshold_mb is numeric
    threshold_mb=$(echo "$threshold_mb" | tr -cd '0-9')
    
    if [ -z "$threshold_mb" ]; then
        log_message "Error: Invalid threshold value"
        return 1
    fi
    
    local threshold_bytes=$((threshold_mb * 1048576))
    local service=""
    
    # If it's a wireguard interface, associate the corresponding service
    if [[ "$interface" == wg* ]]; then
        service="wg-quick@$interface"
    fi
    
    # Remove any existing entry for this interface (including commented ones)
    sed -i "/^$interface:/d" "$THRESHOLD_FILE"
    
    # Add the new entry
    echo "$interface:$threshold_bytes:$service" >> "$THRESHOLD_FILE"
    
    log_message "Set threshold for $interface to $threshold_mb MB"
}

# Function to list all thresholds
list_thresholds() {
    echo "Current thresholds:"
    while IFS=: read -r interface threshold_bytes service; do
        if [ -z "$interface" ] || [ -z "$threshold_bytes" ]; then
            # Skip empty or comment lines
            continue
        fi
        # Make sure threshold_bytes is treated as a number
        threshold_bytes=$(echo "$threshold_bytes" | tr -cd '0-9')
        if [ -n "$threshold_bytes" ]; then
            local threshold_mb=$(echo "scale=2; $threshold_bytes / 1048576" | bc)
            echo "$interface: $threshold_mb MB $([ -n "$service" ] && echo "(Service: $service)")"
        fi
    done < "$THRESHOLD_FILE"
}

# Function to check thresholds and take action if needed
check_thresholds() {
    local threshold_exceeded=0
    
    while IFS=: read -r interface threshold_bytes service; do
        if [ -z "$interface" ] || [ -z "$threshold_bytes" ]; then
            continue
        fi
        
        # Get current usage
        local current=$(get_current_usage "$interface")
        local saved=$(get_saved_counter "$interface")
        local usage=$((current - saved))
        
        # Convert to MB for logging
        local usage_mb=$(echo "scale=2; $usage / 1048576" | bc)
        local threshold_mb=$(echo "scale=2; $threshold_bytes / 1048576" | bc)
        
 service defined, stop and disable it
            if [ -n "$service" ]; then
                log_message "Stopping service $service due to threshold breach"
                systemctl stop "$service"
                systemctl disable "$service"
                log_message "Service $service stopped and disabled"
            else
                log_message "No service defined for $interface, can't perform automatic action"
            fi
        fi
    done < "$THRESHOLD_FILE"
    
    return $threshold_exceeded
}

# Function to show current status
show_status() {
    echo "Network Monitor Status:"
    echo "-----------------------"
    check_all_interfaces
    echo "-----------------------"
    list_thresholds
    echo "-----------------------"
    echo "Last 5 log entries:"
    tail -n 5 "$LOG_FILE"
}

# Main logic based on arguments
case "$1" in
    check)
        if [ "$2" = "all" ]; then
            check_all_interfaces
        elif [ -n "$2" ]; then
            check_usage "$2"
        else
            echo "Usage: $0 check [interface|all]"
            exit 1
        fi
        ;;
    set-threshold)
        if [ -n "$2" ] && [ -n "$3" ]; then
            set_threshold "$2" "$3"
        else
            echo "Usage: $0 set-threshold [interface] [threshold-MB]"
            exit 1
        fi
        ;;
    list-thresholds)
        list_thresholds
        ;;
    reset-counter)
        if [ -n "$2" ]; then
            reset_counter "$2"
        else
            echo "Usage: $0 reset-counter [interface|all]"
            exit 1
        fi
        ;;
    status)
        show_status
        ;;
    *)
        echo "Network Monitor - Usage tracking and threshold management"
        echo "Usage:"
        echo "  $0 check [interface|all] - Check current usage"
        echo "  $0 set-threshold [interface] [threshold-MB] - Set usage threshold"
        echo "  $0 list-thresholds - List all configured thresholds"
        echo "  $0 reset-counter [interface|all] - Reset usage counter"
        echo "  $0 status - Show overall status"
        echo "  $0 check-thresholds - Check all interfaces against thresholds"
        echo "  $0 force-disable [wg-interface] - Force stop a WireGuard interface"
        exit 1
        ;;
esac

# Add a cron job for regular checking
# This script should create this file on first run
if [ ! -f "/etc/cron.d/network-monitor" ]; then
    cat > "/etc/cron.d/network-monitor" << EOF
# Run network monitor checks every hour
0 * * * * root /bin/bash $(realpath $0) check all > /dev/null 2>&1
# Check thresholds every hour
15 * * * * root /bin/bash $(realpath $0) check-thresholds > /dev/null 2>&1
# Reset counters on the 1st of each month
0 0 1 * * root /bin/bash $(realpath $0) reset-counter all > /dev/null 2>&1
EOF
    log_message "Created cron job for regular monitoring"
fi

exit 0