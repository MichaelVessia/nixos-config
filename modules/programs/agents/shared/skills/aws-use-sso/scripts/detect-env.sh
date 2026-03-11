#!/usr/bin/env bash
# Detects the user's environment for aws-use-sso installation and usage.
# Outputs key=value pairs for the agent to parse.
set -euo pipefail

# Check if aws-use-sso is already installed
if command -v aws-use-sso &>/dev/null; then
  echo "AWS_USE_SSO_INSTALLED=true"
  echo "AWS_USE_SSO_PATH=$(command -v aws-use-sso)"
else
  echo "AWS_USE_SSO_INSTALLED=false"
  echo "AWS_USE_SSO_PATH="
fi

# Check for Nix
if command -v nix &>/dev/null; then
  echo "NIX_AVAILABLE=true"
else
  echo "NIX_AVAILABLE=false"
fi

# Check for Devbox
if command -v devbox &>/dev/null; then
  echo "DEVBOX_AVAILABLE=true"
  # Check for project-local devbox.json
  if [ -f "./devbox.json" ]; then
    echo "DEVBOX_PROJECT_LOCAL=true"
  else
    echo "DEVBOX_PROJECT_LOCAL=false"
  fi
else
  echo "DEVBOX_AVAILABLE=false"
  echo "DEVBOX_PROJECT_LOCAL=false"
fi

# Check if running on NixOS
if [ -f "/etc/NIXOS" ]; then
  echo "NIXOS=true"
else
  echo "NIXOS=false"
fi

# Check for existing AWS SSO profiles
AWS_CONFIG="${HOME}/.aws/config"
if [ -f "$AWS_CONFIG" ]; then
  echo "AWS_CONFIG_EXISTS=true"
  # Extract SSO profile names (sections with sso_start_url or sso_session)
  SSO_PROFILES=$(awk '/^\[/{name=""} /^\[profile /{name=$2} /sso_start_url|sso_session/{if(name){gsub(/\]/, "", name); print name}}' "$AWS_CONFIG" | sort -u | tr '\n' ',' | sed 's/,$//')
  echo "SSO_PROFILES=${SSO_PROFILES}"
  PROFILE_COUNT=$(echo "$SSO_PROFILES" | tr ',' '\n' | grep -c . || true)
  echo "SSO_PROFILE_COUNT=${PROFILE_COUNT}"
else
  echo "AWS_CONFIG_EXISTS=false"
  echo "SSO_PROFILES="
  echo "SSO_PROFILE_COUNT=0"
fi

# Check for existing credentials file
if [ -f "${HOME}/.aws/sso-creds.sh" ]; then
  echo "CREDS_FILE_EXISTS=true"
else
  echo "CREDS_FILE_EXISTS=false"
fi

# Check for AWS_PROFILE env var
if [ -n "${AWS_PROFILE:-}" ]; then
  echo "AWS_PROFILE_SET=true"
  echo "AWS_PROFILE_VALUE=${AWS_PROFILE}"
else
  echo "AWS_PROFILE_SET=false"
  echo "AWS_PROFILE_VALUE="
fi
