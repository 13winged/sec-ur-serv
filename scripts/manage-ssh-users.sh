#!/bin/bash

# ============================================
# sec-ur-serv: SSH User Management Tool
# ============================================

set -euo pipefail

VERSION="2.0.0"
SCRIPT_NAME="manage-ssh-users.sh"

# Colors
declare -A colors=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [CYAN]='\033[0;36m'
    [NC]='\033[0m'
)

print_msg() { echo -e "${colors[$1]:-${colors[NC]}}$2${colors[NC]}"; }
print_header() { echo -e "\n${colors[CYAN]}=== $1 ===${colors[NC]}\n"; }

# Check root
check_root() {
    [ "$EUID" -eq 0 ] || {
        print_msg "RED" "Requires root. Run: sudo $0"
        exit 1
    }
}

# Show menu
show_menu() {
    clear
    print_header "🔐 sec-ur-serv User Management v$VERSION"
    
    echo "1. List SSH users and keys"
    echo "2. Add user to SSH access"
    echo "3. Remove user from SSH access"
    echo "4. Generate SSH key for user"
    echo "5. Show SSH configuration"
    echo "6. Test SSH access for user"
    echo "7. Backup SSH configurations"
    echo "8. Restore from backup"
    echo "9. Switch User"
    echo "# Update Key (New Function)"
    echo ""
}

# List SSH users
list_users() {
    print_header "Current SSH Users"
    
    # Get allowed users from config
    local allowed_users=$(grep "^AllowUsers" /etc/ssh/sshd_config 2>/dev/null | cut -d' ' -f2-)
    
    if [ -n "$allowed_users" ]; then
        print_msg "GREEN" "Allowed SSH Users:"
        echo "$allowed_users" | tr ' ' '\n' | while read -r user; do
            echo "  • $user"
            
            # Check if user exists
            if id "$user" &>/dev/null; then
                local home=$(getent passwd "$user" | cut -d: -f6)
                local keys_file="$home/.ssh/authorized_keys"
                
                if [ -f "$keys_file" ]; then
                    local key_count=$(grep -c "^ssh-" "$keys_file" 2>/dev/null || echo 0)
                    echo "    Keys: $key_count"
                    
                    # Show key types
                    grep "^ssh-" "$keys_file" 2>/dev/null | head -2 | while read -r line; do
                        local key_type=$(echo "$line" | cut -d' ' -f1 | sed 's/ssh-//')
                        local comment=$(echo "$line" | cut -d' ' -f3-)
                        echo "    Type: $key_type - $comment"
                    done
                else
                    print_msg "RED" "    No SSH keys! (Will be locked out)"
                fi
            else
                print_msg "YELLOW" "    User account not found"
            fi
            echo ""
        done
    else
        print_msg "YELLOW" "No user restrictions in SSH config (all users allowed)"
    fi
    
    # Show recent SSH logins
    print_header "Recent SSH Logins"
    last -10 | grep -E "ssh.*pts" || echo "  No recent SSH logins found"
}

