#!/usr/bin/env bash

set -euo pipefail

# === Defaults & Flags ===
DEFAULT_CONFIG="${HOME}/.sshop/clients.json"
CONFIG_FILE="${SSHOP_CONFIG:-$DEFAULT_CONFIG}"
USE_DIALOG=false
MODE="normal"
BACK_OPTION="⬅ Back"

# === Use env fallback if needed ===
if [[ "$CONFIG_FILE" == "$DEFAULT_CONFIG" && -n "${SSHOP_CONFIG:-}" ]]; then
  CONFIG_FILE="$SSHOP_CONFIG"
fi

# === Validate config ===
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found at $CONFIG_FILE"
  exit 1
fi

# === Load client names ===
CLIENT_NAMES=()
while IFS= read -r line; do
  CLIENT_NAMES+=("$line")
done < <(jq -r '.clients[].name' "$CONFIG_FILE")

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
  --add, -a             Add new client via prompt
  --edit, -e            Edit existing client via fzf + prompts
  --delete, -d          Delete existing client via fzf + prompts
  --config, -c <file>   Use a specific clients.json config file
  --help, -h            Show this help message

Environment:
  SSHOP_CONFIG          Path to a custom config file (fallback if --config not used)
EOF
}

has_clients() {
  if [[ "${#CLIENT_NAMES[@]}" -eq 0 ]]; then
    echo "No clients found in config."
    exit 1
  fi
}

edit_server() {
  has_clients

  if ! pick_client_server; then
    exit 0
  fi

  # Fetch current server values
  local server_json
  server_json=$(jq -r --arg client "$CLIENT" --arg server "$SERVER" \
    '.clients[] | select(.name == $client) | .servers[] | select(.name == $server)' "$CONFIG_FILE")

  local name host port username
  name=$(echo "$server_json" | jq -r '.name')
  host=$(echo "$server_json" | jq -r '.host')
  port=$(echo "$server_json" | jq -r '.port')
  username=$(echo "$server_json" | jq -r '.username')

  # Prompt for new values
  new_name=$(get_input "Environment/server name" "e.g. Production", $name)
  new_host=$(get_input "Host (IP or domain)" "e.g. prod.example.com", $host)
  new_port=$(get_input "Port" "e.g. 22" $port)
  new_username=$(get_input "Username" "e.g. ubuntu", $username)

  new_name="${new_name:-$name}"
  new_host="${new_host:-$host}"
  new_port="${new_port:-$port}"
  new_username="${new_username:-$username}"

  tmp=$(mktemp)

  jq --arg client "$CLIENT" \
     --arg old_server "$SERVER" \
     --arg name "$new_name" \
     --arg host "$new_host" \
     --argjson port "$new_port" \
     --arg username "$new_username" \
     '
     .clients |= map(
       if .name == $client then
         .servers |= map(
           if .name == $old_server then
             {
               name: $name,
               host: $host,
               port: $port,
               username: $username
             } else . end
         )
       else . end
     )
     ' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"

  echo "✅ Server '$SERVER' for client '$CLIENT' updated."
  exit 0
}

delete_server() {
  has_clients
  if ! pick_client_server; then
    exit 0
  fi

  # read -rp "⚠️ Are you sure you want to delete '$SERVER' from '$CLIENT'? [y/N]: " confirm
  # [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
  get_confirm "⚠️ Are you sure you want to delete '$SERVER' from '$CLIENT'?"

  tmp=$(mktemp)

  jq --arg client "$CLIENT" --arg server "$SERVER" '
    .clients |= map(
      if .name == $client then
        .servers |= map(select(.name != $server))
      else . end
    ) | .clients |= map(select(.servers | length > 0))
  ' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"

  echo "✅ Server deleted. Removed client if it had no servers left."
  exit 0
}

# === Utility: Pick option ===
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

# === Utility: Get input ===
get_input() {
  local label="$1"
  local placeholder="$2"
  local default="${3:-}"

  local value
  if [[ -n "$default" ]]; then
    value=$(gum input --prompt "❯ $label: " --placeholder "$placeholder" --value "$default" --cursor.foreground "#FFF" --prompt.foreground "#31c831")
  else
    value=$(gum input --prompt "❯ $label: " --placeholder "$placeholder" --cursor.foreground "#FFF" --prompt.foreground "#31c831")
  fi

  # Ctrl+C or empty input guard
  if [[ $? -ne 0 || -z "$value" ]]; then
    echo "❌ Aborted."
    exit 1
  fi

  echo "$value"
}

