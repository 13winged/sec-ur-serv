#!/bin/bash

# ============================================
# sec-ur-serv: Secure SSH Hardening Script
# ============================================

set -euo pipefail

# Version
VERSION="1.0.0"
SCRIPT_NAME="secure-ssh.sh"

# Color definitions
declare -A colors=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [CYAN]='\033[0;36m'
    [MAGENTA]='\033[0;35m'
    [NC]='\033[0m'
)

# Print colored messages
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${colors[$color]:-${colors[NC]}}$msg${colors[NC]}"
}

# Print header
print_header() {
    echo -e "\n${colors[CYAN]}╔════════════════════════════════════════════════════════════╗${colors[NC]}"
    echo -e "${colors[CYAN]}║                                                             ║$1${colors[NC]}"
    echo -e "${colors[CYAN]}╚════════════════════════════════════════════════════════════╝${colors[NC]}"
}

# Print section
print_section() {
    echo -e "\n${colors[BLUE]}▸ $1${colors[NC]}"
    echo -e "${colors[BLUE]}────────────────────────────────────────────────────────────${colors[NC]}"
}

# Show script info
show_info() {
    clear
    print_header "                     🔐 sec-ur-serv v${VERSION}                     "
    echo -e "${colors[MAGENTA]}      Secure SSH Hardening Tool by 13winged${colors[NC]}"
    echo -e "${colors[YELLOW]}       Repository: https://github.com/13winged/sec-ur-serv${colors[NC]}"
    echo ""
}

# Check root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_msg "RED" "✗ This script must be run as root"
        print_msg "YELLOW" "  Please run: sudo $0"
        exit 1
    fi
    print_msg "GREEN" "✓ Running with root privileges"
}

# Check system compatibility
check_system() {
    print_section "System Compatibility Check"
    
    # Check Ubuntu/Debian
    if [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
        print_msg "GREEN" "✓ Ubuntu/Debian system detected"
        
        # Get OS info
        if [ -f /etc/lsb-release ]; then
            . /etc/lsb-release
            echo "  Distribution: $DISTRIB_DESCRIPTION"
        else
            echo "  Debian $(cat /etc/debian_version)"
        fi
    else
        print_msg "RED" "✗ Unsupported system"
        print_msg "YELLOW" "  This script is designed for Ubuntu/Debian only"
        exit 1
    fi
    
    # Check SSH
    if ! command -v ssh &> /dev/null; then
        print_msg "RED" "✗ SSH client not found"
        exit 1
    fi
    
    if ! systemctl is-active --quiet ssh; then
        print_msg "YELLOW" "⚠ SSH service is not running"
        print_msg "BLUE" "  Starting SSH service..."
        systemctl start ssh
    fi
    
    print_msg "GREEN" "✓ SSH service is active"
}

# Test SSH key authentication
test_ssh_key_auth() {
    local user=${1:-$(logname)}
    local timeout=${2:-5}
    
    print_section "Testing SSH Key Authentication"
    print_msg "BLUE" "Testing SSH key access for user: $user"
    
    # Try to connect using SSH key
    if sudo -u "$user" ssh -o PasswordAuthentication=no \
                           -o ConnectTimeout=$timeout \
                           -o BatchMode=yes \
                           -o StrictHostKeyChecking=no \
                           localhost "echo '✅ SSH key test successful'" 2>/dev/null; then
        print_msg "GREEN" "✓ SSH key authentication works for $user"
        return 0
    else
        print_msg "RED" "✗ SSH key authentication FAILED for $user"
        print_msg "YELLOW" "  Reason: SSH key not configured or invalid"
        print_msg "BLUE" "  Solution:"
        echo "    1. Generate SSH key: ssh-keygen -t ed25519"
        echo "    2. Copy to server: ssh-copy-id $user@localhost"
        echo "    3. Test again: ssh -o PasswordAuthentication=no localhost"
        return 1
    fi
}

# Check user SSH keys
check_user_keys() {
    local user=${1:-$(logname)}
    local home_dir=$(getent passwd "$user" | cut -d: -f6)
    local auth_keys="$home_dir/.ssh/authorized_keys"
    
    if [ -f "$auth_keys" ] && [ -s "$auth_keys" ]; then
        local key_count=$(grep -c "^ssh-" "$auth_keys" 2>/dev/null || echo 0)
        if [ "$key_count" -gt 0 ]; then
            print_msg "GREEN" "✓ User $user has $key_count SSH key(s)"
            
            # Show key types
            print_msg "BLUE" "  Key types found:"
            grep "^ssh-" "$auth_keys" | while read -r line; do
                echo "$line" | cut -d' ' -f1 | sed 's/ssh-//'
            done | sort -u | while read -r type; do
                echo "    • $type"
            done
            
            return 0
        fi
    fi
    
    print_msg "RED" "✗ User $user has NO valid SSH keys"
    return 1
}

# Backup SSH configuration
backup_config() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="/etc/ssh/backup_$timestamp"
    
    print_section "Creating Backup"
    
    mkdir -p "$backup_dir"
    
    # Backup main config
    cp /etc/ssh/sshd_config "$backup_dir/sshd_config.original"
    
    # Backup config.d directory
    if [ -d /etc/ssh/sshd_config.d ]; then
        cp -r /etc/ssh/sshd_config.d "$backup_dir/"
    fi
    
    # Backup authorized_keys for current user
    local user=$(logname)
    local home_dir=$(getent passwd "$user" | cut -d: -f6)
    if [ -f "$home_dir/.ssh/authorized_keys" ]; then
        cp "$home_dir/.ssh/authorized_keys" "$backup_dir/authorized_keys.$user"
    fi
    
    print_msg "GREEN" "✓ Backup created at: $backup_dir"
    echo "$backup_dir"
}

