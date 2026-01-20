#!/usr/bin/env bash
#
# prepare_pi.sh - Prepare Raspberry Pi for DVMHost installation
#
# This script configures a Raspberry Pi (4 or 5) by:
# - Removing serial console from kernel command line
# - Disabling Bluetooth and onboard sound
# - Configuring UART for serial communication
# - Disabling conflicting system services
#
# Usage: sudo ./prepare_pi.sh
#
# Requirements:
# - Raspberry Pi OS 12 or 13
# - Must be run as root

set -euo pipefail

# Constants
CMDLINE_FILE="/boot/firmware/cmdline.txt"
CONFIG_FILE="/boot/firmware/config.txt"
CONSOLE_PARAM="console=serial0,115200"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check OS version (must be Raspberry Pi OS 12 or 13)
check_os_version() {
  local version_id
  
  # Check for test environment variable first
  if [ -n "${TEST_OS_VERSION:-}" ]; then
    version_id="$TEST_OS_VERSION"
    log_info "Using test OS version: $version_id"
  elif [ ! -f /etc/os-release ]; then
    log_error "Cannot determine OS version (/etc/os-release not found)"
    exit 1
  else
    version_id=$(grep "^VERSION_ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
  fi
  
  if [ "$version_id" != "12" ] && [ "$version_id" != "13" ]; then
    log_error "Unsupported OS version: $version_id (must be Raspberry Pi OS 12 or 13)"
    exit 1
  fi
  
  log_info "OS Version: Raspberry Pi OS $version_id"
}

# Check if running on Raspberry Pi
check_raspberry_pi() {
  local model
  
  # Check for test environment variable first
  if [ -n "${TEST_PI_MODEL:-}" ]; then
    model="$TEST_PI_MODEL"
    log_info "Using test Pi model: $model"
  elif [ ! -f /proc/device-tree/model ]; then
    log_error "Not running on a Raspberry Pi (no device tree model found)"
    exit 1
  else
    model=$(tr -d '\0' < /proc/device-tree/model)
  fi
  
  if [[ ! "$model" =~ Raspberry\ Pi ]]; then
    log_error "Not running on a Raspberry Pi (detected: $model)"
    exit 1
  fi
  
  log_info "Detected: $model"
}

# Check if running as root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
  fi
}

# Detect Raspberry Pi version (must be 4 or 5)
detect_pi_version() {
  local model
  
  # Check for test environment variable first
  if [ -n "${TEST_PI_MODEL:-}" ]; then
    model="$TEST_PI_MODEL"
  else
    model=$(tr -d '\0' < /proc/device-tree/model)
  fi
  
  if [[ "$model" =~ "Raspberry Pi 5" ]]; then
    echo "5"
  elif [[ "$model" =~ "Raspberry Pi 4" ]]; then
    echo "4"
  else
    log_error "Unsupported Raspberry Pi model: $model"
    log_error "This script only supports Raspberry Pi 4 and Raspberry Pi 5"
    exit 1
  fi
}

# Remove console parameter from cmdline.txt
modify_cmdline() {
  if [ ! -f "$CMDLINE_FILE" ]; then
    log_warn "$CMDLINE_FILE not found, skipping cmdline modification"
    return
  fi
  
  if grep -q "$CONSOLE_PARAM" "$CMDLINE_FILE"; then
    log_info "Removing $CONSOLE_PARAM from $CMDLINE_FILE"
    # Create backup
    cp "$CMDLINE_FILE" "${CMDLINE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    # Remove the console parameter (handle spaces correctly)
    sed -i "s/\s*$CONSOLE_PARAM\s*/ /g" "$CMDLINE_FILE"
    # Clean up multiple spaces
    sed -i 's/  \+/ /g' "$CMDLINE_FILE"
    log_info "Successfully modified $CMDLINE_FILE"
  else
    log_info "$CONSOLE_PARAM not found in $CMDLINE_FILE, skipping"
  fi
}

# Modify config.txt based on Pi version
modify_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    log_error "$CONFIG_FILE not found"
    exit 1
  fi
  
  local pi_version
  pi_version=$(detect_pi_version)
  
  # Create backup
  cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
  
  # For Pi 4 and above, disable Bluetooth
  if [ "$pi_version" = "4" ] || [ "$pi_version" = "5" ]; then
    if ! grep -q "^dtoverlay=disable-bt" "$CONFIG_FILE"; then
      log_info "Adding dtoverlay=disable-bt to $CONFIG_FILE"
      echo "dtoverlay=disable-bt" >> "$CONFIG_FILE"
    else
      log_info "dtoverlay=disable-bt already present in $CONFIG_FILE"
    fi
  fi
  
  # For Pi 5, add UART configuration to [all] section
  if [ "$pi_version" = "5" ]; then
    log_info "Configuring UART for Raspberry Pi 5"
    
    # Check if [all] section exists
    if ! grep -q "^\[all\]" "$CONFIG_FILE"; then
      log_info "Adding [all] section to $CONFIG_FILE"
      echo "" >> "$CONFIG_FILE"
      echo "[all]" >> "$CONFIG_FILE"
    fi
    
    # Add UART settings if not present
    if ! grep -q "^enable_uart=1" "$CONFIG_FILE"; then
      log_info "Adding enable_uart=1"
      # Insert after [all] section
      sed -i '/^\[all\]/a enable_uart=1' "$CONFIG_FILE"
    else
      log_info "enable_uart=1 already present"
    fi
    
    if ! grep -q "^dtoverlay=uart0,ctsrts" "$CONFIG_FILE"; then
      log_info "Adding dtoverlay=uart0,ctsrts"
      # Insert after [all] section
      sed -i '/^\[all\]/a dtoverlay=uart0,ctsrts' "$CONFIG_FILE"
    else
      log_info "dtoverlay=uart0,ctsrts already present"
    fi
  fi
  
  log_info "Successfully modified $CONFIG_FILE"
}

# Disable and mask system services
disable_services() {
  local services=(
    "serial-getty@ttyAMA0.service"
    "hciuart.service"
    "bluealsa.service"
    "bluetooth.service"
  )
  
  log_info "Disabling and masking system services"
  
  for service in "${services[@]}"; do
    # Check if service exists before trying to disable
    if systemctl list-unit-files | grep -q "^${service}"; then
      log_info "Disabling $service"
      systemctl disable "$service" 2>/dev/null || log_warn "Could not disable $service (may not be active)"
      
      log_info "Masking $service"
      systemctl mask "$service" 2>/dev/null || log_warn "Could not mask $service"
    else
      log_warn "$service not found, skipping"
    fi
  done
  
  log_info "Services disabled and masked"
}

# Prompt for reboot
prompt_reboot() {
  echo ""
  log_warn "=========================================="
  log_warn "REBOOT REQUIRED"
  log_warn "=========================================="
  echo ""
  log_info "Configuration complete. You must reboot your Raspberry Pi for changes to take effect."
  log_info "You cannot continue with the installation until after rebooting."
  echo ""
  echo -e "${YELLOW}Please run: sudo reboot${NC}"
  echo ""
}

# Main execution
main() {
  log_info "Starting Raspberry Pi preparation"
  echo ""
  
  check_root
  check_os_version
  check_raspberry_pi
  
  # Validate hardware (will exit if not Pi 4 or 5)
  local pi_version
  pi_version=$(detect_pi_version)
  log_info "Validated Raspberry Pi $pi_version"
  
  echo ""
  log_info "Modifying boot configuration files"
  modify_cmdline
  modify_config
  
  echo ""
  log_info "Configuring system services"
  disable_services
  
  echo ""
  prompt_reboot
}

main "$@"
