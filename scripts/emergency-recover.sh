#!/bin/bash

# ============================================
# sec-ur-serv: Emergency Recovery Script
# Use this if locked out after securing SSH
# ============================================

set -e

print_header() {
    echo ""
    echo "=================================="
    echo "🔓 sec-ur-serv Emergency Recovery"
    echo "=================================="
    echo ""
}

print_msg() {
    echo ">>> $1"
}

# Check for root
if [ "$EUID" -ne 0 ]; then
    print_msg "❌ Please run as root: sudo $0"
    exit 1
fi

# Check if SSH service is running before proceeding
print_msg "🔍 Checking SSH service status..."
systemctl is-active ssh > /dev/null 2>&1
if [ $? -ne 0 ]; then
    print_msg "❌ SSH service is NOT running! Attempting to start it..."
    systemctl start ssh
    sleep 2
    systemctl is-active ssh > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_msg "❌ Failed to start SSH service. Exiting."
        exit 1
    fi
fi

# Find latest backup
echo "🔍 Looking for backups..."
BACKUP_DIR=$(find /etc/ssh -maxdepth 1 -name "backup_*" -type d | sort -r | head -1)

if [ -z "$BACKUP_DIR" ]; then
    echo "❌ No backup found!"
    echo ""
    echo "Manual recovery options:"
    echo "1. Use console access (direct/VPN)"
    echo "2. Boot into single-user/recovery mode"
    echo "3. Restore from snapshot/backup"
    exit 1
fi

echo "✅ Found backup: $BACKUP_DIR"
echo ""

# Show backup contents
echo "📦 Backup contents:"
ls -la "$BACKUP_DIR/"
echo ""

# Confirm recovery
read -p "⚠ Restore SSH configuration from backup? (yes/NO): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Recovery cancelled"
    exit 0
fi

# Restore configuration
echo "🔄 Restoring SSH configuration..."
cp "$BACKUP_DIR/sshd_config.original" /etc/ssh/sshd_config

# Restore config.d if exists
if [ -d "$BACKUP_DIR/sshd_config.d" ]; then
    echo "Restoring config.d directory..."
    rm -rf /etc/ssh/sshd_config.d 2>/dev/null || true
    cp -r "$BACKUP_DIR/sshd_config.d" /etc/ssh/
fi

# Enable password authentication
echo "🔑 Enabling password authentication..."
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config

# Restart SSH
echo "🔄 Restarting SSH service..."
systemctl restart ssh

echo ""
echo "✅ RECOVERY COMPLETE"
echo "==================="
echo ""
echo "SSH configuration has been restored."
echo "Password authentication is now ENABLED."
echo ""
echo "⚠ IMPORTANT:"
echo "• Test SSH login with password"
echo "• Fix your SSH key configuration"
echo "• Consider running 'secure-ssh' again when ready"
echo ""
echo "📋 Check these files for issues:"
for user in $(getent passwd | cut -d: -f1); do
    home=$(getent passwd "$user" | cut -d: -f6)
    if [ -f "$home/.ssh/authorized_keys" ]; then
        echo "  $user: $home/.ssh/authorized_keys"
    fi
done
echo ""
echo "🔧 Next steps:"
echo "  1. ssh user@localhost (with password)"
echo "  2. Check .ssh/authorized_keys permissions"
echo "  3. Verify SSH keys are correct"
echo "  4. Test: ssh -o PasswordAuthentication=no localhost"
echo ""