get_confirm() {
  gum confirm "$1"
}

pick_client_server() {
  # Pick client
  local client
  client=$(pick_option "Select a client" false "${CLIENT_NAMES[@]}")
  [[ "$client" == "$BACK_OPTION" || -z "$client" ]] && return 1

  # Get servers for the client
  local servers=()
  while IFS= read -r line; do
    servers+=("$line")
  done < <(jq -r --arg client "$client" '.clients[] | select(.name == $client) | .servers[]?.name' "$CONFIG_FILE")

  if [[ "${#servers[@]}" -eq 0 ]]; then
    echo "No servers defined for client '$client'."
    return 2
  fi

  # Pick server
  local server
  server=$(pick_option "Select an environment for $client" true "${servers[@]}")
  [[ "$server" == "$BACK_OPTION" || -z "$server" ]] && return 1

  # Output selection as global vars or stdout
  CLIENT="$client"
  SERVER="$server"
  return 0
}

add_client_server() {
  echo "🔧 Add a new client and server configuration"

  CONFIG_FILE="${SSHOP_CONFIG:-$HOME/.sshop/clients.json}"
  mkdir -p "$(dirname "$CONFIG_FILE")"
  touch "$CONFIG_FILE"

  CLIENT_NAME=$(get_input "Client name" "e.g. FooBar")
  SERVER_NAME=$(get_input "Environment/server name" "e.g. Production")
  HOST=$(get_input "Host (IP or domain)" "e.g. prod.example.com")
  PORT=$(get_input "Port" "e.g. 22" "22")
  USERNAME=$(get_input "Username" "e.g. ubuntu")

  # Initialize empty JSON if file is empty or invalid
  if ! jq empty "$CONFIG_FILE" >/dev/null 2>&1 || [[ ! -s "$CONFIG_FILE" ]]; then
    echo '{"clients": []}' > "$CONFIG_FILE"
  fi

  TMP=$(mktemp)

  # Check if client exists
  CLIENT_EXISTS=$(jq --arg name "$CLIENT_NAME" '.clients[]? | select(.name == $name)' "$CONFIG_FILE")

  if [[ -z "$CLIENT_EXISTS" ]]; then
    echo "➕ Adding new client '$CLIENT_NAME'"
    jq --arg client "$CLIENT_NAME" \
       --arg server "$SERVER_NAME" \
       --arg host "$HOST" \
       --arg port "$PORT" \
       --arg user "$USERNAME" \
       '.clients += [{"name": $client, "servers": [{"name": $server, "host": $host, "port": ($port | tonumber), "username": $user}]}]' \
       "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
  else
    # Check if server already exists
    SERVER_EXISTS=$(jq --arg name "$CLIENT_NAME" --arg srv "$SERVER_NAME" \
      '.clients[] | select(.name == $name) | .servers[]? | select(.name == $srv)' "$CONFIG_FILE")

    if [[ -n "$SERVER_EXISTS" ]]; then
      echo "⚠️  Server '$SERVER_NAME' already exists for '$CLIENT_NAME'."
      exit 1
    fi

    echo "🧩 Adding server to existing client '$CLIENT_NAME'"
    jq --arg name "$CLIENT_NAME" \
       --arg server "$SERVER_NAME" \
       --arg host "$HOST" \
       --arg port "$PORT" \
       --arg user "$USERNAME" \
       '(.clients[] | select(.name == $name) | .servers) += [{"name": $server, "host": $host, "port": ($port | tonumber), "username": $user}]' \
       "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
  fi

  echo "✅ Configuration saved."
  exit 0
}

# === Parse arguments ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --add|-a)
      add_client_server
      ;;
    --config|-c)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --delete|-d)
      delete_server
      ;;
    --edit|-e)
      edit_server
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

# ==================================
# Client + Server select flow
# ==================================
while true; do
  if ! pick_client_server; then
    exit 0
  fi

  read -r USERNAME HOST PORT < <(jq -r --arg client "$CLIENT" --arg server "$SERVER" \
    '.clients[] | select(.name == $client) | .servers[] | select(.name == $server) | "\(.username) \(.host) \(.port)"' "$CONFIG_FILE")

  if [[ -z "$HOST" || -z "$USERNAME" ]]; then
    echo "Missing username or host for $CLIENT / $SERVER"
    continue
  fi

  echo "Connecting to $CLIENT → $SERVER ($USERNAME@$HOST:$PORT)..."
  exec ssh -p"$PORT" "$USERNAME@$HOST" -t "bash"
done

