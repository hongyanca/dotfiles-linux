#!/usr/bin/env bash
set -Eeuo pipefail

# Ubuntu Interactive Netplan Configuration
# Usage: ./config-ubuntu-ip.sh

CONFIG="/etc/netplan/50-cloud-init.yaml"
BACKUP=""
TMP=""
DEFAULT_GATEWAY_SET=false

# Automatically elevate privileges
if [[ $(id -u) -ne 0 ]]; then
  echo "Administrator privileges required."
  echo "Requesting sudo access..."
  exec sudo -- /bin/bash "$0" "$@"
fi

# Check dependencies
for cmd in netplan python3 ip; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Required command not found: $cmd"
    exit 1
  fi
done

# Normalize yes/no/true/false
ask_bool() {
  local prompt="$1"
  local answer

  while true; do
    read -r -p "$prompt (yes/no): " answer

    case "${answer,,}" in
    yes | y | true | t | 1)
      echo "true"
      return
      ;;
    no | n | false | f | 0)
      echo "false"
      return
      ;;
    *)
      echo "Enter yes, no, true, or false." >&2
      ;;
    esac
  done
}

# Validate IPv4 address
valid_ipv4() {
  python3 - "$1" <<'PY'
import ipaddress
import sys

try:
    ipaddress.IPv4Address(sys.argv[1])
except ValueError:
    sys.exit(1)
PY
}

# Validate IPv4 CIDR
valid_cidr() {
  python3 - "$1" <<'PY'
import ipaddress
import sys

try:
    ipaddress.IPv4Interface(sys.argv[1])
except ValueError:
    sys.exit(1)
PY
}

# Ask for IPv4 address
ask_ipv4() {
  local prompt="$1"
  local value

  while true; do
    read -r -p "$prompt: " value

    if valid_ipv4 "$value"; then
      printf '%s\n' "$value"
      return
    fi

    echo "Invalid IPv4 address." >&2
  done
}

