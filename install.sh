#!/bin/bash
set -e

# Verbose option - set to true to see installation outputs
VERBOSE=${VERBOSE:-false}

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper function for conditional output redirection
run_command() {
    if [ "$VERBOSE" = "true" ]; then
        "$@"
    else
        "$@" > /dev/null 2>&1
    fi
}

# Helper functions for better UI
print_box() {
    local message="$1"
    local color="${2:-$CYAN}"
    local text_color="${3:-$NC}"
    
    # Calculate padding to center the message
    local box_width=62
    # Remove color codes and count actual visible characters
    local clean_message
    clean_message=$(echo -e "$message" | sed 's/\x1b\[[0-9;]*m//g')
    
    # Use wc -m to count multibyte characters properly, then adjust for emoji visual width
    local char_count
    char_count=$(echo -n "$clean_message" | wc -m)
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
    
    echo -e "${color}════════════════════════════════════════════════════════════════${NC}"
    printf "${color} ${NC}%*s${text_color}%s${NC}%*s${color}${NC}\n" $padding "" "$message" $right_padding ""
    echo -e "${color}════════════════════════════════════════════════════════════════${NC}\n"
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
            
            # Check if essential packages are installed
            missing_packages=()
            essential_packages=("build-essential" "git" "curl" "wget" "software-properties-common" "apt-transport-https" "ca-certificates" "gnupg" "lsb-release" "zsh")
            
            for package in "${essential_packages[@]}"; do
                if ! dpkg -s "$package" &>/dev/null; then
                    missing_packages+=("$package")
                fi
            done
            
            if [ ${#missing_packages[@]} -gt 0 ]; then
                echo -e "${YELLOW}Missing packages:${NC} ${missing_packages[*]}"
                run_command sudo apt update
                run_command sudo apt install -y "${missing_packages[@]}"
                print_success "Essential packages installed successfully!"
            else
                print_info "All essential packages are already installed."
            fi
            ;;
        "fedora")
            print_step "Installing essential packages for Fedora/RHEL..."
            
            # Check if essential packages are installed
            missing_packages=()
            essential_packages=("gcc" "gcc-c++" "make" "git" "curl" "wget" "which" "zsh")
            
            for package in "${essential_packages[@]}"; do
                if ! rpm -q "$package" &>/dev/null; then
                    missing_packages+=("$package")
                fi
            done
            
            # Check if Development Tools group is installed
            if ! dnf group list installed | grep -q "Development Tools"; then
                missing_packages+=("@development-tools")
            fi
            
            if [ ${#missing_packages[@]} -gt 0 ]; then
                echo -e "${YELLOW}Missing packages:${NC} ${missing_packages[*]}"
                if [[ " ${missing_packages[*]} " =~ " @development-tools " ]]; then
                    run_command sudo dnf groupinstall -y "Development Tools"
                fi
                # Install remaining individual packages (excluding the group)
                individual_packages=()
                for pkg in "${missing_packages[@]}"; do
                    if [ "$pkg" != "@development-tools" ]; then
                        individual_packages+=("$pkg")
                    fi
                done
                if [ ${#individual_packages[@]} -gt 0 ]; then
                    run_command sudo dnf install -y "${individual_packages[@]}"
                fi
                print_success "Essential packages installed successfully!"
            else
                print_info "All essential packages are already installed."
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

# Set up Homebrew PATH if it exists but isn't in PATH
if [[ "$OS" == "macos" ]]; then
    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    if [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

# -----------------------------------------------------------------------------

# install brew
print_step "Checking Homebrew installation..."
if ! command -v brew &> /dev/null; then
    print_step "Installing Homebrew..."
    NONINTERACTIVE=1 run_command /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

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

if run_command brew install "${packages[@]}"; then
    print_success "All packages installed successfully!"
else
    print_error "Some packages failed to install. Trying individual installation..."
    
    # Fallback to individual installation for failed packages
    for package in "${packages[@]}"; do
        if ! brew list "$package" &>/dev/null; then
            echo -e "${CYAN}▶${NC} Installing ${YELLOW}$package${NC}..."
            run_command brew install "$package"
        fi
    done
fi

print_separator
# -----------------------------------------------------------------------------

print_step "Checking Oh My Zsh installation..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    print_step "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no run_command sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    print_success "Oh My Zsh installed successfully!"
else
    print_info "Oh My Zsh is already installed."
fi

# Set ZSH_CUSTOM_DIR after Oh My Zsh is installed
ZSH_CUSTOM_DIR=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}


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
        run_command git clone "$plugin_url" "$ZSH_CUSTOM_DIR/plugins/$plugin_name"
        print_success "  $plugin_name installed!"
    else
        print_info "  $plugin_name is already installed."
    fi
done
    
print_success "All plugins installed successfully!"


# copy the custom dotfiles to the home directory
print_separator
print_step "Copying custom dotfiles to home directory..."

if [ -d "$SCRIPT_DIR/bling" ]; then
    if cp -rf "$SCRIPT_DIR/bling" "$HOME/"; then
        print_success "Copied bling directory to home directory"
    else
        print_error "Failed to copy bling directory"
    fi
else
    print_info "bling directory not found in script directory"
fi

if [ -f "$SCRIPT_DIR/zsh/.zshrc" ]; then
    if cp -f "$SCRIPT_DIR/zsh/.zshrc" "$HOME/.zshrc"; then
        print_success "Copied .zshrc to home directory"
    else
        print_error "Failed to copy .zshrc"
    fi
else
    print_info ".zshrc file not found in script directory"
fi

# Reload Oh My Zsh if it's installed (this will only work in a new shell session)
if [ -d "$HOME/.oh-my-zsh" ] && command -v zsh &> /dev/null; then
    print_info "Oh My Zsh configuration updated. Changes will take effect in new shell sessions."
fi

print_separator
# -----------------------------------------------------------------------------

echo ""
print_success "🎉 Dotfiles installation completed successfully!"
echo ""
print_box "Installation complete! Please restart your terminal." "$CYAN" "$GREEN"