# Update Key (New Function)
add_user() {
    local user=$1
    
    print_header "Adding User: $user"
    
    # Check if user exists
    if ! id -u "$USERNAME" &> /dev/null; then
        print_msg "RED" "User $USERNAME does not exist"
        print_msg "RED" "Error: User $USERNAME not found."
        return 1
    fi
    
    # Add to AllowUsers in sshd_config
    if grep -q "^AllowUsers" /etc/ssh/sshd_config; then
        # Check if already in list
        if grep -q "AllowUsers.*\b$user\b" /etc/ssh/sshd_config; then
            print_msg "YELLOW" "User $user already in AllowUsers list"
        else
            # Append to existing list
            sed -i "s/^AllowUsers \(.*\)$/AllowUsers \1 $user/" /etc/ssh/sshd_config
            print_msg "GREEN" "Added $user to AllowUsers"
        fi
    else
        # Create new AllowUsers line
        echo "AllowUsers $user" >> /etc/ssh/sshd_config
        print_msg "GREEN" "Created AllowUsers with $user"
    fi
    
    # Setup .ssh directory
    local home=$(getent passwd "$user" | cut -d: -f6)
    mkdir -p "$home/.ssh"
    chmod 700 "$home/.ssh"
    chown -R "$user:$user" "$home/.ssh"
    
    print_msg "GREEN" "Created .ssh directory for $user"
    
    # Ask about generating key
    read -p "Generate SSH key for $user? (Y/n): " -n 1 gen_key
    echo ""
    
    if [[ ! $gen_key =~ ^[Nn]$ ]]; then
        generate_key "$user"
    fi
    
    return 0
}
    if grep -q "^AllowUsers" /etc/ssh/sshd_config; then
        # Check if already in list
        if grep -q "AllowUsers.*\b$user\b" /etc/ssh/sshd_config; then
            print_msg "YELLOW" "User $user already in AllowUsers list"
        else
            # Append to existing list
            sed -i "s/^AllowUsers \(.*\)$/AllowUsers \1 $user/" /etc/ssh/sshd_config
            print_msg "GREEN" "Added $user to AllowUsers"
        fi
    else
        # Create new AllowUsers line
        echo "AllowUsers $user" >> /etc/ssh/sshd_config
        print_msg "GREEN" "Created AllowUsers with $user"
    fi
    
    # Setup .ssh directory
    local home=$(getent passwd "$user" | cut -d: -f6)
    mkdir -p "$home/.ssh"
    chmod 700 "$home/.ssh"
    chown -R "$user:$user" "$home/.ssh"
    
    print_msg "GREEN" "Created .ssh directory for $user"
    
    # Ask about generating key
    read -p "Generate SSH key for $user? (Y/n): " -n 1 gen_key
    echo ""
    
    if [[ ! $gen_key =~ ^[Nn]$ ]]; then
        generate_key "$user"
    fi
    
    return 0
}

# Update Key (New Function)
remove_user() {
    local user=$1
    
    print_header "Removing User: $user"
    
    # Remove from AllowUsers
    if grep -q "AllowUsers.*\b$user\b" /etc/ssh/sshd_config; then
        # Remove user from line
        sed -i "s/\b$user\b//g" /etc/ssh/sshd_config
        # Clean up extra spaces
        sed -i "s/AllowUsers  */AllowUsers /g" /etc/ssh/sshd_config
        # Remove empty AllowUsers line
        sed -i "/^AllowUsers $/d" /etc/ssh/sshd_config
        
        print_msg "GREEN" "Removed $user from AllowUsers"
    else
        print_msg "YELLOW" "User $user not in AllowUsers list"
    fi
    
    # Warn about existing keys
    local home=$(getent passwd "$user" | cut -d: -f6 2>/dev/null)
    if [ -n "$home" ] && [ -f "$home/.ssh/authorized_keys" ]; then
        print_msg "YELLOW" "Warning: $user still has SSH keys in $home/.ssh/authorized_keys"
        print_msg "YELLOW" "Remove manually if needed"
    fi
}

# Update Key (New Function)
generate_key() {
    local user=$1
    local key_type=${2:-ed25519}
    
    print_header "Generating SSH Key for $user"
    
    if ! id "$user" &>/dev/null; then
        print_msg "RED" "User $user does not exist"
        return 1
    fi
    
    local home=$(getent passwd "$user" | cut -d: -f6)
    local key_path="$home/.ssh/id_$key_type"
    
    # Create .ssh directory
    mkdir -p "$home/.ssh"
    chmod 700 "$home/.ssh"
    chown "$user:$user" "$home/.ssh"
    
    # Generate key
    print_msg "BLUE" "🔑 Обновление ключа для $user..."
    
    sudo -u "$user" ssh-keygen -t "$key_type" \
        -C "$user@$(hostname)_$(date +%Y-%m-%d)" \
        -f "$key_path" \
        -N "" \
        -q
    
    # Add to authorized_keys
    sudo -u "$user" cat "$key_path.pub" >> "$home/.ssh/authorized_keys"
    chmod 600 "$home/.ssh/authorized_keys"
    chown "$user:$user" "$home/.ssh/authorized_keys"
    
    print_msg "BLUE" "🔑 Обновление ключа для $user..."
    print_msg "BLUE" "Private key: $key_path"
    print_msg "BLUE" "Public key:"
    cat "$key_path.pub"
    
    return 0
}

