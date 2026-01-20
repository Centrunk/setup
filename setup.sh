#!/usr/bin/env bash
#
# setup.sh - Interactive setup menu for Raspberry Pi DVMHost installation
#
# This script provides a menu-driven interface to configure and install
# DVMHost on Raspberry Pi systems. It checks the status of various setup
# tasks and allows running or re-running individual setup scripts.
#
# Usage: sudo ./setup.sh
#
# Requirements:
# - Raspberry Pi OS 12 or 13
# - Must be run as root
# - Internet connection required

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Symbols
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"

# GitHub repository base URL
GITHUB_RAW_URL="https://raw.githubusercontent.com/Centrunk/setup/master"

# Determine script directory
# If running from stdin (curl pipe), use temp directory
if [ -t 0 ]; then
  # Running from terminal (local file)
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TEMP_MODE=false
else
  # Running from pipe (curl)
  SCRIPT_DIR="/tmp/centrunk-setup-$$"
  TEMP_MODE=true
  mkdir -p "$SCRIPT_DIR"
fi

# Check if running as root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root (use sudo)"
    exit 1
  fi
}

# Download script (always re-download with cache-busting)
ensure_script() {
  local script_name=$1
  local script_path="$SCRIPT_DIR/$script_name"
  
  echo -e "${BLUE}Downloading $script_name...${NC}"
  if ! curl -fsSL -o "$script_path" "$GITHUB_RAW_URL/$script_name?$(date +%s)"; then
    echo -e "${RED}Failed to download $script_name${NC}"
    return 1
  fi
  chmod +x "$script_path"
  return 0
}

# Cleanup temp directory on exit
cleanup_temp() {
  if [ "$TEMP_MODE" = true ] && [ -d "$SCRIPT_DIR" ]; then
    rm -rf "$SCRIPT_DIR"
  fi
}

# Set trap for cleanup
trap cleanup_temp EXIT

# Check OS version
check_os() {
  if [ ! -f /etc/os-release ]; then
    return 1
  fi
  
  local version_id
  version_id=$(grep "^VERSION_ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
  
  if [ "$version_id" = "12" ] || [ "$version_id" = "13" ]; then
    return 0
  fi
  return 1
}

# Check if running on Raspberry Pi 4 or 5
check_pi_model() {
  if [ ! -f /proc/device-tree/model ]; then
    return 1
  fi
  
  local model
  model=$(tr -d '\0' < /proc/device-tree/model)
  
  if [[ "$model" =~ "Raspberry Pi 4" ]] || [[ "$model" =~ "Raspberry Pi 5" ]]; then
    return 0
  fi
  return 1
}

# Check if serial console is disabled
check_serial_console() {
  local cmdline_file="/boot/firmware/cmdline.txt"
  
  if [ ! -f "$cmdline_file" ]; then
    return 2  # File doesn't exist
  fi
  
  if grep -q "console=serial0,115200" "$cmdline_file"; then
    return 1  # Serial console enabled
  fi
  return 0  # Serial console disabled
}

# Check if Bluetooth is disabled
check_bluetooth_disabled() {
  local config_file="/boot/firmware/config.txt"
  
  if [ ! -f "$config_file" ]; then
    return 2  # File doesn't exist
  fi
  
  if grep -q "dtoverlay=disable-bt" "$config_file"; then
    return 0  # Bluetooth disabled
  fi
  return 1  # Bluetooth not disabled
}

# Check if UART is configured (Pi 5 only)
check_uart_config() {
  local config_file="/boot/firmware/config.txt"
  
  if [ ! -f "$config_file" ]; then
    return 2  # File doesn't exist
  fi
  
  if grep -q "enable_uart=1" "$config_file" && grep -q "dtoverlay=uart0,ctsrts" "$config_file"; then
    return 0  # UART configured
  fi
  return 1  # UART not configured
}

# Check if Bluetooth services are disabled
check_bluetooth_services() {
  local services=(
    "serial-getty@ttyAMA0.service"
    "hciuart.service"
    "bluealsa.service"
    "bluetooth.service"
  )
  
  for service in "${services[@]}"; do
    if systemctl is-enabled "$service" &>/dev/null; then
      return 1  # At least one service is enabled
    fi
  done
  return 0  # All services disabled
}

# Check if packages are installed
check_packages_installed() {
  local packages=(
    git
    nano
    stm32flash
    xz-utils
  )
  
  for pkg in "${packages[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
      return 1  # Package not installed
    fi
  done
  return 0  # All packages installed
}

# Check if NetBird is installed
check_netbird_installed() {
  if command -v netbird &> /dev/null; then
    return 0
  fi
  return 1
}

# Check if directories exist
check_directories() {
  local dirs=(
    "/var/log/centrunk"
    "/opt/centrunk"
    "/opt/centrunk/configs"
  )
  
  for dir in "${dirs[@]}"; do
    if [ ! -d "$dir" ]; then
      return 1
    fi
  done
  return 0
}

# Check if DVMHost is installed
check_dvmhost_installed() {
  if [ -d "/opt/centrunk/dvmhost" ] && [ -n "$(ls -A /opt/centrunk/dvmhost)" ]; then
    return 0
  fi
  return 1
}

# Display status with symbol
display_status() {
  local status=$1
  case $status in
    0) echo -e "$CHECK" ;;
    1) echo -e "$CROSS" ;;
    2) echo -e "$WARN" ;;
    *) echo -e "$CROSS" ;;
  esac
}

# Clear screen and show header
show_header() {
  clear
  echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}         ${BLUE}Raspberry Pi DVMHost Setup Menu${NC}                       ${CYAN}║${NC}"
  echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

