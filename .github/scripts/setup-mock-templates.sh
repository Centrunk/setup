#!/usr/bin/env bash
#
# setup-mock-templates.sh - Mock config template server
#
# This script creates a mock curl that returns test config templates
# instead of downloading from GitHub.

set -euo pipefail

# Create mock template files
mkdir -p /tmp/mock-templates

# Create configCC.yml template
cat > /tmp/mock-templates/configCC.yml << 'EOF'
# Control Channel Configuration
site_name: ${SITE_NAME}
site_id: ${SITE_ID}
channel_id: ${CC_CHANNEL_ID}
frequency: ${CC_FREQUENCY}
peer_id: ${PEER_ID}
network_id: ${NETWORK_ID}
system_id: ${SYSTEM_ID}
color_code: ${COLOR_CODE}
EOF

# Create configVC.yml template
cat > /tmp/mock-templates/configVC.yml << 'EOF'
# Voice Channel Configuration
site_name: ${SITE_NAME}
site_id: ${SITE_ID}
channel_id: ${VC_CHANNEL_ID}
frequency: ${VC_FREQUENCY}
peer_id: ${PEER_ID}
network_id: ${NETWORK_ID}
system_id: ${SYSTEM_ID}
color_code: ${COLOR_CODE}
EOF

# Create configCONVENTIONAL.yml template
cat > /tmp/mock-templates/configCONVENTIONAL.yml << 'EOF'
# Conventional Configuration
site_name: ${SITE_NAME}
frequency: ${FREQUENCY}
peer_id: ${PEER_ID}
network_id: ${NETWORK_ID}
tx_power: ${TX_POWER}
channel_spacing: ${CHANNEL_SPACING}
EOF

# Backup original curl
if [ -f /usr/bin/curl ] && [ ! -f /usr/bin/curl.original ]; then
  cp /usr/bin/curl /usr/bin/curl.original
fi

# Create mock curl script
cat > /usr/bin/curl << 'CURL_SCRIPT'
#!/usr/bin/env bash

# Parse arguments to find output file and URL
output_file=""
url=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -o)
      output_file="$2"
      shift 2
      ;;
    -fsSL|-fsS|-fL)
      shift
      ;;
    http*|https*)
      url="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Determine which template to return based on URL
if [[ "$url" =~ configCC\.yml ]]; then
  template="/tmp/mock-templates/configCC.yml"
elif [[ "$url" =~ configVC\.yml ]]; then
  template="/tmp/mock-templates/configVC.yml"
elif [[ "$url" =~ configCONVENTIONAL\.yml ]]; then
  template="/tmp/mock-templates/configCONVENTIONAL.yml"
else
  # For non-template URLs, use original curl
  /usr/bin/curl.original "$@"
  exit $?
fi

# Return the mock template
if [ -n "$output_file" ]; then
  cp "$template" "$output_file"
else
  cat "$template"
fi

exit 0
CURL_SCRIPT

chmod +x /usr/bin/curl

echo "✓ Mock template server configured"
