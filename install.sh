#!/bin/bash
# set -e

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper functions for better UI
print_box() {
    local message="$1"
    local color="${2:-$CYAN}"
    local text_color="${3:-$NC}"
    
    # Calculate padding to center the message
    local box_width=62
    # Remove color codes and count actual visible characters
    local clean_message=$(echo -e "$message" | sed 's/\x1b\[[0-9;]*m//g')
    
    # Use wc -m to count multibyte characters properly, then adjust for emoji visual width
    local char_count=$(echo -n "$clean_message" | wc -m)
    local visual_length=$char_count
    
    case "$clean_message" in
        *"🚀"*) visual_length=$((char_count + 1)) ;;  # Rocket emoji takes 2 visual spaces
        *"🎉"*) visual_length=$((char_count + 1)) ;;  # Party emoji takes 2 visual spaces
        *"✓"*) visual_length=$char_count ;;           # Checkmark is usually 1 space
        *"▶"*) visual_length=$char_count ;;           # Arrow is usually 1 space
        *"ℹ"*) visual_length=$char_count ;;           # Info symbol is usually 1 space
        *"✗"*) visual_length=$char_count ;;           # X mark is usually 1 space
    esac
    
    local padding=$(( (box_width - visual_length) / 2 ))
    local right_padding=$(( box_width - visual_length - padding ))
    
    echo -e "${color}╔══════════════════════════════════════════════════════════════╗${NC}"
    printf "${color}║${NC}%*s${text_color}%s${NC}%*s${color}║${NC}\n" $padding "" "$message" $right_padding ""
    echo -e "${color}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_separator() {
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
}

# OS Detection function
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian) echo "ubuntu" ;;
            fedora|rhel|centos) echo "fedora" ;;
            *) echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

# Install essential packages based on OS
install_essential_packages() {
    local os="$1"
    
    case "$os" in
        "ubuntu")
            print_step "Installing essential packages for Ubuntu/Debian..."
            if ! dpkg -l | grep -q build-essential; then
                sudo apt-get update > /dev/null 2>&1
                sudo apt-get install -y build-essential git curl wget software-properties-common apt-transport-https ca-certificates gnupg lsb-release > /dev/null 2>&1
                print_success "Essential packages installed successfully!"
            else
                print_info "Essential packages are already installed."
            fi
            ;;
        "fedora")
            print_step "Installing essential packages for Fedora/RHEL..."
            if ! rpm -qa | grep -q gcc; then
                sudo dnf groupinstall -y "Development Tools" > /dev/null 2>&1
                sudo dnf install -y git curl wget which > /dev/null 2>&1
                print_success "Essential packages installed successfully!"
            else
                print_info "Essential packages are already installed."
            fi
            ;;
        "macos")
            print_step "Checking Xcode Command Line Tools for macOS..."
            if ! xcode-select -p &> /dev/null; then
                print_step "Installing Xcode Command Line Tools..."
                xcode-select --install
                print_info "Please complete the Xcode Command Line Tools installation and re-run this script."
                exit 1
            else
                print_info "Xcode Command Line Tools are already installed."
            fi
            ;;
        *)
            print_error "Unsupported operating system. This script supports Ubuntu/Debian, Fedora/RHEL, and macOS."
            exit 1
            ;;
    esac
}

# Start installation
print_box "🚀 DOTFILES INSTALLER" "$CYAN" "$PURPLE"

# Detect OS and install essential packages
OS=$(detect_os)
print_step "Detected OS: $OS"

# print current user

CURRENT_USER=$(whoami)
print_step "Current user: $CURRENT_USER"

print_separator
install_essential_packages "$OS"

ZSH_CUSTOM_DIR=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}

# -----------------------------------------------------------------------------

# install brew
print_step "Checking Homebrew installation..."
if ! command -v brew &> /dev/null; then
    print_step "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Set up Homebrew PATH based on OS
    if [[ "$OS" == "macos" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)"
    else
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
    
    print_success "Homebrew installed successfully!"
else
    print_info "Homebrew is already installed."
fi

print_separator
# -----------------------------------------------------------------------------

print_step "Installing essential packages..."

# Verify brew is now available
if ! command -v brew &> /dev/null; then
    print_error "Failed to setup Homebrew PATH. Please restart your terminal and re-run this script."
    exit 1
fi

packages=(
    "atuin" "bat" "bash-preexec" "chezmoi" "direnv" 
    "dysk" "eza" "fd" "gh" "glab" "rg" "starship" 
    "shellcheck" "stress-ng" "tealdeer" "trash-cli" 
    "television" "uutils-coreutils" "ugrep" "yq" "zoxide"
)

print_step "Installing ${#packages[@]} packages..."
echo -e "${CYAN}Installing:${NC} ${YELLOW}${packages[*]}${NC}"

if brew install "${packages[@]}" > /dev/null 2>&1; then
    print_success "All packages installed successfully!"
else
    print_error "Some packages failed to install. Trying individual installation..."
    
    # Fallback to individual installation for failed packages
    for package in "${packages[@]}"; do
        if ! brew list "$package" &>/dev/null; then
            echo -e "${CYAN}▶${NC} Installing ${YELLOW}$package${NC}..."
            brew install "$package" > /dev/null 2>&1
        fi
    done
fi

print_separator
# -----------------------------------------------------------------------------

print_step "Checking Zsh installation..."
if ! command -v zsh &> /dev/null; then
    print_step "Installing Zsh..."
    brew install zsh > /dev/null 2>&1
    print_success "Zsh installed successfully!"
else
    print_info "Zsh is already installed."
fi

print_separator
# -----------------------------------------------------------------------------

print_step "Checking Oh My Zsh installation..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    print_step "Installing Oh My Zsh..."
    RUNZSH=yes CHSH=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" > /dev/null 2>&1
    print_success "Oh My Zsh installed successfully!"
else
    print_info "Oh My Zsh is already installed."
fi


print_separator
# -----------------------------------------------------------------------------

print_step "Installing Oh My Zsh plugins..."

plugins=(
    "zsh-autosuggestions:https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting:https://github.com/zsh-users/zsh-syntax-highlighting.git"
    "zsh-bat:https://github.com/fdellwing/zsh-bat.git"
)

for plugin_info in "${plugins[@]}"; do
    plugin_name=${plugin_info%%:*}
    plugin_url=${plugin_info#*:}
    
    if [ ! -d "$ZSH_CUSTOM_DIR/plugins/$plugin_name" ]; then
        echo -e "  ${CYAN}▶${NC} Installing ${YELLOW}$plugin_name${NC}..."
        git clone "$plugin_url" "$ZSH_CUSTOM_DIR/plugins/$plugin_name" > /dev/null 2>&1
        print_success "  $plugin_name installed!"
    else
        print_info "  $plugin_name is already installed."
    fi
done
    
print_success "All plugins installed successfully!"


# copy the custom dotfiles to the home directory
cp -rf "$SCRIPT_DIR/bling"  "$HOME/bling"
cp -f "$SCRIPT_DIR/zsh/.zshrc" "$HOME/.zshrc"


# Reload Oh My Zsh if it's installed
if command -v omz &> /dev/null; then
    omz reload
fi

print_separator
# -----------------------------------------------------------------------------

echo ""
print_success "🎉 Dotfiles installation completed successfully!"
echo ""
print_box "Installation complete! Please restart your terminal." "$CYAN" "$GREEN"