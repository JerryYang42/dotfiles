#!/bin/bash

PACKAGES_FILE="${1:-packages.txt}"
CHECK_ONLY=true
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --check)
      CHECK_ONLY=true
      shift
      ;;
    --no-check)
      CHECK_ONLY=false
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --file=*)
      PACKAGES_FILE="${1#*=}"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [[ ! -f "$PACKAGES_FILE" ]]; then
  echo "Error: Package file '$PACKAGES_FILE' not found."
  exit 1
fi

# Function to check if a package is installed via APT
is_apt_installed() {
  dpkg -l "$1" 2>/dev/null | grep -q "^ii"
  return $?
}

# Function to check if a command exists in PATH
command_exists() {
  command -v "$1" >/dev/null 2>&1
  return $?
}

# Function to install a package
install_package() {
  if $VERBOSE; then
    echo "Installing package: $1"
  fi
  sudo apt-get install -y "$1"
}

# Function to handle PPA repositories
add_ppa() {
  local ppa="$1"
  if ! grep -q "^deb .*${ppa#ppa:}" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    if $VERBOSE; then
      echo "Adding PPA: $ppa"
    fi
    if ! $CHECK_ONLY; then
      sudo add-apt-repository -y "$ppa"
      sudo apt-get update
    fi
  else
    installed=$((installed + 1))
    if $VERBOSE; then
      echo "PPA already added: $ppa"
    fi
  fi
}

# Function to handle snap packages
install_snap() {
  local package="$1"
  if ! snap list | grep -q "^$package "; then
    if $VERBOSE; then
      echo "Installing snap package: $package"
    fi
    if ! $CHECK_ONLY; then
      sudo snap install "$package"
    else
      echo "Missing snap package: $package"
    fi
  elif $VERBOSE; then
    echo "Snap package already installed: $package"
  fi
}

# Function to validate a command-line tool
validate_command() {
  local cmd="$1"
  if command_exists "$cmd"; then
    installed=$((installed + 1))
    if $VERBOSE; then
      echo "Command found in PATH: $cmd"
      # Show where the command is located
      echo "  Location: $(command -v "$cmd")"
    fi
    return 0
  else
    missing=$((missing + 1))
    echo "Missing command: $cmd"
    return 1
  fi
}

# Track stats
total=0
installed=0
missing=0

# Process the package file
while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip comments and empty lines - make sure to trim whitespace
  line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  
  # If there's a comment at the end of the line, remove it
  line=$(echo "$line" | sed 's/[[:space:]]*#.*$//')
  [[ -z "$line" ]] && continue
  
  total=$((total + 1))
  
  # Handle different types of entries
  if [[ "$line" == ppa:* ]]; then
    # Handle PPA repositories
    add_ppa "$line"
  elif [[ "$line" == snap:* ]]; then
    # Handle snap packages
    package="${line#snap:}"
    install_snap "$package"
    if snap list | grep -q "^$package "; then
      installed=$((installed + 1))
    else
      missing=$((missing + 1))
    fi
  elif [[ "$line" == cmd:* ]]; then
    # Explicitly check for command in PATH
    command="${line#cmd:}"
    validate_command "$command"
    if [ $? -ne 0 ] && [ "$CHECK_ONLY" = false ]; then
      echo "Please install '$command' manually or specify the appropriate installation method"
    fi
  else
    # First try to check if command exists in PATH
    if command_exists "$line"; then
      installed=$((installed + 1))
      if $VERBOSE; then
        echo "Command found in PATH: $line"
        echo "  Location: $(command -v "$line")"
      fi
    # Then fall back to checking if it's an apt package
    elif is_apt_installed "$line"; then
      installed=$((installed + 1))
      if $VERBOSE; then
        echo "Package already installed: $line"
      fi
    else
      missing=$((missing + 1))
      echo "Missing package/command: $line"
      if ! $CHECK_ONLY; then
        # Try to install via apt
        echo "Attempting to install '$line' via apt..."
        install_package "$line"
      fi
    fi
  fi
done < "$PACKAGES_FILE"

# Print summary
echo "===== Package Summary ====="
echo "Total packages: $total"
echo "Installed: $installed"
echo "Missing: $missing"

if [ "$missing" -gt 0 ] && $CHECK_ONLY; then
  echo "Run with --no-check to install missing packages"
  exit 1
fi

exit 0