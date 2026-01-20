# AI Coding Agent Instructions

## Project Overview
This is a setup scripts repository for automating environment configuration and tooling installation.

## Project Structure
- Root directory contains setup scripts organized by purpose
- Scripts should be idempotent (safe to run multiple times)
- Runs on Linux, specifically Raspberry Pi OS 12 and Raspbery Pi OS 13.
- Runs on Raspberry Pi 4 and Raspberry Pi 5 only.
- Scripts must error out if on an unsupported OS or version.

## Coding Conventions
- 2 spaces for indentation
- Use `snake_case` for filenames and variables
- Variables should be uppercase with underscores for constants (e.g., `INSTALL_DIR`)

### Script Organization
- Use descriptive filenames: `install-<tool>.sh`, `configure-<feature>.sh`
- Include usage documentation at the top of each script
- Return non-zero exit codes on failures for CI/CD integration

### Bash Scripts (Unix-like)
- Start with `#!/usr/bin/env bash`
- Use `set -euo pipefail` for safety
- Check for root when required: `[ "$EUID" -ne 0 ]`

### Error Handling
- Validate prerequisites (OS version, existing installations) before making changes
- Provide clear error messages with troubleshooting hints
- Clean up partial installations on failure when possible

## CI/CD Testing
- Test in the above raspberry pi OS versions using GitHub Actions

## Development Workflow
- Test scripts in clean environments (VMs/containers) before committing
- Document any external dependencies or prerequisites in the script header
- Version-pin downloaded tools/packages when stability is critical

## Key Patterns
- **Idempotency**: Check if tool is already installed before attempting installation
- **Logging**: Output current step for debugging (`echo "Installing X..."`)
- **User Confirmation**: Prompt before destructive changes unless `--force` flag provided


## Scripts
- `prepare_pi.sh`: Runs only if it's a raspberry pi.
  - Remove `console=serial0,115200` from /boot/firmware/cmdline.txt if the file is present and the value is in it.
  - For Pi 4 and above, disable the onboard sound card by adding `dtoverlay=disable-bt` to /boot/firmware/config.txt
  - For Pi 5, add the following to the `[all]` section of /boot/firmware/config.txt:
    ```
    enable_uart=1
    dtoverlay=uart0,ctsrts
    ```
  - Disable the following services:
    - sudo systemctl disable serial-getty@ttyAMA0.service
    - sudo systemctl disable hciuart.service
    - sudo systemctl disable bluealsa.service
    - sudo systemctl disable bluetooth.service
    - sudo systemctl mask serial-getty@ttyAMA0.service
    - sudo systemctl mask hciuart.service
    - sudo systemctl mask bluealsa.service
    - sudo systemctl mask bluetooth.service
  - Then prompt the user to reboot the pi, informing them that they cannot continue until they do.


- `install_dvmhost.sh`: Updates package lists, upgrades existing packages, and installs common dependencies.
  - Install: git nano stm32flash gcc-arm-none-eabi cmake libasio-dev libncurses-dev libssl-dev
  - Run: 
    - `curl -fsSL https://pkgs.netbird.io/install.sh | sh`
    - `mkdir /var/log/centrunk/`
    - `mkdir /opt/centrunk/`
    - `mkdir /opt/centrunk/configs/`  
    - Retrieve the dvmhost-arm64.tar.xz from https://github.com/Centrunk/dvmbins and extract it to /opt/centrunk/dvmhost

## CI/CD
- Use GitHub Actions to run scripts in a Raspberry Pi OS 12 and Raspberry Pi OS 13 environment.
- Validate that scripts complete successfully and idempotently.
- Report any errors or warnings in the action logs.
