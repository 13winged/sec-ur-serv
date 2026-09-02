## 🚨 CRITICAL WARNINGS: Mandatory Prerequisites
**SSH Key testing is the absolute first step.** Do not proceed until key authentication is verified.

*   **MANDATORY:** Always test SSH key access first (`ssh -o PasswordAuthentication=no localhost`).
*   **REQUIRED:** Ensure console access (physical/VPN) is available as a fallback.
*   **SAFETY:** Never close your current terminal session until the new configuration is validated.
*   **VERIFICATION:** Test connectivity from a *separate* terminal session before concluding setup.

### **Quick Verification:**
```bash
# Test SSH key authentication BEFORE proceeding
ssh -o PasswordAuthentication=no localhost
# Should connect WITHOUT asking for password
```

---

## 🚀 Quick Start: Initialize Setup

### **Install with One Command (Recommended)**
```bash
# Download and execute the complete security setup script
bash <(curl -s https://raw.githubusercontent.com/13winged/sec-ur-serv/main/scripts/install-secure-ssh.sh)
```

### **Install Manually**
```bash
# Clone the repository
git clone https://github.com/13winged/sec-ur-serv.git
cd sec-ur-serv

# Install the tool using the main script
sudo scripts/install-secure-ssh.sh
```

---

## ✅ Prerequisites Check

**Before proceeding, ensure you have:**

### **1. Working SSH Key Authentication**
```bash
ssh -o PasswordAuthentication=no localhost
# Should connect without password prompt
```

### **2. Required Access**
- ✅ Root/sudo access on the target server
- ✅ Console access (physical/VPN) as backup
- ✅ Another SSH session open for testing

### **3. System Compatibility**
- Ubuntu 18.04+ or Debian 10+
- OpenSSH server installed
- Bash 4.0+ available

---

## 📦 Installation

### **Option 1: Complete Installation (Recommended)**
```bash
# One-line installer (downloads and installs everything)
bash <(curl -s https://raw.githubusercontent.com/13winged/sec-ur-serv/main/scripts/install-secure-ssh.sh)
```

### **Option 2: Manual Installation**
```bash
# Clone and install manually
git clone https://github.com/13winged/sec-ur-serv.git
cd sec-ur-serv

# Make scripts executable
chmod +x scripts/*.sh

# Run installer
sudo scripts/install-secure-ssh.sh
```

### **Option 3: Direct Script Usage**
```bash
# Download individual scripts as needed
curl -O https://raw.githubusercontent.com/13winged/sec-ur-serv/main/scripts/secure-ssh.sh
chmod +x secure-ssh.sh
sudo ./secure-ssh.sh --dry-run
```

### **Post-Installation**
After installation, these commands become available:
- `secure-ssh` - Main security hardening tool
- `manage-ssh-users` - User management interface

---

## ⚙️ Usage: The Imperative Workflow
Follow these steps in strict sequence to ensure a secure transition.

### **Step 1: Validate SSH Key Access (CRITICAL)**
Verify your SSH keys function correctly without prompting for a password.
```bash
ssh -o PasswordAuthentication=no localhost
# If this fails, fix SSH keys NOW: ssh-keygen -t ed25519 && ssh-copy-id localhost
```

### **Step 2: Perform Dry Run (Non-Destructive Check)**
Run the tool to preview all configuration changes it *will* make.
```bash
sudo secure-ssh --dry-run
```

### **Step 3: Apply Security Hardening**
Execute the main command to apply all configured security patches.
```bash
sudo secure-ssh
```

### **Step 4: Manage Users (Post-Setup)**
Access the interactive menu to add, remove, or manage keys for existing users.
```bash
sudo manage-ssh-users
```

---

## 🔧 Command Line Options

### **Main Script Options**
```bash
sudo secure-ssh --dry-run     # Test without changes
sudo secure-ssh --help        # Show help
sudo secure-ssh --version     # Show version
```

### **User Management Commands**
```bash
sudo manage-ssh-users list              # List all users
sudo manage-ssh-users add username      # Add user
sudo manage-ssh-users remove username   # Remove user
sudo manage-ssh-users generate-key user # Generate SSH key
```

---

## 📋 Complete Workflow Example

```bash
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
```

---

## 🛡️ Security Features Implemented

### **SSH Configuration Changes**
| Setting | Before | After | Purpose |
|---------|--------|-------|---------|
| `PasswordAuthentication` | yes | **no** | Prevent brute force attacks |
| `PubkeyAuthentication` | yes | **yes** | Enable key-based auth |
| `PermitRootLogin` | yes/prohibit-password | **prohibit-password** | Secure root access |
| `AllowUsers` | (none) | **current_user** | Restrict access |
| `Protocol` | 1,2 | **2** | Disable outdated protocol |
| Encryption | Default | **Modern ciphers** | Stronger encryption |

### **Additional Security Measures**
- ✅ **Automatic backups** before any changes
- ✅ **Configuration validation** with `sshd -t`
- ✅ **Service monitoring** via systemd
- ✅ **Detailed logging** for audit trails
- ✅ **Emergency scripts** for recovery
- ✅ **Permission hardening** (700/600 for SSH files)

### **Encryption Algorithms Enabled**
- **Ciphers**: `chacha20-poly1305@openssh.com`, `aes256-gcm@openssh.com`, `aes128-gcm@openssh.com`
- **KEX**: `curve25519-sha256`, `curve25519-sha256@libssh.org`
- **MACs**: `hmac-sha2-512-etm@openssh.com`, `hmac-sha2-256-etm@openssh.com`

---

## 🆘 Emergency Recovery

### **If You Get Locked Out**

#### **Option 1: Use Emergency Script (Console Access Required)**
```bash
# From console/VPN/direct access
sudo /root/ssh_emergency_revert.sh
```

#### **Option 2: Manual Recovery**
```bash
# 1. Access server console
# 2. Edit SSH config
sudo nano /etc/ssh/sshd_config
# 3. Change: PasswordAuthentication no → yes
# 4. Restart SSH
sudo systemctl restart ssh
```

#### **Option 3: Single User Mode**
1. Reboot server
2. Interrupt boot process
3. Enter single-user/recovery mode
4. Mount filesystem read-write
5. Fix SSH configuration


Additional Security Measures
✅ Automatic backups before any changes

✅ Configuration validation with sshd -t

✅ Service monitoring via systemd

✅ Detailed logging for audit trails

✅ Emergency scripts for recovery

✅ Permission hardening (700/600 for SSH files)

Encryption Algorithms Enabled
**Ciphers:** `chacha20-poly1305@openssh.com`, `aes256-gcm@openssh.com`, `aes128-gcm@openssh.com`

**KEX:** `curve25519-sha256`, `curve25519-sha256@libssh.org`

**MACs:** `hmac-sha2-512-etm@openssh.com`, `hmac-sha2-256-etm@openssh.com`