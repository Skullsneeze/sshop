#!/usr/bin/env bash

set -euo pipefail

# === Defaults & Flags ===
BREW_PREFIX=$(brew --prefix)

# Default config location installed by Homebrew
BREW_PREFIX=$(brew --prefix)
DEFAULT_CONFIG="${BREW_PREFIX}/etc/clients.yaml"
CONFIG_FILE="${SSHOP_CONFIG:-$DEFAULT_CONFIG}"
USE_DIALOG=false

# === Functions ===
print_help() {
  cat <<EOF
 _____ _____ _   _
/  ___/  ___| | | |
\ \`--.\ \`--.| |_| | ___  _ __
 \`--. \\\`--. \  _  |/ _ \| '_ \\
/\__/ /\__/ / | | | (_) | |_) |
\____/\____/\_| |_/\___/| .__/
                        | |
                        |_|

Usage: sshop [options]

Options:
  --config, -c <file>   Use a specific clients.yaml config file
  --dialog, -d          Use dialog instead of fzf
  --help, -h            Show this help message

Environment:
  SSHOP_CONFIG          Path to a custom config file (fallback if --config not used)
EOF
}

abort() {
  echo "Aborted."
  exit 1
}

# === Parse arguments ===

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config|-c)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --dialog|-d)
      USE_DIALOG=true
      shift
      ;;
    --help|-h)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_help
      exit 1
      ;;
  esac
done

# Use env fallback if needed
if [[ "$CONFIG_FILE" == "$DEFAULT_CONFIG" && -n "${SSHOP_CONFIG:-}" ]]; then
  CONFIG_FILE="$SSHOP_CONFIG"
fi

# === Validate config ===
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found at $CONFIG_FILE"
  exit 1
fi

# === Load client names (portable version) ===
CLIENT_NAMES=()
while IFS= read -r line; do
  CLIENT_NAMES+=("$line")
done < <(yq -r '.clients[].name' "$CONFIG_FILE")

if [[ "${#CLIENT_NAMES[@]}" -eq 0 ]]; then
  echo "No clients found in config."
  exit 1
fi

# === Set back option based on UI ===
if $USE_DIALOG; then
  BACK_OPTION="__BACK__"
else
  BACK_OPTION="⬅ Back"
fi

# === Pick client ===
pick_option() {
  local prompt="$1"
  local include_back="$2"
  shift 2
  local options=("$@")
  local result=""

  # Add back option as entry only for fzf if requested
  if ! $USE_DIALOG && [ "$include_back" == "true" ]; then
    options=("$BACK_OPTION" "${options[@]}")
  fi

  if $USE_DIALOG; then
    local menu_items=()
    for opt in "${options[@]}"; do
      menu_items+=("$opt" "")
    done

    temp=$(mktemp)
    trap "rm -f $temp" EXIT
    if ! dialog --clear --stdout --menu "$prompt" 15 60 10 "${menu_items[@]}" > "$temp"; then
      rm -f "$temp"
      trap - EXIT
      echo "$BACK_OPTION"
      return
    fi

    result=$(<"$temp")
    rm -f "$temp"
    trap - EXIT
  else
    result=$(printf "%s\n" "${options[@]}" | fzf --prompt="$prompt: " --height=20 --border) || result="$BACK_OPTION"
  fi

  echo "$result"
}

# Step 1: Pick a client
while true; do
  CLIENT=$(pick_option "Select a client" false "${CLIENT_NAMES[@]}")
  [[ "$CLIENT" == "$BACK_OPTION" ]] && exit 0

  # Step 2: Pick a server
  while true; do
    SERVERS=()
    while IFS= read -r line; do
      SERVERS+=("$line")
    done < <(yq -r ".clients[] | select(.name == \"$CLIENT\") | .servers[] | .name" "$CONFIG_FILE")

    if [[ "${#SERVERS[@]}" -eq 0 ]]; then
      echo "No servers defined for client '$CLIENT'."
      break
    fi

    SERVER=$(pick_option "Select an environment for $CLIENT" true "${SERVERS[@]}")
    [[ "$SERVER" == "$BACK_OPTION" ]] && break

    USERNAME=$(yq -r ".clients[] | select(.name == \"$CLIENT\") | .servers[] | select(.name == \"$SERVER\") | .username // \"\"" "$CONFIG_FILE")
    HOST=$(yq -r ".clients[] | select(.name == \"$CLIENT\") | .servers[] | select(.name == \"$SERVER\") | .host" "$CONFIG_FILE")

    if [[ -z "$HOST" || -z "$USERNAME" ]]; then
      echo "Missing username or host for $CLIENT / $SERVER"
      continue
    fi

    echo "Connecting to $CLIENT → $SERVER ($USERNAME@$HOST)..."
    exec ssh "$USERNAME@$HOST" -t "bash"
  done
done
