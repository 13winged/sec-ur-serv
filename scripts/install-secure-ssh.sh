#!/bin/bash

# ============================================
# sec-ur-serv: Complete Installation Script
# One-line installer for sec-ur-serv
# ============================================

set -euo pipefail

REPO_URL="https://github.com/13winged/sec-ur-serv"
INSTALL_DIR="/opt/sec-ur-serv"
VERSION="2.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_msg() { echo -e "$1$2${NC}"; }
print_header() {
    echo -e "\n${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║$1                                                          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_msg "$RED" "✗ This installer must be run as root (sudo)."
        exit 1
    fi
}

check_ssh_connectivity() {
    print_header "Checking SSH Connectivity..."

    # BatchMode run of `true`: exit code tells the truth (no greppable banner exists)
    if ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no \
           -o PasswordAuthentication=no localhost true 2>/dev/null; then
        print_msg "$GREEN" "✓ SSH Connectivity Check: SUCCESS (key auth to localhost works)"
    else
        print_msg "$RED" "✗ SSH Connectivity Check: FAIL (key auth to localhost:22 failed)"
        print_msg "$YELLOW" "Please ensure SSH server is running and your key is set up correctly."
        print_msg "$YELLOW" "Run 'ssh -o PasswordAuthentication=no localhost' manually to test."
        exit 1
    fi
}