# Create emergency recovery script
create_emergency_script() {
    local script_path="/root/ssh_emergency_revert.sh"
    
    print_section "Creating Emergency Recovery Script"
    
    cat > "$script_path" << 'EOF'
#!/bin/bash
# ============================================
# sec-ur-serv: Emergency SSH Recovery Script
# Use this if you get locked out of the system
# ============================================

set -e

echo "🔓 EMERGENCY SSH RECOVERY SCRIPT"
echo "=================================="
echo ""

# Find latest backup
BACKUP_DIR=$(find /etc/ssh -name "backup_*" -type d | sort -r | head -1)

if [ -z "$BACKUP_DIR" ]; then
    echo "❌ ERROR: No backup directory found!"
    echo "Please restore SSH configuration manually."
    exit 1
fi

echo "📦 Found backup: $BACKUP_DIR"
echo ""

# Restore configuration
echo "🔄 Restoring SSH configuration..."
cp "$BACKUP_DIR/sshd_config.original" /etc/ssh/sshd_config

# Restore config.d files
if [ -d "$BACKUP_DIR/sshd_config.d" ]; then
    rm -rf /etc/ssh/sshd_config.d
    cp -r "$BACKUP_DIR/sshd_config.d" /etc/ssh/
fi

# Enable password authentication temporarily
echo "🔑 Enabling password authentication temporarily..."
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service
echo "🔄 Restarting SSH service..."
systemctl restart ssh

echo ""
echo "✅ RECOVERY COMPLETE"
echo "===================="
echo ""
echo "SSH configuration has been restored from backup."
echo "Password authentication has been temporarily enabled."
echo ""
echo "⚠ IMPORTANT NEXT STEPS:"
echo "   1. Test SSH login with password"
echo "   2. Fix your SSH key configuration"
echo "   3. Review authorized_keys files"
echo "   4. Run sec-ur-serv again when ready"
echo ""
echo "📋 User home directories to check:"
for user in $(getent passwd | cut -d: -f1,6 | grep -E "/(home|root)/" | cut -d: -f1); do
    home=$(getent passwd "$user" | cut -d: -f6)
    if [ -f "$home/.ssh/authorized_keys" ]; then
        echo "  - $user: $home/.ssh/authorized_keys"
    fi
done
EOF
    
    chmod 700 "$script_path"
    print_msg "GREEN" "✓ Emergency script created: $script_path"
    print_msg "YELLOW" "⚠ IMPORTANT: Keep this script safe! Use it if locked out."
}

