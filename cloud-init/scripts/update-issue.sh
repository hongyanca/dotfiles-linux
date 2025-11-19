#!/usr/bin/env bash

# Save this file to /usr/local/bin/update-issue.sh

{
  echo "$(cat /etc/os-release | grep "PRETTY_NAME=" | cut -d\" -f2) \n \l"
  ip -o addr show | awk '/inet / {print $2, $4}' | grep -v -E '^(lo|br-|docker)'
  echo ""
} >/etc/issue