# Show status overview
show_status() {
  show_header
  
  echo -e "${YELLOW}System Requirements:${NC}"
  echo -ne "  OS Version (Pi OS 12/13): "
  check_os && echo -e "$CHECK" || echo -e "$CROSS"
  echo -ne "  Raspberry Pi Model (4/5): "
  check_pi_model && echo -e "$CHECK" || echo -e "$CROSS"
  echo ""
  
  echo -e "${YELLOW}1. Pi Preparation (prepare_pi.sh):${NC}"
  echo -ne "  Serial console disabled: "
  check_serial_console
  display_status $?
  echo -ne "  Bluetooth disabled: "
  check_bluetooth_disabled
  display_status $?
  
  if check_pi_model && [[ "$(tr -d '\0' < /proc/device-tree/model)" =~ "Raspberry Pi 5" ]]; then
    echo -ne "  UART configured: "
    check_uart_config
    display_status $?
  fi
  
  echo -ne "  Bluetooth services disabled: "
  check_bluetooth_services
  display_status $?
  echo ""
  
  echo -e "${YELLOW}2. DVMHost Installation (install_dvmhost.sh):${NC}"
  echo -n "  Required packages installed: "
  check_packages_installed && echo -e "$CHECK" || echo -e "$CROSS"
  echo -n "  NetBird installed: "
  check_netbird_installed && echo -e "$CHECK" || echo -e "$CROSS"
  echo -n "  Directories created: "
  check_directories && echo -e "$CHECK" || echo -e "$CROSS"
  echo -n "  DVMHost binaries installed: "
  check_dvmhost_installed && echo -e "$CHECK" || echo -e "$CROSS"
  echo ""
}

# Run prepare_pi.sh script
run_prepare_pi() {
  show_header
  echo -e "${BLUE}Running Pi Preparation Script...${NC}"
  echo ""
  
  if ! ensure_script "prepare_pi.sh"; then
    echo -e "${RED}Error: Could not get prepare_pi.sh${NC}"
    read -p "Press Enter to continue..." </dev/tty
    return
  fi
  
  bash "$SCRIPT_DIR/prepare_pi.sh"
  local exit_code=$?
  
  echo ""
  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}Pi preparation completed successfully${NC}"
  else
    echo -e "${RED}Pi preparation failed with exit code: $exit_code${NC}"
  fi
  echo ""
  read -p "Press Enter to continue..." </dev/tty
}

# Run install_dvmhost.sh script
run_install_dvmhost() {
  show_header
  echo -e "${BLUE}Running DVMHost Installation Script...${NC}"
  echo ""
  
  if ! ensure_script "install_dvmhost.sh"; then
    echo -e "${RED}Error: Could not get install_dvmhost.sh${NC}"
    read -p "Press Enter to continue..." </dev/tty
    return
  fi
  
  bash "$SCRIPT_DIR/install_dvmhost.sh"
  local exit_code=$?
  
  echo ""
  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}DVMHost installation completed successfully${NC}"
  else
    echo -e "${RED}DVMHost installation failed with exit code: $exit_code${NC}"
  fi
  echo ""
  read -p "Press Enter to continue..." </dev/tty
}

# Run all setup scripts in order
run_all() {
  show_header
  echo -e "${BLUE}Running All Setup Scripts...${NC}"
  echo ""
  
  # Ensure both scripts are available
  if ! ensure_script "prepare_pi.sh" || ! ensure_script "install_dvmhost.sh"; then
    echo -e "${RED}Error: Could not download required scripts${NC}"
    read -p "Press Enter to continue..." </dev/tty
    return
  fi
  
  echo -e "${YELLOW}Step 1: Pi Preparation${NC}"
  echo ""
  bash "$SCRIPT_DIR/prepare_pi.sh"
  local prepare_exit=$?
  
  if [ $prepare_exit -ne 0 ]; then
    echo -e "${RED}Pi preparation failed. Aborting full setup.${NC}"
    read -p "Press Enter to continue..." </dev/tty
    return
  fi
  
  echo ""
  echo -e "${YELLOW}Step 2: DVMHost Installation${NC}"
  echo ""
  bash "$SCRIPT_DIR/install_dvmhost.sh"
  local install_exit=$?
  
  echo ""
  if [ $install_exit -eq 0 ]; then
    echo -e "${GREEN}All setup completed successfully!${NC}"
  else
    echo -e "${RED}DVMHost installation failed${NC}"
  fi
  echo ""
  read -p "Press Enter to continue..." </dev/tty
}

# Show main menu
show_menu() {
  show_status
  
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}Options:${NC}"
  echo "  1) Run Pi Preparation Script (prepare_pi.sh)"
  echo "  2) Run DVMHost Installation Script (install_dvmhost.sh)"
  echo "  3) Run All Setup Scripts"
  echo "  4) Refresh Status"
  echo "  q) Quit"
  echo ""
  echo -ne "${BLUE}Select an option:${NC} "
}

# Main menu loop
main() {
  check_root
  
  while true; do
    show_menu
    read -r choice </dev/tty || choice=""
    
    case "${choice:-}" in
      1)
        run_prepare_pi
        ;;
      2)
        run_install_dvmhost
        ;;
      3)
        run_all
        ;;
      4)
        # Just refresh - the loop will redraw
        continue
        ;;
      q|Q)
        echo ""
        echo -e "${GREEN}Exiting setup menu. Goodbye!${NC}"
        echo ""
        exit 0
        ;;
      *)
        echo ""
        echo -e "${RED}Invalid option. Please try again.${NC}"
        sleep 2
        ;;
    esac
  done
}

main "$@"