# Show SSH configuration
show_config() {
    print_header "SSH Configuration"
    
    echo "SSH Service Status:"
    systemctl status ssh --no-pager | head -3
    
    echo ""
    echo "SSH Configuration (/etc/ssh/sshd_config):"
    echo "----------------------------------------"
    grep -E "^(PasswordAuthentication|PubkeyAuthentication|PermitRootLogin|AllowUsers|Port|Protocol)" /etc/ssh/sshd_config
    
    echo ""
    echo "Active SSH Connections:"
    ss -tlnp | grep :22 || echo "  No SSH listeners"
    
    echo ""
    echo "SSH Server Version:"
    ssh -V 2>&1
}

# Test SSH access for user
test_access() {
    local user=$1
    
    print_header "Testing SSH Access for $user"
    
    if ! id "$user" &>/dev/null; then
        print_msg "RED" "User $user does not exist"
        return 1
    fi
    
    # Check if user is in AllowUsers
    if grep -q "^AllowUsers" /etc/ssh/sshd_config; then
        if ! grep -q "AllowUsers.*\b$user\b" /etc/ssh/sshd_config; then
            print_msg "RED" "User $user is NOT in AllowUsers list"
            return 1
        fi
    fi
    
    # Check for SSH keys
    local home=$(getent passwd "$user" | cut -d: -f6)
    if [ ! -f "$home/.ssh/authorized_keys" ]; then
        print_msg "RED" "No authorized_keys file for $user"
        return 1
    fi
    
    # Test SSH key authentication
    print_msg "BLUE" "Testing SSH key authentication..."
    
    if sudo -u "$user" ssh -o PasswordAuthentication=no \
                           -o ConnectTimeout=5 \
                           -o BatchMode=yes \
                           localhost "echo 'SSH test successful'" 2>/dev/null; then
        print_msg "GREEN" "✓ SSH key authentication works for $user"
        return 0
    else
        print_msg "RED" "✗ SSH key authentication FAILED for $user"
        return 1
    fi
}

# Update Key (New Function)
switch_user() {
    print_header "🔄 Switching User Mode"
    
    # 1. Ask user for username
    read -p "Enter username to switch to: " USERNAME
    
    if [ -z "$USERNAME" ]; then
        print_msg "YELLOW" "No username entered. Returning to menu."
        return 0
    fi
    
    # 2. Check if user exists
    if ! id -u "$USERNAME" &> /dev/null; then
        print_msg "RED" "User '$USERNAME' does not exist!"
        print_msg "RED" "Error: User $USERNAME not found."
        return 1
    fi
    
    # 3. Output connection instruction
    print_msg "GREEN" "✅ Готово! Выполните: ssh -t $USERNAME@localhost"
    
    return 0
}
    print_header "Backup SSH Configurations"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="/etc/ssh/backup_users_$timestamp"
    
    mkdir -p "$backup_dir"
    
    # Backup main config
    cp /etc/ssh/sshd_config "$backup_dir/"
    
    # Backup config.d
    if [ -d /etc/ssh/sshd_config.d ]; then
        cp -r /etc/ssh/sshd_config.d "$backup_dir/"
    fi
    
    # Backup user authorized_keys
    for user in $(getent passwd | cut -d: -f1); do
        local home=$(getent passwd "$user" | cut -d: -f6)
        if [ -f "$home/.ssh/authorized_keys" ]; then
            mkdir -p "$backup_dir/users/$user"
            cp "$home/.ssh/authorized_keys" "$backup_dir/users/$user/"
        fi
    done
    
    # Create restore script
    cat > "$backup_dir/restore.sh" << 'EOF'
#!/bin/bash
# Restore SSH configuration from backup

set -e

echo "Restoring SSH configuration..."
cp ssd_config /etc/ssh/sshd_config

if [ -d ssd_config.d ]; then
    rm -rf /etc/ssh/sshd_config.d
    cp -r ssd_config.d /etc/ssh/
