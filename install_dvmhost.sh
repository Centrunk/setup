#!/usr/bin/env bash
#
# install_dvmhost.sh - Install DVMHost and dependencies
#
# This script installs DVMHost from precompiled binaries and all
# required dependencies on Raspberry Pi OS.
#
# Usage: sudo ./install_dvmhost.sh
#
# Requirements:
# - Raspberry Pi OS 12 or 13
# - Must be run as root
# - Internet connection required

set -euo pipefail

# Constants
DVMHOST_BINARY_URL="https://github.com/Centrunk/dvmbins/releases/latest/download/dvmhost-arm64.tar.xz"
DVMHOST_DIR="/opt/centrunk/dvmhost"
CENTRUNK_LOG_DIR="/var/log/centrunk"
CENTRUNK_OPT_DIR="/opt/centrunk"
CENTRUNK_CONFIG_DIR="/opt/centrunk/configs"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
  echo -e "${BLUE}[STEP]${NC} $1"
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

# Check if running on Raspberry Pi (must be Pi 4 or 5)
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
  
  # Validate it's Pi 4 or 5
  if [[ ! "$model" =~ "Raspberry Pi 4" ]] && [[ ! "$model" =~ "Raspberry Pi 5" ]]; then
    log_error "Unsupported Raspberry Pi model: $model"
    log_error "This script only supports Raspberry Pi 4 and Raspberry Pi 5"
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

# Update package lists
update_packages() {
  log_step "Updating package lists"
  apt-get update || {
    log_error "Failed to update package lists"
    exit 1
  }
  log_info "Package lists updated"
}

# Upgrade existing packages
upgrade_packages() {
  log_step "Upgrading existing packages"
  apt-get upgrade -y || {
    log_error "Failed to upgrade packages"
    exit 1
  }
  log_info "Packages upgraded"
}

# Install required dependencies
install_dependencies() {
  log_step "Installing required dependencies"
  
  local packages=(
    git
    nano
    stm32flash
  )
  
  log_info "Installing: ${packages[*]}"
  
  apt-get install -y "${packages[@]}" || {
    log_error "Failed to install dependencies"
    exit 1
  }
  
  log_info "Dependencies installed successfully"
}

# Install NetBird
install_netbird() {
  log_step "Installing NetBird"
  
  if command -v netbird &> /dev/null; then
    log_info "NetBird is already installed ($(netbird version))"
    return
  fi
  
  log_info "Downloading and executing NetBird installer"
  curl -fsSL https://pkgs.netbird.io/install.sh | sh || {
    log_error "Failed to install NetBird"
    exit 1
  }
  
  log_info "NetBird installed successfully"
}

# Create required directories
create_directories() {
  log_step "Creating required directories"
  
  local dirs=(
    "$CENTRUNK_LOG_DIR"
    "$CENTRUNK_OPT_DIR"
    "$CENTRUNK_CONFIG_DIR"
  )
  
  for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
      log_info "Directory already exists: $dir"
    else
      log_info "Creating directory: $dir"
      mkdir -p "$dir" || {
        log_error "Failed to create directory: $dir"
        exit 1
      }
    fi
  done
  
  log_info "Directories created successfully"
}

# Download and extract DVMHost binaries
download_dvmhost() {
  log_step "Downloading DVMHost precompiled binaries"
  
  if [ -d "$DVMHOST_DIR" ]; then
    log_warn "DVMHost directory already exists at $DVMHOST_DIR"
    read -p "Do you want to remove it and reinstall? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      log_info "Removing existing directory"
      rm -rf "$DVMHOST_DIR"
    else
      log_info "Skipping download, using existing installation"
      return
    fi
  fi
  
  log_info "Creating DVMHost directory"
  mkdir -p "$DVMHOST_DIR" || {
    log_error "Failed to create directory: $DVMHOST_DIR"
    exit 1
  }
  
  local temp_file="/tmp/dvmhost-arm64.tar.xz"
  
  log_info "Downloading from $DVMHOST_BINARY_URL"
  curl -fsSL -o "$temp_file" "$DVMHOST_BINARY_URL" || {
    log_error "Failed to download DVMHost binaries"
    exit 1
  }
  
  log_info "Extracting binaries to $DVMHOST_DIR"
  tar -xf "$temp_file" -C "$DVMHOST_DIR" || {
    log_error "Failed to extract DVMHost binaries"
    rm -f "$temp_file"
    exit 1
  }
  
  log_info "Cleaning up temporary files"
  rm -f "$temp_file"
  
  log_info "DVMHost binaries installed successfully"
}

# Display completion message
display_completion() {
  echo ""
  log_info "=========================================="
  log_info "DVMHost Installation Complete!"
  log_info "=========================================="
  echo ""
  log_info "Installation summary:"
  log_info "  - Installation directory: $DVMHOST_DIR"
  log_info "  - Log directory: $CENTRUNK_LOG_DIR"
  log_info "  - Config directory: $CENTRUNK_CONFIG_DIR"
  echo ""
  log_info "Next steps:"
  log_info "  1. Configure DVMHost in $CENTRUNK_CONFIG_DIR"
  log_info "  2. Review the documentation at https://github.com/DVMProject/dvmhost"
  echo ""
}

# Main execution
main() {
  log_info "Starting DVMHost installation"
  echo ""
  
  check_root
  check_os_version
  check_raspberry_pi
  
  echo ""
  
  # Update and upgrade system
  update_packages
  upgrade_packages
  
  echo ""
  
  # Install dependencies
  install_dependencies
  
  echo ""
  
  # Install NetBird
  install_netbird
  
  echo ""
  
  # Create directories
  create_directories
  
  echo ""
  
  # Download and extract DVMHost
  download_dvmhost
  
  # Display completion message
  display_completion
}

main "$@"
