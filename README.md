⚠️ CRITICAL WARNING: Always test SSH key access before running this tool! Have console access available as backup.
⚠️ DO NOT CLOSE YOUR CURRENT SESSION YET!

### Quick Start
One-line Installation & Setup
bash
# Download and run the complete security setup
bash <(curl -s https://raw.githubusercontent.com/13winged/sec-ur-serv/main/scripts/install-secure-ssh.sh)
Manual Installation
bash
# Clone repository
git clone https://github.com/13winged/sec-ur-serv.git
cd sec-ur-serv

# Install the tool
sudo scripts/install-secure-ssh.sh
Prerequisites Check
Before proceeding, ensure you have:

Working SSH key authentication:

bash
ssh -o PasswordAuthentication=no localhost
# Should connect without password prompt
Root/sudo access on the target server

Console access (physical/VPN) as backup

Another SSH session open for testing

### Installation
Option 1: Complete Installation (Recommended)
bash
# One-line installer (downloads and installs everything)
bash <(curl -s https://raw.githubusercontent.com/13winged/sec-ur-serv/main/scripts/install-secure-ssh.sh)
Option 2: Manual Installation
bash
# Clone and install manually
git clone https://github.com/13winged/sec-ur-serv.git
cd sec-ur-serv

# Make scripts executable
chmod +x scripts/*.sh

# Run installer
sudo scripts/install-secure-ssh.sh
Option 3: Direct Script Usage
bash
# Download individual scripts as needed
curl -O https://raw.githubusercontent.com/13winged/sec-ur-serv/main/scripts/secure-ssh.sh
chmod +x secure-ssh.sh
sudo ./secure-ssh.sh --dry-run
Post-Installation
After installation, these commands become available:

secure-ssh - Main security hardening tool

manage-ssh-users - User management interface

### Usage
1. Test SSH Keys (CRITICAL FIRST STEP)
bash
# Verify your SSH keys work
ssh -o PasswordAuthentication=no localhost
# If this fails, DO NOT proceed!
2. Dry Run (Safe Testing)
bash
# Test configuration without making changes
sudo secure-ssh --dry-run
3. Apply Security Hardening
bash
# Apply all security changes
sudo secure-ssh
4. Manage Users
bash
# Interactive menu for user management
sudo manage-ssh-users
Command Line Options
bash
# Main script options
sudo secure-ssh --dry-run     # Test without changes
sudo secure-ssh --help        # Show help
sudo secure-ssh --version     # Show version

# User management commands
sudo manage-ssh-users list              # List all users
sudo manage-ssh-users add username      # Add user
sudo manage-ssh-users remove username   # Remove user
sudo manage-ssh-users generate-key user # Generate SSH key
Complete Workflow Example
bash
# 1. First, test your current setup
ssh -o PasswordAuthentication=no localhost

# 2. Run dry-run to see proposed changes
sudo secure-ssh --dry-run

# 3. Apply security hardening
sudo secure-ssh

# 4. Open NEW SSH session to test
#    (Keep current session open!)

# 5. Add additional users if needed
sudo manage-ssh-users add developer
sudo manage-ssh-users generate-key developer

# 6. Verify everything works
sudo manage-ssh-users test developer

### Emergency Recovery
If You Get Locked Out
Option 1: Use Emergency Script (Console Access Required)
bash
# From console/VPN/direct access
sudo /root/ssh_emergency_revert.sh
Option 2: Manual Recovery
bash
# 1. Access server console
# 2. Edit SSH config
sudo nano /etc/ssh/sshd_config
# 3. Change: PasswordAuthentication no → yes
# 4. Restart SSH
sudo systemctl restart ssh
Option 3: Single User Mode
Reboot server

Interrupt boot process

Enter single-user/recovery mode

Mount filesystem read-write

Fix SSH configuration


Additional Security Measures
✅ Automatic backups before any changes

✅ Configuration validation with sshd -t

✅ Service monitoring via systemd

✅ Detailed logging for audit trails

✅ Emergency scripts for recovery

✅ Permission hardening (700/600 for SSH files)

Encryption Algorithms Enabled
Ciphers: chacha20-poly1305@openssh.com, aes256-gcm@openssh.com, aes128-gcm@openssh.com

KEX: curve25519-sha256, curve25519-sha256@libssh.org

MACs: hmac-sha2-512-etm@openssh.com, hmac-sha2-256-etm@openssh.com