fi

echo "Restoring user keys..."
for user_dir in users/*/; do
    user=$(basename "$user_dir")
    home=$(getent passwd "$user" | cut -d: -f6 2>/dev/null)
    if [ -n "$home" ]; then
        mkdir -p "$home/.ssh"
        cp "$user_dir/authorized_keys" "$home/.ssh/"
        chmod 600 "$home/.ssh/authorized_keys"
        chown -R "$user:$user" "$home/.ssh"
        echo "Restored keys for $user"
    fi
done

systemctl restart ssh
echo "Restore complete!"
EOF
    
    chmod +x "$backup_dir/restore.sh"
    
    print_msg "GREEN" "Backup created: $backup_dir"
    print_msg "BLUE" "To restore: cd $backup_dir && sudo ./restore.sh"
}

# Interactive menu
interactive_menu() {
    while true; do
        show_menu
        read -p "Select option [1-9]: " choice
        
        case $choice in
                1)
                    list_users
                    ;;
                2)
                    read -p "Enter username to add: " username
                    if [ -n "$username" ]; then
                        add_user "$username"
                    fi
                    ;;
                3)
                    read -p "Enter username to remove: " username
                    if [ -n "$username" ]; then
                        remove_user "$username"
                    fi
                    ;;
                4)
                    read -p "Enter username: " username
                    read -p "Key type [ed25519/rsa]: " key_type
                    if [ -n "$username" ]; then
                        generate_key "$username" "${key_type:-ed25519}"
                    fi
                    ;;
                5)
                    show_config
                    ;;
                6)
                    read -p "Enter username to test: " username
                    if [ -n "$username" ]; then
                        test_access "$username"
                    fi
                    ;;
                7)
                    backup_configs
                    ;;
                8)
                    print_msg "YELLOW" "Restore from latest backup:"
                    local latest_backup=$(find /etc/ssh -name "backup_users_*" -type d | sort -r | head -1)
                    if [ -n "$latest_backup" ]; then
                        echo "Found: $latest_backup"
                        read -p "Restore from this backup? (y/N): " -n 1 confirm
                        echo ""
                        if [[ $confirm =~ ^[Yy]$ ]]; then
                            (cd "$latest_backup" && ./restore.sh)
                        fi
                    else
                        print_msg "RED" "No user backups found"
                    fi
                    ;;
                9)
                    switch_user
                    ;;
                10)
                    echo "Exiting..."
                    exit 0
                    ;;
            *)
                print_msg "RED" "Invalid option"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Command line mode
command_line_mode() {
    case "$1" in
        "list")
            list_users
            ;;
        "add")
            if [ -z "$2" ]; then
                print_msg "RED" "Usage: $0 add <username>"
                exit 1
            fi
            add_user "$2"
            ;;
        "remove")
            if [ -z "$2" ]; then
                print_msg "RED" "Usage: $0 remove <username>"
                exit 1
            fi
            remove_user "$2"
            ;;
        "generate-key")
            if [ -z "$2" ]; then
                print_msg "RED" "Usage: $0 generate-key <username> [key-type]"
                exit 1
            fi
            generate_key "$2" "$3"
            ;;
        "test")
            if [ -z "$2" ]; then
                print_msg "RED" "Usage: $0 test <username>"
                exit 1
            fi
            test_access "$2"
            ;;
        "backup")
            backup_configs
            ;;
        "config")
            show_config
            ;;
        *)
            print_msg "RED" "Unknown command: $1"
            echo "Available commands:"
            echo "  list                   - List SSH users"
            echo "  add <username>         - Add user to SSH access"
            echo "  remove <username>      - Remove user from SSH access"
            echo "  generate-key <user> [type] - Generate SSH key"
            echo "  test <username>        - Test SSH access"
            echo "  backup                 - Backup configurations"
            echo "  config                 - Show SSH configuration"
            echo "  interactive            - Interactive menu (default)"
            exit 1
            ;;
    esac
}

# Main
check_root

if [ $# -eq 0 ]; then
    interactive_menu
else
    command_line_mode "$@"
fi