# Ask for IPv4 address with optional CIDR prefix
# Defaults to /24 when no prefix is provided
ask_cidr() {
  local value

  while true; do
    read -r -p \
      "Static IPv4 address (default /24): " value

    # Append /24 if no prefix was entered
    if [[ "$value" != */* ]]; then
      value="${value}/24"
    fi

    # Validate IPv4 address and prefix
    if valid_cidr "$value"; then
      printf '%s\n' "$value"
      return
    fi

    echo "Invalid IPv4 address or CIDR prefix." >&2
    echo "Examples: 10.56.1.31 or 10.56.1.31/24" >&2
  done
}

# Restore original configuration
restore_backup() {
  if [[ -n "$BACKUP" && -f "$BACKUP" ]]; then
    cp -p "$BACKUP" "$CONFIG"
    echo "Original configuration restored."
  else
    rm -f "$CONFIG"
    echo "New configuration file removed."
  fi
}

cleanup() {
  if [[ -n "$TMP" ]]; then
    rm -f "$TMP"
  fi
}

trap cleanup EXIT

echo "======================================"
echo " Ubuntu Network Configuration"
echo "======================================"

# Detect Ethernet interfaces
mapfile -t INTERFACES < <(
  for path in /sys/class/net/*; do
    iface="${path##*/}"

    [[ "$iface" == "lo" ]] && continue
    [[ -e "$path/device" ]] || continue
    [[ "$(cat "$path/type")" == "1" ]] || continue

    echo "$iface"
  done | sort
)

if [[ ${#INTERFACES[@]} -eq 0 ]]; then
  echo "Error: No Ethernet interfaces detected."
  exit 1
fi

echo
echo "Detected Ethernet interfaces:"
printf '  - %s\n' "${INTERFACES[@]}"

echo
echo "Configuration file: $CONFIG"

# Create temporary YAML
TMP=$(mktemp /etc/netplan/.netplan-config.XXXXXX)
chmod 600 "$TMP"

cat >"$TMP" <<EOF
network:
  version: 2
  ethernets:
EOF

CONFIGURED_COUNT=0

# Configure each interface
for IFACE in "${INTERFACES[@]}"; do
  echo
  echo "--------------------------------------"
  echo " Interface: $IFACE"
  echo "--------------------------------------"

  CONFIGURE=$(ask_bool "Configure $IFACE?")

  if [[ "$CONFIGURE" != "true" ]]; then
    echo "Skipping $IFACE"
    continue
  fi

  ((CONFIGURED_COUNT += 1))

  DHCP4=$(ask_bool "Enable DHCPv4?")
  DHCP6=$(ask_bool "Enable DHCPv6?")

  {
    echo "    $IFACE:"
    echo "      dhcp4: $DHCP4"
    echo "      dhcp6: $DHCP6"
  } >>"$TMP"

  if [[ "$DHCP4" == "true" ]]; then
    echo "      dhcp-identifier: mac" >>"$TMP"
  else
    echo
    echo "Static IPv4 configuration"

    STATIC_IP=$(ask_cidr)

    cat >>"$TMP" <<EOF
      addresses:
        - $STATIC_IP
EOF

    # Optional default gateway
    if [[ "$DEFAULT_GATEWAY_SET" == "false" ]]; then
      USE_GATEWAY=$(ask_bool "Configure default IPv4 gateway?")

      if [[ "$USE_GATEWAY" == "true" ]]; then
        GATEWAY=$(ask_ipv4 "Default IPv4 gateway")

        cat >>"$TMP" <<EOF
      routes:
        - to: default
          via: $GATEWAY
EOF
        DEFAULT_GATEWAY_SET=true
      fi
    else
      echo "Default IPv4 gateway already configured."
    fi

    # Optional DNS configuration
    USE_DNS=$(ask_bool "Configure DNS servers?")

    if [[ "$USE_DNS" == "true" ]]; then
      echo
      echo "Enter DNS servers separated by commas."

      while true; do
        read -r -p \
          "DNS servers [1.1.1.1,8.8.8.8]: " DNS

        DNS=${DNS:-1.1.1.1,8.8.8.8}
        IFS=',' read -r -a DNS_ARRAY <<<"$DNS"

        VALID_DNS=true
        CLEAN_DNS=()

        for SERVER in "${DNS_ARRAY[@]}"; do
          SERVER="${SERVER//[[:space:]]/}"

          if ! valid_ipv4 "$SERVER"; then
            echo "Invalid DNS server: $SERVER"
            VALID_DNS=false
            break
          fi

          CLEAN_DNS+=("$SERVER")
        done

        if [[ "$VALID_DNS" == "true" ]]; then
          break
        fi
      done

      {
        echo "      nameservers:"
        echo "        addresses:"

        for SERVER in "${CLEAN_DNS[@]}"; do
          echo "          - $SERVER"
        done
      } >>"$TMP"
    fi
  fi
done

if [[ "$CONFIGURED_COUNT" -eq 0 ]]; then
  echo
  echo "No interfaces selected. Nothing changed."
  exit 0
fi

echo
echo "======================================"
echo " Generated Netplan Configuration"
echo "======================================"
cat "$TMP"

echo
CONFIRM=$(ask_bool "Save and apply configuration?")

if [[ "$CONFIRM" != "true" ]]; then
  echo "Configuration cancelled."
  exit 0
fi

# Backup original configuration
if [[ -f "$CONFIG" ]]; then
  BACKUP="${CONFIG}.bak.$(date +%Y%m%d-%H%M%S)"
  cp -p "$CONFIG" "$BACKUP"
  echo "Backup created: $BACKUP"
fi

# Install new configuration
install -m 600 "$TMP" "$CONFIG"

echo
echo "Validating Netplan configuration..."

if ! netplan generate; then
  echo "ERROR: Netplan validation failed."
  restore_backup
  exit 1
fi

echo "Netplan validation passed."

echo
echo "Applying network configuration..."
echo "WARNING: Network connectivity may be interrupted."

# netplan try provides rollback if not confirmed
if netplan try --timeout 120; then
  echo
  echo "Network configuration confirmed."
else
  echo
  echo "Netplan configuration was not confirmed."
  echo "Restoring original configuration file..."
  restore_backup

  if ! netplan generate || ! netplan apply; then
    echo "WARNING: Could not reapply original configuration."
    exit 1
  fi

  exit 1
fi

echo
echo "======================================"
echo " Current Network Configuration"
echo "======================================"

echo
echo "IPv4 addresses:"
ip -br -4 address show

echo
echo "IPv6 addresses:"
ip -br -6 address show

echo
echo "IPv4 routes:"
ip -4 route show

echo
echo "DNS configuration:"
if command -v resolvectl >/dev/null 2>&1; then
  resolvectl dns || true
else
  cat /etc/resolv.conf
fi

echo
echo "Configuration complete."
