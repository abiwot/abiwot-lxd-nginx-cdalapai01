#!/bin/bash

# Configuration
HOSTS_FILE="/etc/hosts"
MOBILE_HOSTS_FILE="/etc/hosts.mobile"
STATUS_FILE="/tmp/hosts_mobile_status"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

# Create mobile hosts file if it doesn't exist
if [ ! -f "$MOBILE_HOSTS_FILE" ]; then
  echo "# Mobile hosts entries - will be toggled when needed" > "$MOBILE_HOSTS_FILE"
  echo "# Add your entries below in the format: IP HOSTNAME" >> "$MOBILE_HOSTS_FILE"
  echo "# Example:" >> "$MOBILE_HOSTS_FILE"
  echo "# 10.0.0.10 internal-server.example.com" >> "$MOBILE_HOSTS_FILE"
  echo "Created $MOBILE_HOSTS_FILE. Please edit this file to add your mobile hosts entries."
  exit 0
fi

# Function to check if mobile entries are enabled
is_mobile_enabled() {
  if [ -f "$STATUS_FILE" ] && [ "$(cat "$STATUS_FILE")" == "enabled" ]; then
    return 0  # true
  else
    return 1  # false
  fi
}

# Function to enable mobile hosts
enable_mobile() {
  # Check if already enabled
  if is_mobile_enabled; then
    echo "Mobile hosts are already enabled."
    return
  fi
  
  # Create backup if it doesn't exist
  if [ ! -f "${HOSTS_FILE}.backup" ]; then
    cp "$HOSTS_FILE" "${HOSTS_FILE}.backup"
    echo "Created backup of original hosts file at ${HOSTS_FILE}.backup"
  fi
  
  # Add mobile entries
  echo "" >> "$HOSTS_FILE"
  echo "# BEGIN MOBILE HOSTS - DO NOT EDIT THIS SECTION" >> "$HOSTS_FILE"
  cat "$MOBILE_HOSTS_FILE" >> "$HOSTS_FILE"
  echo "# END MOBILE HOSTS" >> "$HOSTS_FILE"
  
  # Update status
  echo "enabled" > "$STATUS_FILE"
  echo "Mobile hosts enabled. To disable, run: sudo $0 disable"
  
  # Flush DNS cache if systemd-resolved is being used
  if command -v systemd-resolve &> /dev/null; then
    systemd-resolve --flush-caches
    echo "DNS cache flushed"
  fi
}

# Function to disable mobile hosts
disable_mobile() {
  # Check if already disabled
  if ! is_mobile_enabled; then
    echo "Mobile hosts are already disabled."
    return
  fi
  
  # Remove mobile entries section from hosts file
  sed -i '/# BEGIN MOBILE HOSTS - DO NOT EDIT THIS SECTION/,/# END MOBILE HOSTS/d' "$HOSTS_FILE"
  
  # Update status
  echo "disabled" > "$STATUS_FILE"
  echo "Mobile hosts disabled. To enable, run: sudo $0 enable"
  
  # Flush DNS cache if systemd-resolved is being used
  if command -v systemd-resolve &> /dev/null; then
    systemd-resolve --flush-caches
    echo "DNS cache flushed"
  fi
}

# Function to edit mobile hosts file
edit_mobile() {
  if [ -z "$EDITOR" ]; then
    EDITOR="nano"
  fi
  
  $EDITOR "$MOBILE_HOSTS_FILE"
  
  # If mobile hosts are currently enabled, refresh them
  if is_mobile_enabled; then
    disable_mobile
    enable_mobile
    echo "Mobile hosts refreshed with new entries"
  fi
}

# Function to show current status
status() {
  if is_mobile_enabled; then
    echo "Mobile hosts are currently ENABLED"
    echo "Mobile entries currently active:"
    sed -n '/# BEGIN MOBILE HOSTS/,/# END MOBILE HOSTS/p' "$HOSTS_FILE" | grep -v "#"
  else
    echo "Mobile hosts are currently DISABLED"
  fi
  
  echo -e "\nAvailable mobile entries (from $MOBILE_HOSTS_FILE):"
  grep -v "^#" "$MOBILE_HOSTS_FILE" || echo "No entries found"
}

# Show help
show_help() {
  echo "Usage: $0 [enable|disable|edit|status]"
  echo
  echo "Options:"
  echo "  enable    Enable mobile hosts entries"
  echo "  disable   Disable mobile hosts entries"
  echo "  edit      Edit the mobile hosts file"
  echo "  status    Show current status"
  echo
  echo "Run without arguments to see this help."
}

# Main logic
case "$1" in
  enable)
    enable_mobile
    ;;
  disable)
    disable_mobile
    ;;
  edit)
    edit_mobile
    ;;
  status)
    status
    ;;
  *)
    show_help
    ;;
esac

exit 0