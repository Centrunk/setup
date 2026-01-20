#!/usr/bin/env bash
#
# setup_dvmhost.sh - Configure DVMHost with user input
#
# This script configures DVMHost by:
# - Prompting for site type (CC/VC or Conventional)
# - Downloading appropriate config templates
# - Collecting user input for all placeholders
# - Writing final configuration files
#
# Usage: sudo ./setup_dvmhost.sh
#
# Requirements:
# - Raspberry Pi OS 12 or 13
# - Must be run as root
# - DVMHost must be installed (run install_dvmhost.sh first)
# - Internet connection required

set -euo pipefail

# Constants
CENTRUNK_CONFIG_DIR="/opt/centrunk/configs"
TEMPLATE_BASE_URL="https://raw.githubusercontent.com/Centrunk/centrunk-config-generator/templates"
CC_CONFIG_URL="${TEMPLATE_BASE_URL}/configCC.yml"
VC_CONFIG_URL="${TEMPLATE_BASE_URL}/configVC.yml"
CONVENTIONAL_CONFIG_URL="${TEMPLATE_BASE_URL}/configCONVENTIONAL.yml"

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
  else
    if [ ! -f /etc/os-release ]; then
      log_error "Cannot determine OS version: /etc/os-release not found"
      return 1
    fi
    
    version_id=$(grep ^VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')
  fi
  
  if [ "$version_id" != "12" ] && [ "$version_id" != "13" ]; then
    log_error "Unsupported OS version: $version_id"
    log_error "This script only supports Raspberry Pi OS 12 or 13"
    return 1
  fi
  
  log_info "Detected Raspberry Pi OS version: $version_id"
}

# Check if running as root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    log_error "Usage: sudo $0"
    return 1
  fi
}

# Check if DVMHost is installed
check_dvmhost_installed() {
  log_step "Checking if DVMHost is installed..."
  
  if [ ! -d "$CENTRUNK_CONFIG_DIR" ]; then
    log_error "DVMHost config directory not found: $CENTRUNK_CONFIG_DIR"
    log_error "Please run install_dvmhost.sh first"
    return 1
  fi
  
  log_info "DVMHost installation verified"
}

# Prompt user for site type
prompt_site_type() {
  log_step "Selecting site type..."
  echo ""
  echo "Please select your site type:"
  echo "  1) CC/VC (Control Channel / Voice Channel)"
  echo "  2) Conventional"
  echo ""
  
  local choice
  while true; do
    read -r -p "Enter choice (1 or 2): " choice </dev/tty || choice=""
    case $choice in
      1)
        echo "CC/VC"
        return 0
        ;;
      2)
        echo "CONVENTIONAL"
        return 0
        ;;
      *)
        log_warn "Invalid choice. Please enter 1 or 2."
        ;;
    esac
  done
}

# Download config template
download_template() {
  local url="$1"
  local output_file="$2"
  
  log_info "Downloading template from $url..."
  
  if ! curl -fsSL "$url" -o "$output_file"; then
    log_error "Failed to download template from $url"
    return 1
  fi
  
  log_info "Template downloaded successfully"
}

# Extract placeholders from config file
extract_placeholders() {
  local config_file="$1"
  
  # Find all ${PLACEHOLDER} values and return unique sorted list
  grep -oP '\$\{[^}]+\}' "$config_file" | sort -u | sed 's/\${\(.*\)}/\1/'
}

# Prompt user for placeholder value
prompt_for_placeholder() {
  local placeholder="$1"
  local value
  
  # Convert placeholder name to more readable format
  local display_name=$(echo "$placeholder" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++) $i=tolower($i); print}')
  
  local value
  echo ""
  read -r -p "Enter value for ${display_name}: " value </dev/tty || value=""
  
  # Validate that value is not empty
  while [ -z "$value" ]; do
    log_warn "Value cannot be empty"
    read -r -p "Enter value for ${display_name}: " value </dev/tty || value=""
  done
  
  echo "$value"
}

# Replace placeholders in config file
replace_placeholders() {
  local config_file="$1"
  shift
  local -n replacements=$1
  
  local temp_file="${config_file}.tmp"
  cp "$config_file" "$temp_file"
  
  for placeholder in "${!replacements[@]}"; do
    local value="${replacements[$placeholder]}"
    # Escape forward slashes in value for sed
    local escaped_value=$(echo "$value" | sed 's/[\/&]/\\&/g')
    sed -i "s/\${${placeholder}}/${escaped_value}/g" "$temp_file"
  done
  
  mv "$temp_file" "$config_file"
}

# Process config file
process_config_file() {
  local template_url="$1"
  local output_file="$2"
  local temp_file="${output_file}.download"
  
  # Download template
  download_template "$template_url" "$temp_file" || return 1
  
  # Extract placeholders
  log_step "Collecting configuration values for $(basename $output_file)..."
  local placeholders=($(extract_placeholders "$temp_file"))
  
  if [ ${#placeholders[@]} -eq 0 ]; then
    log_info "No placeholders found in template"
    mv "$temp_file" "$output_file"
    return 0
  fi
  
  # Collect values for all placeholders
  declare -A placeholder_values
  for placeholder in "${placeholders[@]}"; do
    placeholder_values[$placeholder]=$(prompt_for_placeholder "$placeholder")
  done
  
  # Replace placeholders
  log_info "Writing configuration file..."
  replace_placeholders "$temp_file" placeholder_values
  
  # Move to final location
  mv "$temp_file" "$output_file"
  
  log_info "Configuration file created: $output_file"
}

# Main setup function
main() {
  log_info "Starting DVMHost configuration..."
  echo ""
  
  # Check prerequisites
  check_os_version || exit 1
  check_root || exit 1
  check_dvmhost_installed || exit 1
  
  # Get site type
  local site_type=$(prompt_site_type)
  
  echo ""
  log_info "Configuring for site type: $site_type"
  echo ""
  
  # Process config files based on site type
  case "$site_type" in
    "CC/VC")
      process_config_file "$CC_CONFIG_URL" "${CENTRUNK_CONFIG_DIR}/configCC.yml" || exit 1
      process_config_file "$VC_CONFIG_URL" "${CENTRUNK_CONFIG_DIR}/configVC.yml" || exit 1
      ;;
    "CONVENTIONAL")
      process_config_file "$CONVENTIONAL_CONFIG_URL" "${CENTRUNK_CONFIG_DIR}/configCONVENTIONAL.yml" || exit 1
      ;;
    *)
      log_error "Invalid site type: $site_type"
      exit 1
      ;;
  esac
  
  echo ""
  log_info "✓ DVMHost configuration completed successfully!"
  echo ""
  log_info "Configuration files written to: $CENTRUNK_CONFIG_DIR"
  
  # List created files
  echo ""
  log_info "Created configuration files:"
  ls -lh "$CENTRUNK_CONFIG_DIR"/*.yml 2>/dev/null || true
  
  echo ""
}

# Run main function
main "$@"
