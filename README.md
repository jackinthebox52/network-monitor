# Network Usage Monitor

A simple bash-based tool to track network usage on cron-capable Unix systems and enforce usage thresholds.
(Developed and tested solely on Debian)

## Installation

### Quick Installation

1. Clone this repository or download the files
2. Make the installer executable:
   ```bash
   chmod +x installer.sh
   ```
3. Run the installer:
   ```bash
   sudo ./installer.sh
   ```

### Manual Installation

If you prefer to set up the system manually:

1. Copy the script to your bin directory:
   ```bash
   sudo cp network-monitor.sh /usr/local/bin/
   sudo chmod +x /usr/local/bin/network-monitor.sh
   ```

2. Create a symlink (optional):
   ```bash
   sudo ln -s /usr/local/bin/network-monitor.sh /usr/local/bin/netmon
   ```

3. Create required directories and files:
   ```bash
   sudo mkdir -p /etc/network-monitor
   sudo touch /etc/network-monitor/thresholds.conf
   sudo touch /etc/network-monitor/counters.dat
   sudo touch /var/log/network-monitor.log
   ```

4. Set appropriate permissions:
   ```bash
   sudo chmod 750 /etc/network-monitor
   sudo chmod 640 /etc/network-monitor/thresholds.conf /etc/network-monitor/counters.dat /var/log/network-monitor.log
   ```

## Configuration

### Setting Up Thresholds

Create or edit the thresholds configuration file:

```bash
sudo nano /etc/network-monitor/thresholds.conf
```

Each line in this file defines a threshold in the format:
```
interface:threshold_bytes:service_name
```

For example:
```
wg0:5368709120:wg-quick@wg0
eth0:10737418240:
```

This sets a 5GB threshold for wg0 (will stop the WireGuard service when exceeded) and a 10GB threshold for eth0 (monitoring only).

### Setting Up Cron Jobs (Optional)

To enable automatic monitoring and monthly resets, create a cron file (This file is created automatically if you run the installer):

```bash
sudo nano /etc/cron.d/network-monitor
```

Example content:
```
# Check thresholds every hour
15 * * * * root /bin/bash /usr/local/bin/network-monitor.sh check-thresholds > /dev/null 2>&1
# Reset counters on the 1st of each month
0 0 1 * * root /bin/bash /usr/local/bin/network-monitor.sh reset-counter all > /dev/null 2>&1
```

## Usage

### Basic Commands

Check usage for a specific interface:
```bash
sudo netmon check wg0
```

Check all interfaces:
```bash
sudo netmon check all
```

Set a threshold (example: 5GB):
```bash
sudo netmon set-threshold wg0 5000
```

List configured thresholds:
```bash
sudo netmon list-thresholds
```

Reset counter for an interface:
```bash
sudo netmon reset-counter wg0
```

Reset all counters:
```bash
sudo netmon reset-counter all
```

Show overall status:
```bash
sudo netmon status
```

## Byte Size Reference

When manually setting thresholds in the configuration file, use exact byte values. For example:

- 1GB = 1073741824 bytes
- 5GB = 5368709120 bytes
- 10GB = 10737418240 bytes

## Log File

The log file is located at `/var/log/network-monitor.log` and contains all actions and alerts.


### Dependencies

This script requires the `bc` package. Debian/Ubuntu install:

```bash
sudo apt-get update
sudo apt-get install bc
```


