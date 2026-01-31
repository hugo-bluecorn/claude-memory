#!/usr/bin/env bash
# Script: get-utc-timestamp.sh
# Purpose: Output current UTC timestamp in ISO 8601 format
# Usage: bash get-utc-timestamp.sh
# Output: YYYY-MM-DDTHH:MM:SSZ (single line, no trailing content)

set -euo pipefail

# Output UTC timestamp in ISO 8601 format
date -u '+%Y-%m-%dT%H:%M:%SZ'