# Download scripts
download_scripts() {
    print_header "Downloading sec-ur-serv"
    
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Download scripts
    print_msg "$BLUE" "Downloading scripts..."

    curl -fsSL --max-time 120 --retry 3 "$REPO_URL/raw/main/scripts/secure-ssh.sh" \
        -o "$INSTALL_DIR/secure-ssh.sh"

    curl -fsSL --max-time 120 --retry 3 "$REPO_URL/raw/main/scripts/manage-ssh-users.sh" \
        -o "$INSTALL_DIR/manage-ssh-users.sh"

    curl -fsSL --max-time 120 --retry 3 "$REPO_URL/raw/main/scripts/install-secure-ssh.sh" \
        -o "$INSTALL_DIR/install.sh"
    
    # Make executable
    chmod +x "$INSTALL_DIR"/*.sh
    
    # Create symlinks
    ln -sf "$INSTALL_DIR/secure-ssh.sh" /usr/local/bin/secure-ssh
    ln -sf "$INSTALL_DIR/manage-ssh-users.sh" /usr/local/bin/manage-ssh-users
    
    print_msg "$GREEN" "✓ Scripts downloaded to $INSTALL_DIR"
    print_msg "$GREEN" "✓ Commands available: secure-ssh, manage-ssh-users"
}

# Create configuration
create_config() {
    print_header "Creating Configuration"
    
    # Create config directory
    mkdir -p /etc/sec-ur-serv
    
    # Default configuration
    cat > /etc/sec-ur-serv/config.conf << EOF
# sec-ur-serv Configuration
# Version: $VERSION

SECURE_SSH=true
BACKUP_ENABLED=true
EMERGENCY_SCRIPT=true

# Default settings
DEFAULT_KEY_TYPE=ed25519
SSH_PORT=22
ALLOW_ROOT=prohibit-password

# Notification settings
SEND_NOTIFICATIONS=false
# NOTIFICATION_EMAIL=
EOF
    
    chmod 600 /etc/sec-ur-serv/config.conf
    print_msg "$GREEN" "✓ Configuration created"
}

# Install dependencies
install_deps() {
    print_header "Installing Dependencies"
    
    echo -e "${BLUE}-> Running apt-get update...${NC}"
    apt-get update
    if [ $? -ne 0 ]; then
        print_msg "$RED" "✗ ERROR: apt-get update failed!"
        exit 1
    fi

    echo -e "${BLUE}-> Running apt-get install...${NC}"
    apt-get install -y \
        openssh-server \
        sshpass \
        curl \
        net-tools
    if [ $? -ne 0 ]; then
        print_msg "$RED" "✗ ERROR: apt-get install failed!"
        exit 1
    fi
    
    print_msg "$GREEN" "✓ Dependencies installed"
}

# Create uninstall script
create_uninstall() {
    print_header "Creating Uninstall Script"
    
    cat > "$INSTALL_DIR/uninstall.sh" << 'EOF'
#!/bin/bash

echo "⚠ WARNING: This will remove sec-ur-serv"
echo "It will NOT revert SSH configuration changes!"
echo ""

read -p "Continue? (type 'yes'): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cancelled"
    exit 1
fi

# Remove symlinks
rm -f /usr/local/bin/secure-ssh
rm -f /usr/local/bin/manage-ssh-users

# Remove configuration
rm -rf /etc/sec-ur-serv

echo ""
echo "sec-ur-serv removed."
echo "Note: SSH configuration changes remain."
echo "Use emergency script if needed: /root/ssh_emergency_revert.sh"
EOF
    
    chmod +x "$INSTALL_DIR/uninstall.sh"
    print_msg "$GREEN" "✓ Uninstall script created"
}

# Show completion
show_completion() {
    print_header "Installation Complete!"
    
    cat << EOF
## Summary
${GREEN}✅ sec-ur-serv v$VERSION successfully installed!${NC}

${CYAN}📁 Installation Directory:${NC}
  $INSTALL_DIR

${CYAN}🚀 Available Commands:${NC}
  • secure-ssh           - Secure SSH configuration
  • manage-ssh-users     - Manage SSH users and keys
  • $INSTALL_DIR/uninstall.sh - Uninstall tool

${CYAN}🔧 Quick Start:${NC}
  1. First, test your SSH keys:
     ${BLUE}ssh -o PasswordAuthentication=no localhost${NC}

  2. Secure your SSH configuration:
     ${BLUE}secure-ssh --dry-run${NC}     (Test first)
     ${BLUE}secure-ssh${NC}               (Apply changes)

  3. Manage users:
     ${BLUE}manage-ssh-users${NC}         (Interactive menu)

${YELLOW}⚠ IMPORTANT WARNING:${NC}
  • Always test SSH keys before running secure-ssh
  • Keep emergency script: /root/ssh_emergency_revert.sh
  • Have console access available

${CYAN}📚 Documentation:${NC}
  GitHub: ${BLUE}$REPO_URL${NC}
  Issues: ${BLUE}$REPO_URL/issues${NC}

${GREEN}🎉 Ready to secure your server!${NC}
EOF
    
    # Actually run secure-ssh in dry-run mode for immediate feedback (read-only)
    print_msg "$BLUE" "--- Running 'secure-ssh --dry-run' for immediate feedback ---"
    /usr/local/bin/secure-ssh --dry-run || true
}

# Main installation
main() {
    clear 2>/dev/null || true
    print_header "        sec-ur-serv Installation v$VERSION        "
    echo -e "${BLUE}        Secure SSH Hardening Tool by 13winged${NC}"
    echo ""

    check_root

    # Check for main SSH config file existence
    if [ ! -f /etc/ssh/sshd_config ]; then
        print_msg "$RED" "✗ ERROR: /etc/ssh/sshd_config missing!"
        print_msg "$YELLOW" "SSH server is likely not installed or configured. Please install OpenSSH server."
        echo ""
    fi

    # Check system requirements
    check_system() {
        print_header "Checking system requirements..."
        
        # Check for commands (apt-get, curl, ssh)
        if ! command -v apt-get &> /dev/null; then
            print_msg "$RED" "✗ ERROR: apt-get command not found."
            print_msg "$YELLOW" "This script requires a Debian/Ubuntu based system (apt-get)."
            exit 1
        fi
        
        # Check for curl
        if ! command -v curl &> /dev/null; then
            print_msg "$RED" "✗ ERROR: curl command not found."
            exit 1
        fi
        
        # Check for ssh
        if ! command -v ssh &> /dev/null; then
            print_msg "$RED" "✗ ERROR: ssh command not found."
            exit 1
        fi
        
        print_msg "$GREEN" "✓ System requirements met!"
    }

    # Run check
    check_system

    # Verify key auth works before touching anything
    check_ssh_connectivity

    # Show warning
    print_msg "$YELLOW" "⚠ WARNING: This tool will disable SSH password authentication"
    print_msg "$YELLOW" "  Make sure you have working SSH key access first!"
    echo ""
    
    read -p "Continue installation? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Installation cancelled"
        exit 0
    fi
    
    # Install steps
    install_deps
    download_scripts
    create_config
    create_uninstall
    
    # Final message
    show_completion
}

# Run
main
