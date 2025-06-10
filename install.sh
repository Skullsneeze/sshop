#!/usr/bin/env bash

set -euo pipefail

# === Variables ===
SCRIPT_NAME="sshop"
SCRIPT_SOURCE="https://github.com/Skullsneeze/sshop/releases/latest/download/sshop"
DEFAULT_INSTALL_DIR="/usr/local/bin"
FALLBACK_INSTALL_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.sshop"
CONFIG_FILE="${CONFIG_DIR}/clients.json"

# === Colors ===
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

# === Functions ===
detect_package_manager() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt >/dev/null; then echo "apt"
    elif command -v dnf >/dev/null; then echo "dnf"
    elif command -v pacman >/dev/null; then echo "pacman"
    else echo ""; fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew >/dev/null; then echo "brew"; else echo ""; fi
  else
    echo ""
  fi
}

install_jq_if_missing() {
  if ! command -v jq >/dev/null; then
    echo -e "${GREEN}🔧 'jq' not found. Attempting to install...${NC}"
    PM=$(detect_package_manager)
    case "$PM" in
      apt)    sudo apt update && sudo apt install -y jq ;;
      dnf)    sudo dnf install -y jq ;;
      pacman) sudo pacman -Sy --noconfirm jq ;;
      brew)   brew install jq ;;
      *)      echo -e "${RED}❌ Could not detect a supported package manager. Please install 'jq' manually.${NC}"; exit 1 ;;
    esac
  else
    echo -e "${GREEN}✅ jq is already installed${NC}"
  fi
}

install_fzf_if_missing() {
  if ! command -v jq >/dev/null; then
    echo -e "${GREEN}🔧 'fzf' not found. Attempting to install...${NC}"
    PM=$(detect_package_manager)
    case "$PM" in
      apt)    sudo apt update && sudo apt install -y fzf ;;
      dnf)    sudo dnf install -y fzf ;;
      pacman) sudo pacman -Sy --noconfirm fzf ;;
      brew)   brew install fzf ;;
      *)      echo -e "${RED}❌ Could not detect a supported package manager. Please install 'fzf' manually.${NC}"; exit 1 ;;
    esac
  else
    echo -e "${GREEN}✅ fzf is already installed${NC}"
  fi
}

install_gum_if_missing() {
  if ! command -v gum >/dev/null; then
    echo -e "${GREEN}🔧 'gum' not found. Attempting to install...${NC}"
    PM=$(detect_package_manager)
    case "$PM" in
      apt)    sudo apt update && sudo apt install -y gum ;;
      dnf)    sudo dnf install -y gum ;;
      pacman) sudo pacman -Sy --noconfirm gum ;;
      brew)   brew install gum ;;
      *)      echo -e "${RED}❌ Could not detect a supported package manager. Please install 'gum' manually.${NC}"; exit 1 ;;
    esac
  else
    echo -e "${GREEN}✅ gum is already installed${NC}"
  fi
}

install_script() {
  local target_dir="$DEFAULT_INSTALL_DIR"
  local use_sudo=true

  if [[ ! -w "$DEFAULT_INSTALL_DIR" ]]; then
    echo -e "${RED}⚠️ No write access to $DEFAULT_INSTALL_DIR. Falling back to $FALLBACK_INSTALL_DIR${NC}"
    target_dir="$FALLBACK_INSTALL_DIR"
    use_sudo=false
    mkdir -p "$target_dir"
  fi

  echo -e "${GREEN}📦 Installing $SCRIPT_NAME to $target_dir${NC}"
  curl -sSfL "$SCRIPT_SOURCE" -o "$target_dir/$SCRIPT_NAME"
  chmod +x "$target_dir/$SCRIPT_NAME"

  # Add to PATH if necessary
  if [[ ":$PATH:" != *":$target_dir:"* ]]; then
    echo -e "${GREEN}🔧 $target_dir is not in your PATH. You can add it by running:${NC}"
    echo "  echo 'export PATH=\"\$PATH:$target_dir\"' >> ~/.bashrc && source ~/.bashrc"
    echo "  # or for zsh:"
    echo "  echo 'export PATH=\"\$PATH:$target_dir\"' >> ~/.zshrc && source ~/.zshrc"
  fi
}

create_default_config_if_missing() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${GREEN}📝 Creating default config at $CONFIG_FILE${NC}"
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<EOF
{
  "clients": [
    {
      "name": "ExampleClient",
      "servers": [
        {
          "name": "Production",
          "host": "prod.example.com",
          "port": 22,
          "username": "ubuntu"
        }
      ]
    }
  ]
}
EOF
  else
    echo -e "${GREEN}✅ Config file already exists at $CONFIG_FILE${NC}"
  fi
}

# === Run ===
echo -e "${GREEN}🚀 Installing sshop...${NC}"
install_jq_if_missing
install_fzf_if_missing
install_gum_if_missing
install_script
create_default_config_if_missing
echo -e "${GREEN}✅ Done! Run '${SCRIPT_NAME}' to get started.${NC}"
