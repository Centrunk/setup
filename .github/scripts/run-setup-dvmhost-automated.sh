#!/usr/bin/env bash
#
# run-setup-dvmhost-automated.sh - Run setup_dvmhost.sh with automated input
#
# This script automates the setup_dvmhost.sh process for testing
# by providing pre-defined answers to all prompts.

set -euo pipefail

SITE_TYPE="$1"

# Test values for placeholders
TEST_SITE_NAME="TestSite"
TEST_SITE_ID="12345"
TEST_PEER_ID="67890"
TEST_NETWORK_ID="54321"
TEST_SYSTEM_ID="11111"
TEST_COLOR_CODE="1"
TEST_CC_CHANNEL_ID="100"
TEST_CC_FREQUENCY="851.0125"
TEST_VC_CHANNEL_ID="101"
TEST_VC_FREQUENCY="851.0375"
TEST_FREQUENCY="453.5000"
TEST_TX_POWER="10"
TEST_CHANNEL_SPACING="12.5"

if [ "$SITE_TYPE" = "CC/VC" ]; then
  # Provide input for CC/VC configuration
  {
    echo "1"  # Select CC/VC option
    echo "$TEST_SITE_NAME"
    echo "$TEST_SITE_ID"
    echo "$TEST_CC_CHANNEL_ID"
    echo "$TEST_CC_FREQUENCY"
    echo "$TEST_PEER_ID"
    echo "$TEST_NETWORK_ID"
    echo "$TEST_SYSTEM_ID"
    echo "$TEST_COLOR_CODE"
    # Repeat for VC config (same values reused)
    echo "$TEST_SITE_NAME"
    echo "$TEST_SITE_ID"
    echo "$TEST_VC_CHANNEL_ID"
    echo "$TEST_VC_FREQUENCY"
    echo "$TEST_PEER_ID"
    echo "$TEST_NETWORK_ID"
    echo "$TEST_SYSTEM_ID"
    echo "$TEST_COLOR_CODE"
  } | ./setup_dvmhost.sh
else
  # Provide input for Conventional configuration
  {
    echo "2"  # Select Conventional option
    echo "$TEST_SITE_NAME"
    echo "$TEST_FREQUENCY"
    echo "$TEST_PEER_ID"
    echo "$TEST_NETWORK_ID"
    echo "$TEST_TX_POWER"
    echo "$TEST_CHANNEL_SPACING"
  } | ./setup_dvmhost.sh
fi

exit $?