# Generate secure SSH configuration
generate_secure_config() {
    local config_file="/etc/ssh/sshd_config"
    local temp_file="/tmp/sshd_config.secure"
    local current_user=$(logname)
    
    print_section "Generating Secure SSH Configuration"
    
    # Create new secure configuration
    cat > "$temp_file" << 'EOF'
# ============================================
# sec-ur-serv: Secure SSH Configuration
# Generated by sec-ur-serv v1.0.0
# https://github.com/13winged/sec-ur-serv
# ============================================

# Basic Settings
Port 22
Protocol 2
ListenAddress 0.0.0.0
SyslogFacility AUTH
LogLevel VERBOSE

# Authentication Settings
LoginGraceTime 60
PermitRootLogin prohibit-password
StrictModes yes
MaxAuthTries 3
MaxSessions 10

# Password Authentication - DISABLED
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitEmptyPasswords no
UsePAM no

# Public Key Authentication - ENABLED
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2
IgnoreUserKnownHosts no
IgnoreRhosts yes
HostbasedAuthentication no

# User Access Control
AllowUsers CURRENT_USER
DenyUsers *
DenyGroups *

# Encryption Settings (Modern, Secure)
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# Connection Settings
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive yes
Compression no
UseDNS no

# Forwarding Restrictions
AllowTcpForwarding yes
GatewayPorts no
X11Forwarding no
X11DisplayOffset 10
X11UseLocalhost yes
PermitTTY yes
PrintMotd yes
PrintLastLog yes
PermitUserEnvironment no

# Chroot and Security
UsePrivilegeSeparation sandbox
AllowAgentForwarding yes
AllowStreamLocalForwarding no
StreamLocalBindUnlink yes
EOF
    
    # Replace CURRENT_USER with actual username
    sed -i "s/CURRENT_USER/$current_user/g" "$temp_file"
    
    # Backup current config
    local backup_dir=$(backup_config)
    
    # Apply new configuration
    cp "$temp_file" "$config_file"
    chmod 600 "$config_file"
    
    # Remove any conflicting configs in sshd_config.d
    if [ -d /etc/ssh/sshd_config.d ]; then
        for file in /etc/ssh/sshd_config.d/*.conf; do
            if [ -f "$file" ]; then
                # Remove any configs that would conflict
                grep -q "PasswordAuthentication\|PubkeyAuthentication\|PermitRootLogin" "$file" && \
                mv "$file" "$file.disabled"
            fi
        done
    fi
    
    print_msg "GREEN" "✓ Secure SSH configuration applied"
    print_msg "BLUE" "  Backup location: $backup_dir"
}

# Verify configuration
verify_config() {
    print_section "Verifying SSH Configuration"
    
    # Check syntax
    if sshd -t 2>/dev/null; then
        print_msg "GREEN" "✓ SSH configuration syntax is valid"
    else
        print_msg "RED" "✗ SSH configuration has syntax errors"
        print_msg "YELLOW" "  Run 'sshd -t' to see details"
        return 1
    fi
    
    # Verify critical settings
    local checks=(
        "PasswordAuthentication no"
        "PubkeyAuthentication yes"
        "PermitRootLogin prohibit-password"
        "AllowUsers $(logname)"
    )
    
    local all_ok=true
    for check in "${checks[@]}"; do
        if grep -q "^$check" /etc/ssh/sshd_config; then
            print_msg "GREEN" "✓ $check"
        else
            print_msg "RED" "✗ Missing: $check"
            all_ok=false
        fi
    done
    
    if [ "$all_ok" = false ]; then
        return 1
    fi
    
    return 0
}

# Restart SSH service
restart_ssh_service() {
    print_section "Restarting SSH Service"
    
    print_msg "BLUE" "Restarting SSH service..."
    
    if systemctl restart ssh; then
        print_msg "GREEN" "✓ SSH service restarted successfully"
        
        # Wait for service to be fully up
        sleep 2
        
        if systemctl is-active --quiet ssh; then
            print_msg "GREEN" "✓ SSH service is running"
        else
            print_msg "RED" "✗ SSH service failed to start"
            return 1
        fi
    else
        print_msg "RED" "✗ Failed to restart SSH service"
        return 1
    fi
    
    return 0
}

# Final verification test
final_verification() {
    local user=$(logname)
    
    print_section "Final Verification"
    
    # Test 1: SSH key authentication should work
    print_msg "BLUE" "Test 1: Verifying SSH key authentication..."
    if test_ssh_key_auth "$user" 3; then
        print_msg "GREEN" "✓ SSH key authentication works"
    else
        print_msg "RED" "✗ SSH key authentication failed"
        return 1
    fi
    
    # Test 2: Password authentication should fail
    print_msg "BLUE" "Test 2: Verifying password authentication is disabled..."
    
    # Install sshpass if not present (just for test)
    if ! command -v sshpass &> /dev/null; then
        apt-get update && apt-get install -y sshpass > /dev/null 2>&1
    fi
    
    # Try to connect with password (should fail)
    if sshpass -p 'wrongpassword' ssh -o ConnectTimeout=3 \
                                      -o PasswordAuthentication=yes \
                                      -o PubkeyAuthentication=no \
                                      "$user@localhost" "echo test" 2>&1 | \
        grep -q "Permission denied"; then
        print_msg "GREEN" "✓ Password authentication correctly rejected"
    else
        print_msg "YELLOW" "⚠ Could not verify password authentication status"
    fi
    
    # Test 3: Check SSH service status
    print_msg "BLUE" "Test 3: Checking SSH service..."
    if systemctl is-active --quiet ssh; then
        print_msg "GREEN" "✓ SSH service is active"
    else
        print_msg "RED" "✗ SSH service is not running"
        return 1
    fi
    
    return 0
}

# Generate summary report
generate_summary() {
    local user=$(logname)
    local report_file="/root/sec-ur-serv-report-$(date +%Y%m%d_%H%M%S).txt"
    
    print_section "Generating Security Report"
    
    cat > "$report_file" << EOF
╔════════════════════════════════════════════════════════════╗
║                  sec-ur-serv Security Report               ║
╚════════════════════════════════════════════════════════════╝

Report Date: $(date)
Hostname: $(hostname)
User: $user
Script Version: $VERSION

────────────────────────────────────────────────────────────
SYSTEM INFORMATION
────────────────────────────────────────────────────────────
OS: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/debian_version)
Kernel: $(uname -r)
Architecture: $(uname -m)

────────────────────────────────────────────────────────────
SSH CONFIGURATION STATUS
────────────────────────────────────────────────────────────
Password Authentication: DISABLED
Public Key Authentication: ENABLED
Root Login: prohibit-password
Allowed Users: $user

Critical Settings:
$(grep -E "^(PasswordAuthentication|PubkeyAuthentication|PermitRootLogin|AllowUsers)" /etc/ssh/sshd_config)

────────────────────────────────────────────────────────────
BACKUP INFORMATION
────────────────────────────────────────────────────────────
Backup Directory: $(find /etc/ssh -name "backup_*" -type d | sort -r | head -1)

────────────────────────────────────────────────────────────
EMERGENCY RECOVERY
────────────────────────────────────────────────────────────
Emergency Script: /root/ssh_emergency_revert.sh
Usage: sudo /root/ssh_emergency_revert.sh

────────────────────────────────────────────────────────────
USER SSH KEYS
────────────────────────────────────────────────────────────
User: $user
Authorized Keys: $HOME/.ssh/authorized_keys
Key Count: $(grep -c "^ssh-" "$HOME/.ssh/authorized_keys" 2>/dev/null || echo 0)

────────────────────────────────────────────────────────────
SECURITY RECOMMENDATIONS
────────────────────────────────────────────────────────────
1. Keep emergency script in safe location
2. Regularly update SSH keys
3. Monitor SSH logs: journalctl -u ssh
4. Consider changing default SSH port
5. Set up fail2ban for additional protection
6. Regularly update system: apt update && apt upgrade

────────────────────────────────────────────────────────────
QUICK COMMANDS
────────────────────────────────────────────────────────────
Check SSH status: systemctl status ssh
View SSH logs: journalctl -u ssh -f
Add new user: adduser username && ssh-copy-id username@localhost
Update config: nano /etc/ssh/sshd_config
Test connection: ssh -o PasswordAuthentication=no localhost

────────────────────────────────────────────────────────────
⚠ IMPORTANT WARNINGS
────────────────────────────────────────────────────────────
• Password authentication is DISABLED
• Only SSH key access is allowed
• Test from another session before closing this one
• Keep private keys secure
• Backup your .ssh directory regularly

────────────────────────────────────────────────────────────

EOF
    
    chmod 600 "$report_file"
    print_msg "GREEN" "✓ Security report generated: $report_file"
    
    # Show important parts of the report
    echo ""
    print_msg "CYAN" "📋 REPORT HIGHLIGHTS:"
    grep -A2 -B2 "DISABLED\|ENABLED\|EMERGENCY\|WARNINGS" "$report_file" | head -20
}

# Show completion message
show_completion() {
    local user=$(logname)
    
    print_header "                     🎉 SETUP COMPLETE!                     "
    
    cat << EOF

${colors[GREEN]}✅ sec-ur-serv has successfully secured your SSH configuration!${colors[NC]}

${colors[CYAN]}📊 SUMMARY OF CHANGES:${colors[NC]}
────────────────────────────────────────────────────────────
• Password authentication: ${colors[RED]}DISABLED${colors[NC]}
• SSH key authentication: ${colors[GREEN]}ENABLED${colors[NC]}
• Root login with password: ${colors[RED]}DISABLED${colors[NC]}
• User restrictions applied: ${colors[GREEN]}$user only${colors[NC]}
• Secure encryption algorithms: ${colors[GREEN]}CONFIGURED${colors[NC]}

${colors[CYAN]}🔐 SECURITY STATUS:${colors[NC]}
────────────────────────────────────────────────────────────
✓ SSH service: ${colors[GREEN]}Running${colors[NC]}
✓ Configuration: ${colors[GREEN]}Valid${colors[NC]}
✓ Key authentication: ${colors[GREEN]}Working${colors[NC]}
✓ Emergency recovery: ${colors[GREEN]}Ready${colors[NC]}

${colors[CYAN]}🚨 CRITICAL INFORMATION:${colors[NC]}
────────────────────────────────────────────────────────────
${colors[YELLOW]}⚠ You can ONLY login via SSH key now!${colors[NC]}
${colors[YELLOW]}⚠ Test from another terminal BEFORE closing this session!${colors[NC]}
${colors[YELLOW]}⚠ Emergency script: /root/ssh_emergency_revert.sh${colors[NC]}

${colors[CYAN]}🚀 NEXT STEPS:${colors[NC]}
────────────────────────────────────────────────────────────
1. ${colors[GREEN]}Open another SSH session and test connection${colors[NC]}
2. ${colors[BLUE]}Add more users: edit /etc/ssh/sshd_config${colors[NC]}
3. ${colors[BLUE]}Consider changing SSH port for security${colors[NC]}
4. ${colors[BLUE]}Set up fail2ban for brute force protection${colors[NC]}

${colors[CYAN]}📞 SUPPORT:${colors[NC]}
────────────────────────────────────────────────────────────
GitHub: ${colors[MAGENTA]}https://github.com/13winged/sec-ur-serv${colors[NC]}
Issues: ${colors[MAGENTA]}https://github.com/13winged/sec-ur-serv/issues${colors[NC]}

${colors[YELLOW]}⚠ FINAL WARNING: If you get locked out, use:${colors[NC]}
${colors[RED]}   sudo /root/ssh_emergency_revert.sh${colors[NC]}

${colors[GREEN]}✨ Thank you for using sec-ur-serv!${colors[NC]}
EOF
}

# Main execution flow
main() {
    show_info
    
    # Check prerequisites
    check_root
    check_system
    
    # Get current user
    CURRENT_USER=$(logname)
    if [ -z "$CURRENT_USER" ]; then
        CURRENT_USER=$(who am i | awk '{print $1}')
    fi
    
    print_header "               Starting Security Hardening               "
    print_msg "BLUE" "Target user: $CURRENT_USER"
    print_msg "BLUE" "Hostname: $(hostname)"
    echo ""
    
    # Check if user has SSH keys
    if ! check_user_keys "$CURRENT_USER"; then
        print_msg "RED" "✗ Cannot proceed without SSH keys"
        print_msg "YELLOW" "  Generate SSH keys first:"
        echo ""
        echo "  Steps to fix:"
        echo "  1. Generate key: ssh-keygen -t ed25519"
        echo "  2. Copy to server: ssh-copy-id $CURRENT_USER@localhost"
        echo "  3. Test: ssh -o PasswordAuthentication=no localhost"
        echo "  4. Run this script again"
        exit 1
    fi
    
    # Test SSH key authentication
    if ! test_ssh_key_auth "$CURRENT_USER"; then
        print_msg "RED" "✗ SSH key authentication test failed"
        exit 1
    fi
    
    # Create emergency recovery script
    create_emergency_script
    
    # Apply secure configuration
    generate_secure_config
    
    # Verify configuration
    if ! verify_config; then
        print_msg "RED" "✗ Configuration verification failed"
        exit 1
    fi
    
    # Restart SSH service
    if ! restart_ssh_service; then
        print_msg "RED" "✗ Failed to restart SSH service"
        exit 1
    fi
    
    # Final verification
    if ! final_verification; then
        print_msg "RED" "✗ Final verification failed"
        print_msg "YELLOW" "  Use emergency script if needed: /root/ssh_emergency_revert.sh"
        exit 1
    fi
    
    # Generate summary report
    generate_summary
    
    # Show completion message
    show_completion
}

# Dry-run mode
dry_run() {
    show_info
    print_header "                    🧪 DRY RUN MODE                    "
    
    print_msg "YELLOW" "This is a dry run. No changes will be made."
    echo ""
    
    check_system
    
    CURRENT_USER=$(logname)
    print_section "System Check Results"
    print_msg "BLUE" "Current user: $CURRENT_USER"
    
    # Check SSH keys
    if check_user_keys "$CURRENT_USER"; then
        print_msg "GREEN" "✓ User has SSH keys"
    else
        print_msg "RED" "✗ User needs SSH keys"
    fi
    
    # Test SSH key auth
    if test_ssh_key_auth "$CURRENT_USER" 2; then
        print_msg "GREEN" "✓ SSH key authentication works"
    else
        print_msg "RED" "✗ SSH key authentication would fail"
    fi
    
    print_section "Proposed Changes"
    echo "• Disable password authentication"
    echo "• Enable SSH key authentication only"
    echo "• Restrict root login"
    echo "• Allow only user: $CURRENT_USER"
    echo "• Apply modern encryption algorithms"
    echo "• Create backup and emergency script"
    
    print_section "Dry Run Complete"
    print_msg "GREEN" "✓ System is ready for hardening"
    print_msg "BLUE" "  Run without --dry-run to apply changes"
}

# Show help
show_help() {
    show_info
    cat << EOF

Usage: $0 [OPTION]

Options:
  --dry-run     Test configuration without making changes
  --help        Show this help message
  --version     Show version information

Examples:
  sudo $0                    # Apply security hardening
  sudo $0 --dry-run         # Test without changes
  sudo $0 --help            # Show this help

Description:
  sec-ur-serv is a security hardening tool that disables
  password authentication and enables SSH key-only access
  for Ubuntu/Debian servers.

⚠ WARNING:
  Always test SSH key access before running this script!
  Have console access available as a backup.

For more information, visit:
  https://github.com/13winged/sec-ur-serv

EOF
}

# Show version
show_version() {
    echo "sec-ur-serv v$VERSION"
    echo "Secure SSH hardening tool by 13winged"
    echo "https://github.com/13winged/sec-ur-serv"
}

# Parse arguments
case "${1:-}" in
    "--dry-run"|"-d")
        dry_run
        ;;
    "--help"|"-h")
        show_help
        ;;
    "--version"|"-v")
        show_version
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac