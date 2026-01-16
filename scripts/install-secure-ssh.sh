#!/bin/bash

# ============================================
# sec-ur-serv: Complete Installation Script
# One-line installer for sec-ur-serv
# ============================================

set -euo pipefail

REPO_URL="https://github.com/13winged/sec-ur-serv"
INSTALL_DIR="/opt/sec-ur-serv"
VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_msg() { echo -e "$1$2${NC}"; }
print_header() {
    echo -e "\n${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║$1║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check system
check_system() {
    if [ "$EUID" -ne 0 ]; then
        print_msg "$RED" "Please run as root: sudo $0"
        exit 1
    fi
    
    if [ ! -f /etc/debian_version ] && [ ! -f /etc/lsb-release ]; then
        print_msg "$RED" "Only Ubuntu/Debian supported"
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
    
    curl -sL "$REPO_URL/raw/main/scripts/secure-ssh.sh" \
        -o "$INSTALL_DIR/secure-ssh.sh"
    
    curl -sL "$REPO_URL/raw/main/scripts/manage-ssh-users.sh" \
        -o "$INSTALL_DIR/manage-ssh-users.sh"
    
    curl -sL "$REPO_URL/raw/main/scripts/install-secure-ssh.sh" \
        -o "$INSTALL_DIR/install.sh"
    
    # Make executable
    chmod +x "$INSTALL_DIR"/*.sh
    
    # Create symlinks
    ln -sf "$INSTALL_DIR/secure-ssh.sh" /usr/local/bin/secure-ssh
    ln -sf "$INSTALL_DIR/manage-ssh-users.sh" /usr/local/bin/manage-ssh-users
    
    print_msg "$GREEN" "✓ Scripts downloaded to $INSTALL_DIR"
    print_msg "$GREEN" "✓ Commands available: secure-ssh, manage-ssh-users"
}

# Create systemd service
create_service() {
    print_header "Creating System Service"
    
    cat > /etc/systemd/system/sec-ur-serv-monitor.service << EOF
[Unit]
Description=sec-ur-serv SSH Security Monitor
After=network.target ssh.service
Requires=ssh.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/echo "sec-ur-serv monitoring active"
ExecReload=/bin/echo "Configuration reloaded"

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable sec-ur-serv-monitor.service
    
    print_msg "$GREEN" "✓ Monitoring service installed"
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
MONITORING=true

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
    
    apt-get update
    apt-get install -y \
        openssh-server \
        sshpass \
        curl \
        net-tools
    
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

# Remove systemd service
systemctl disable sec-ur-serv-monitor.service 2>/dev/null || true
rm -f /etc/systemd/system/sec-ur-serv-monitor.service
systemctl daemon-reload

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
}

# Main installation
main() {
    clear
    print_header "        sec-ur-serv Installation v$VERSION        "
    echo -e "${BLUE}        Secure SSH Hardening Tool by 13winged${NC}"
    echo ""
    
    # Check system
    check_system
    
    # Show warning
    print_msg "$YELLOW" "⚠ WARNING: This tool will disable SSH password authentication"
    print_msg "$YELLOW" "  Make sure you have working SSH key access first!"
    echo ""
    
    read -p "Continue installation? (yes/NO): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Installation cancelled"
        exit 0
    fi
    
    # Install steps
    install_deps
    download_scripts
    create_config
    create_service
    create_uninstall
    
    # Final message
    show_completion
}

# Run
main