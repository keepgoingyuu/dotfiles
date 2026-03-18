#!/bin/bash

# FZF Nginx、SSL 和 SSH 管理功能
# 系統管理任務的擴展功能
# FZF Nginx, SSL, and SSH Management Functions
# Extensions for system administration tasks

# ============================================
# Nginx 負載平衡管理 (Nginx Load Balancing Management)
# ============================================

# fnx-upstream - 查看和管理上游配置
# 功能：管理負載平衡的後端伺服器配置
# fnx-upstream - View and manage upstream configurations
fnx-upstream() {
    local config_file
    config_file=$(find /etc/nginx/sites-available -type f -exec grep -l "upstream" {} \; 2>/dev/null | \
        fzf --prompt="Select config with upstream: " \
            --preview 'grep -A 10 "upstream" {} | head -20' \
            --preview-window=right:60%:wrap)
    
    if [[ -n "$config_file" ]]; then
        echo "Selected: $config_file"
        echo ""
        grep -A 15 "upstream" "$config_file" | head -20
        echo ""
        
        local action
        action=$(echo -e "Edit config\nView full config\nAdd backend server\nReload nginx\nView logs" | \
            fzf --prompt="Action: " --height=40%)
        
        case "$action" in
            "Edit config")
                sudo ${EDITOR:-nvim} "$config_file"
                ;;
            "View full config")
                less "$config_file"
                ;;
            "Add backend server")
                echo "Enter backend server (e.g., localhost:8080):"
                read -r backend
                echo "Enter weight (default 1):"
                read -r weight
                weight=${weight:-1}
                echo "Add 'server $backend weight=$weight;' to upstream block"
                echo "Edit the file to add it in the correct position? (y/n)"
                read -r confirm
                if [[ "$confirm" == "y" ]]; then
                    sudo ${EDITOR:-nvim} "$config_file"
                fi
                ;;
            "Reload nginx")
                echo "Testing configuration..."
                if sudo nginx -t; then
                    sudo systemctl reload nginx
                    echo "✓ Nginx reloaded successfully"
                else
                    echo "✗ Configuration test failed"
                fi
                ;;
            "View logs")
                local log_type
                log_type=$(echo -e "access.log\nerror.log" | fzf --prompt="Log type: ")
                sudo tail -f "/var/log/nginx/$log_type"
                ;;
        esac
    fi
}

# fnx-backend - 管理上游中的後端伺服器
# 功能：新增、刪除、切換後端伺服器狀態
# fnx-backend - Manage backend servers in upstream
fnx-backend() {
    local config_file
    config_file=$(find /etc/nginx/sites-available -type f -exec grep -l "upstream" {} \; 2>/dev/null | \
        fzf --prompt="Select upstream config: " \
            --preview 'grep -A 10 "upstream" {}' \
            --preview-window=right:60%:wrap)
    
    if [[ -n "$config_file" ]]; then
        echo "Upstream servers in $config_file:"
        echo ""
        grep -A 20 "upstream" "$config_file" | grep "server " | nl
        echo ""
        
        local action
        action=$(echo -e "Toggle server (comment/uncomment)\nChange weight\nAdd new server\nRemove server\nTest connection" | \
            fzf --prompt="Action: " --height=40%)
        
        case "$action" in
            "Toggle server (comment/uncomment)")
                echo "Edit file to toggle server status:"
                sudo ${EDITOR:-nvim} "$config_file"
                ;;
            "Change weight")
                echo "Edit file to change server weights:"
                sudo ${EDITOR:-nvim} "$config_file"
                ;;
            "Add new server")
                echo "Enter new backend server (e.g., localhost:8080):"
                read -r new_server
                echo "Add to config? (y/n)"
                read -r confirm
                if [[ "$confirm" == "y" ]]; then
                    sudo ${EDITOR:-nvim} "$config_file"
                fi
                ;;
            "Remove server")
                echo "Edit file to remove server:"
                sudo ${EDITOR:-nvim} "$config_file"
                ;;
            "Test connection")
                local servers=$(grep -A 20 "upstream" "$config_file" | grep "server " | awk '{print $2}' | tr -d ';')
                for server in $servers; do
                    echo -n "Testing $server... "
                    if curl -s -o /dev/null -w "%{http_code}" "http://$server" | grep -q "200\|301\|302"; then
                        echo "✓ OK"
                    else
                        echo "✗ Failed"
                    fi
                done
                ;;
        esac
    fi
}

# fnx-reload - 安全重載 nginx（先測試配置）
# 功能：測試配置後安全重載，自動備份配置
# fnx-reload - Safe nginx reload with config test
fnx-reload() {
    echo "Testing Nginx configuration..."
    
    if sudo nginx -t; then
        echo ""
        echo "Configuration test passed. Reload nginx? (y/n)"
        read -r confirm
        if [[ "$confirm" == "y" ]]; then
            # Backup current config
            local backup_name="/tmp/nginx-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
            echo "Creating backup: $backup_name"
            sudo tar -czf "$backup_name" /etc/nginx/
            
            # Reload
            sudo systemctl reload nginx
            
            if systemctl is-active --quiet nginx; then
                echo "✓ Nginx reloaded successfully"
            else
                echo "✗ Nginx reload failed!"
                echo "Backup available at: $backup_name"
            fi
        fi
    else
        echo "✗ Configuration test failed! Please fix errors before reloading."
    fi
}

# fnx-status - 顯示上游後端伺服器狀態
# 功能：檢查所有後端伺服器的健康狀態
# fnx-status - Show upstream backend status
fnx-status() {
    echo "=== Nginx Upstream Status ==="
    echo ""
    
    # Find all upstream configurations
    local configs=$(find /etc/nginx/sites-available -type f -exec grep -l "upstream" {} \; 2>/dev/null)
    
    for config in $configs; do
        local upstream_name=$(grep "upstream" "$config" | head -1 | awk '{print $2}')
        echo "Upstream: $upstream_name (from $(basename $config))"
        
        local servers=$(grep -A 20 "upstream" "$config" | grep "server " | grep -v "^#" | awk '{print $2}' | tr -d ';')
        for server in $servers; do
            echo -n "  → $server: "
            if timeout 2 curl -s -o /dev/null "http://$server"; then
                echo "✓ UP"
            else
                echo "✗ DOWN"
            fi
        done
        echo ""
    done
}

# ============================================
# SSL 憑證管理 (SSL Certificate Management - Certbot)
# ============================================

# fcert - 主要憑證管理介面
# 功能：查看、更新、申請、刪除 SSL 憑證
# fcert - Main certificate management interface
fcert() {
    echo "=== SSL Certificate Management ==="
    echo ""
    
    # Get certificate info
    local cert_info=$(sudo certbot certificates 2>/dev/null)
    echo "$cert_info" | grep -E "Certificate Name:|Domains:|Expiry Date:"
    echo ""
    
    local action
    action=$(echo -e "View all certificates\nRenew certificates\nTest renewal (dry-run)\nRequest new certificate\nDelete certificate\nView certificate details\nSetup auto-renewal" | \
        fzf --prompt="Select action: " --height=50%)
    
    case "$action" in
        "View all certificates")
            sudo certbot certificates
            ;;
        "Renew certificates")
            echo "Checking for renewals..."
            sudo certbot renew
            ;;
        "Test renewal (dry-run)")
            echo "Testing renewal process..."
            sudo certbot renew --dry-run
            ;;
        "Request new certificate")
            echo "Enter domain name(s) separated by space:"
            read -r domains
            echo "Use Nginx plugin? (y/n)"
            read -r use_nginx
            if [[ "$use_nginx" == "y" ]]; then
                sudo certbot certonly --nginx -d ${domains// / -d }
            else
                sudo certbot certonly --standalone -d ${domains// / -d }
            fi
            ;;
        "Delete certificate")
            local cert_name
            cert_name=$(sudo certbot certificates 2>/dev/null | grep "Certificate Name:" | awk '{print $3}' | \
                fzf --prompt="Select certificate to delete: ")
            
            if [[ -n "$cert_name" ]]; then
                echo "Delete certificate $cert_name? (yes/no)"
                read -r confirm
                if [[ "$confirm" == "yes" ]]; then
                    sudo certbot delete --cert-name "$cert_name"
                fi
            fi
            ;;
        "View certificate details")
            local cert_name
            cert_name=$(sudo certbot certificates 2>/dev/null | grep "Certificate Name:" | awk '{print $3}' | \
                fzf --prompt="Select certificate: ")
            
            if [[ -n "$cert_name" ]]; then
                local cert_path="/etc/letsencrypt/live/$cert_name/cert.pem"
                if [[ -f "$cert_path" ]]; then
                    echo "Certificate details for $cert_name:"
                    sudo openssl x509 -in "$cert_path" -text -noout | less
                fi
            fi
            ;;
        "Setup auto-renewal")
            echo "Current cron jobs for certbot:"
            sudo crontab -l | grep certbot || echo "No cron job found"
            echo ""
            echo "Add auto-renewal cron job? (y/n)"
            read -r confirm
            if [[ "$confirm" == "y" ]]; then
                echo "Adding twice-daily renewal check..."
                (sudo crontab -l 2>/dev/null; echo "0 3,15 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'") | sudo crontab -
                echo "✓ Auto-renewal configured"
            fi
            ;;
    esac
}

# fcert-status - 快速檢查憑證狀態
# 功能：顯示所有憑證到期日期和警告
# fcert-status - Quick certificate status check
fcert-status() {
    echo "=== Certificate Status Overview ==="
    echo ""
    
    local cert_data=$(sudo certbot certificates 2>/dev/null)
    
    # Parse and display in a nice format
    echo "$cert_data" | while IFS= read -r line; do
        if [[ "$line" == *"Certificate Name:"* ]]; then
            echo -e "\n📜 ${line}"
        elif [[ "$line" == *"Domains:"* ]]; then
            echo "   ${line}"
        elif [[ "$line" == *"Expiry Date:"* ]]; then
            echo "   ${line}"
            
            # Check if expiring soon
            if [[ "$line" == *"VALID:"* ]]; then
                local days=$(echo "$line" | grep -oP '\d+(?= days)')
                if [[ "$days" -lt 30 ]]; then
                    echo "   ⚠️  WARNING: Expires in $days days!"
                elif [[ "$days" -lt 7 ]]; then
                    echo "   🚨 CRITICAL: Expires in $days days!"
                fi
            fi
        fi
    done
    echo ""
}

# fcert-renew - 互動式更新憑證
# 功能：選擇性更新即將到期的憑證
# fcert-renew - Interactive certificate renewal
fcert-renew() {
    local cert_name
    cert_name=$(sudo certbot certificates 2>/dev/null | grep "Certificate Name:" | awk '{print $3}' | \
        fzf --prompt="Select certificate to renew: " \
            --preview "sudo certbot certificates 2>/dev/null | grep -A 3 {}")
    
    if [[ -n "$cert_name" ]]; then
        echo "Renewing certificate: $cert_name"
        echo ""
        echo "Test first? (y/n)"
        read -r test_first
        
        if [[ "$test_first" == "y" ]]; then
            sudo certbot renew --cert-name "$cert_name" --dry-run
            echo ""
            echo "Proceed with actual renewal? (y/n)"
            read -r proceed
            if [[ "$proceed" == "y" ]]; then
                sudo certbot renew --cert-name "$cert_name"
            fi
        else
            sudo certbot renew --cert-name "$cert_name"
        fi
        
        # Reload nginx if successful
        if [[ $? -eq 0 ]]; then
            echo "Reloading Nginx..."
            sudo systemctl reload nginx
            echo "✓ Certificate renewed and Nginx reloaded"
        fi
    fi
}

# ============================================
# SSH 授權管理 (SSH Authorization Management)
# ============================================

# fssh-keys - 管理 authorized_keys
# 功能：查看、新增、刪除可連入的 SSH 公鑰
# fssh-keys - Manage authorized_keys
fssh-keys() {
    local auth_file="$HOME/.ssh/authorized_keys"
    
    if [[ ! -f "$auth_file" ]]; then
        echo "No authorized_keys file found"
        return 1
    fi
    
    echo "=== SSH Authorized Keys Management ==="
    echo "Total keys: $(wc -l < "$auth_file")"
    echo ""
    
    local action
    action=$(echo -e "View all keys\nAdd new key\nRemove key\nView key details\nBackup keys\nRestore keys\nAudit access" | \
        fzf --prompt="Select action: " --height=50%)
    
    case "$action" in
        "View all keys")
            # Show keys with line numbers and comments
            nl -ba "$auth_file" | less
            ;;
        
        "Add new key")
            echo "Paste the public key (or enter path to key file):"
            read -r key_input
            
            if [[ -f "$key_input" ]]; then
                # It's a file path
                key_content=$(cat "$key_input")
            else
                # It's the key itself
                key_content="$key_input"
            fi
            
            echo "Enter a comment for this key (e.g., user@hostname):"
            read -r comment
            
            # Add comment to key if not present
            if [[ -n "$comment" ]] && [[ "$key_content" != *"$comment"* ]]; then
                key_content="$key_content $comment"
            fi
            
            echo ""
            echo "Key to add:"
            echo "$key_content" | cut -c1-80
            echo ""
            echo "Add this key? (y/n)"
            read -r confirm
            
            if [[ "$confirm" == "y" ]]; then
                # Backup first
                cp "$auth_file" "$auth_file.backup.$(date +%Y%m%d-%H%M%S)"
                echo "$key_content" >> "$auth_file"
                chmod 600 "$auth_file"
                echo "✓ Key added successfully"
            fi
            ;;
        
        "Remove key")
            # Show keys with identifiable info
            local key_to_remove
            key_to_remove=$(nl -ba "$auth_file" | \
                fzf --prompt="Select key to remove: " \
                    --preview 'echo {} | cut -d" " -f2- | fold -w 80' \
                    --preview-window=right:60%:wrap)
            
            if [[ -n "$key_to_remove" ]]; then
                local line_num=$(echo "$key_to_remove" | awk '{print $1}')
                echo "Remove this key? (y/n)"
                echo "$key_to_remove" | cut -d" " -f2- | cut -c1-80
                read -r confirm
                
                if [[ "$confirm" == "y" ]]; then
                    # Backup first
                    cp "$auth_file" "$auth_file.backup.$(date +%Y%m%d-%H%M%S)"
                    sed -i "${line_num}d" "$auth_file"
                    echo "✓ Key removed successfully"
                fi
            fi
            ;;
        
        "View key details")
            local key_line
            key_line=$(nl -ba "$auth_file" | \
                fzf --prompt="Select key to inspect: " \
                    --preview 'echo {} | cut -d" " -f2-' \
                    --preview-window=right:60%:wrap)
            
            if [[ -n "$key_line" ]]; then
                echo "Key details:"
                echo "$key_line" | cut -d" " -f2- | fold -w 80
                echo ""
                
                # Extract key type and comment
                local key_type=$(echo "$key_line" | awk '{print $2}')
                local key_comment=$(echo "$key_line" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i}')
                
                echo "Type: $key_type"
                echo "Comment: $key_comment"
                
                # Try to get fingerprint
                local temp_file=$(mktemp)
                echo "$key_line" | cut -d" " -f2- > "$temp_file"
                echo "Fingerprint:"
                ssh-keygen -lf "$temp_file" 2>/dev/null || echo "Could not generate fingerprint"
                rm "$temp_file"
            fi
            ;;
        
        "Backup keys")
            local backup_file="$auth_file.backup.$(date +%Y%m%d-%H%M%S)"
            cp "$auth_file" "$backup_file"
            echo "✓ Keys backed up to: $backup_file"
            ;;
        
        "Restore keys")
            local backup
            backup=$(ls -1 "$auth_file".backup.* 2>/dev/null | \
                fzf --prompt="Select backup to restore: " \
                    --preview 'echo "Lines: $(wc -l < {})" && head -5 {}')
            
            if [[ -n "$backup" ]]; then
                echo "Restore from $backup? Current keys will be replaced. (y/n)"
                read -r confirm
                if [[ "$confirm" == "y" ]]; then
                    cp "$auth_file" "$auth_file.before-restore.$(date +%Y%m%d-%H%M%S)"
                    cp "$backup" "$auth_file"
                    chmod 600 "$auth_file"
                    echo "✓ Keys restored from backup"
                fi
            fi
            ;;
        
        "Audit access")
            fssh-audit
            ;;
    esac
}

# fssh-audit - 審計 SSH 存取記錄
# 功能：查看登入歷史、失敗嘗試、活動連線
# fssh-audit - Audit SSH access logs
fssh-audit() {
    echo "=== SSH Access Audit ==="
    echo ""
    
    local action
    action=$(echo -e "Recent logins\nFailed attempts\nActive sessions\nLogin history by user\nLogin history by IP" | \
        fzf --prompt="Select audit type: " --height=40%)
    
    case "$action" in
        "Recent logins")
            echo "Recent successful SSH logins:"
            sudo journalctl -u ssh --since "7 days ago" | grep "Accepted" | tail -20
            ;;
        
        "Failed attempts")
            echo "Recent failed SSH attempts:"
            sudo journalctl -u ssh --since "7 days ago" | grep -E "Failed|Invalid user" | tail -20
            ;;
        
        "Active sessions")
            echo "Currently active SSH sessions:"
            who | grep -E "pts/|tty"
            echo ""
            echo "Detailed view:"
            ss -tnp | grep :22
            ;;
        
        "Login history by user")
            echo "Enter username:"
            read -r username
            echo "Login history for $username:"
            sudo journalctl -u ssh | grep "Accepted.*$username" | tail -20
            ;;
        
        "Login history by IP")
            echo "Enter IP address:"
            read -r ip
            echo "Login history from $ip:"
            sudo journalctl -u ssh | grep "$ip" | tail -20
            ;;
    esac
}

# fssh-add - 新增 SSH 公鑰（含驗證）
# 功能：從 GitHub、檔案或直接貼上新增公鑰
# fssh-add - Add new SSH key with validation
fssh-add() {
    echo "=== Add SSH Public Key ==="
    echo ""
    echo "Methods:"
    echo "1. Paste key directly"
    echo "2. Fetch from GitHub"
    echo "3. Read from file"
    echo ""
    echo "Select method (1-3):"
    read -r method
    
    case "$method" in
        1)
            echo "Paste the public key:"
            read -r key
            ;;
        2)
            echo "Enter GitHub username:"
            read -r github_user
            key=$(curl -s "https://github.com/$github_user.keys")
            if [[ -z "$key" ]]; then
                echo "✗ Could not fetch keys from GitHub"
                return 1
            fi
            echo "Fetched keys:"
            echo "$key"
            ;;
        3)
            echo "Enter file path:"
            read -r filepath
            if [[ -f "$filepath" ]]; then
                key=$(cat "$filepath")
            else
                echo "✗ File not found"
                return 1
            fi
            ;;
        *)
            echo "Invalid option"
            return 1
            ;;
    esac
    
    # Validate key format
    if [[ "$key" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
        echo ""
        echo "Key is valid. Add comment? (e.g., user@hostname)"
        read -r comment
        
        if [[ -n "$comment" ]]; then
            key="$key $comment"
        fi
        
        # Backup and add
        cp "$HOME/.ssh/authorized_keys" "$HOME/.ssh/authorized_keys.backup.$(date +%Y%m%d-%H%M%S)"
        echo "$key" >> "$HOME/.ssh/authorized_keys"
        chmod 600 "$HOME/.ssh/authorized_keys"
        
        echo "✓ Key added successfully"
    else
        echo "✗ Invalid key format"
        return 1
    fi
}

# fssh-who - 顯示當前 SSH 連線
# 功能：查看誰正在連線、終止連線、發送訊息
# fssh-who - Show who's currently connected
fssh-who() {
    echo "=== Current SSH Sessions ==="
    echo ""
    
    # Show active sessions
    echo "Active sessions:"
    who | grep -E "pts/|tty" | while read line; do
        local user=$(echo "$line" | awk '{print $1}')
        local terminal=$(echo "$line" | awk '{print $2}')
        local login_time=$(echo "$line" | awk '{print $3, $4}')
        local from=$(echo "$line" | awk '{print $5}' | tr -d '()')
        
        echo "User: $user | Terminal: $terminal | Login: $login_time | From: $from"
    done
    
    echo ""
    echo "Network connections on SSH port:"
    sudo ss -tnp | grep :22 | grep ESTAB
    
    echo ""
    echo "Select action:"
    local action
    action=$(echo -e "Refresh\nKill session\nMessage user\nView user details" | \
        fzf --prompt="Action: " --height=40%)
    
    case "$action" in
        "Refresh")
            fssh-who
            ;;
        "Kill session")
            local session
            session=$(who | grep -E "pts/|tty" | \
                fzf --prompt="Select session to kill: ")
            
            if [[ -n "$session" ]]; then
                local terminal=$(echo "$session" | awk '{print $2}')
                echo "Kill session on $terminal? (y/n)"
                read -r confirm
                if [[ "$confirm" == "y" ]]; then
                    sudo pkill -9 -t "$terminal"
                    echo "✓ Session killed"
                fi
            fi
            ;;
        "Message user")
            local session
            session=$(who | grep -E "pts/|tty" | \
                fzf --prompt="Select user to message: ")
            
            if [[ -n "$session" ]]; then
                local terminal=$(echo "$session" | awk '{print $2}')
                echo "Enter message:"
                read -r message
                echo "$message" | sudo write $(echo "$session" | awk '{print $1}') "$terminal"
            fi
            ;;
        "View user details")
            local session
            session=$(who | grep -E "pts/|tty" | \
                fzf --prompt="Select user: ")
            
            if [[ -n "$session" ]]; then
                local user=$(echo "$session" | awk '{print $1}')
                echo "Details for $user:"
                id "$user"
                echo ""
                echo "Recent commands:"
                sudo journalctl -u ssh | grep "$user" | tail -10
            fi
            ;;
    esac
}

# ============================================
# 整合管理功能 (Integrated Management Functions)
# ============================================

# fsite - 網站綜合管理（Nginx + SSL）
# 功能：統一管理網站配置、SSL 憑證、日誌
# fsite - Integrated site management (Nginx + SSL)
fsite() {
    echo "=== Integrated Site Management ==="
    echo ""
    
    local site
    site=$(ls -1 /etc/nginx/sites-available/ | \
        fzf --prompt="Select site: " \
            --preview 'head -30 /etc/nginx/sites-available/{}' \
            --preview-window=right:60%:wrap)
    
    if [[ -n "$site" ]]; then
        echo "Site: $site"
        echo ""
        
        # Check if enabled
        if [[ -L "/etc/nginx/sites-enabled/$site" ]]; then
            echo "Status: ✓ Enabled"
        else
            echo "Status: ✗ Disabled"
        fi
        
        # Check SSL
        local domains=$(grep server_name "/etc/nginx/sites-available/$site" | head -1 | sed 's/.*server_name//' | tr -d ';')
        echo "Domains: $domains"
        
        # Check certificate
        for domain in $domains; do
            if sudo certbot certificates 2>/dev/null | grep -q "$domain"; then
                echo "SSL: ✓ Certificate exists for $domain"
            else
                echo "SSL: ✗ No certificate for $domain"
            fi
        done
        
        echo ""
        local action
        action=$(echo -e "Edit configuration\nEnable/Disable site\nManage SSL\nView logs\nTest configuration\nBackup configuration" | \
            fzf --prompt="Action: " --height=40%)
        
        case "$action" in
            "Edit configuration")
                sudo ${EDITOR:-nvim} "/etc/nginx/sites-available/$site"
                ;;
            "Enable/Disable site")
                if [[ -L "/etc/nginx/sites-enabled/$site" ]]; then
                    sudo rm "/etc/nginx/sites-enabled/$site"
                    echo "✓ Site disabled"
                else
                    sudo ln -s "/etc/nginx/sites-available/$site" "/etc/nginx/sites-enabled/$site"
                    echo "✓ Site enabled"
                fi
                sudo nginx -t && sudo systemctl reload nginx
                ;;
            "Manage SSL")
                fcert
                ;;
            "View logs")
                local log_type
                log_type=$(echo -e "access\nerror" | fzf --prompt="Log type: ")
                
                # Try to find site-specific log
                local log_file=$(grep "${log_type}_log" "/etc/nginx/sites-available/$site" | head -1 | awk '{print $2}' | tr -d ';')
                
                if [[ -n "$log_file" ]] && [[ -f "$log_file" ]]; then
                    sudo tail -f "$log_file"
                else
                    sudo tail -f "/var/log/nginx/${log_type}.log"
                fi
                ;;
            "Test configuration")
                sudo nginx -t
                ;;
            "Backup configuration")
                local backup_file="/etc/nginx/sites-available/${site}.backup-$(date +%Y%m%d-%H%M%S)"
                sudo cp "/etc/nginx/sites-available/$site" "$backup_file"
                echo "✓ Backed up to: $backup_file"
                ;;
        esac
    fi
}

# fmonitor - 系統監控儀表板
# 功能：即時監控 Nginx、SSL、SSH、系統資源
# fmonitor - System monitoring dashboard
fmonitor() {
    echo "=== System Monitor Dashboard ==="
    echo ""
    
    while true; do
        clear
        echo "=== System Monitor Dashboard ==="
        echo "Time: $(date)"
        echo ""
        
        # Nginx status
        echo "📊 Nginx Status:"
        if systemctl is-active --quiet nginx; then
            echo "   ✓ Running"
            echo "   Connections: $(ss -tn | grep :80 | wc -l) on port 80"
            echo "   Connections: $(ss -tn | grep :443 | wc -l) on port 443"
        else
            echo "   ✗ Not running"
        fi
        echo ""
        
        # SSL certificates
        echo "🔒 SSL Certificates:"
        sudo certbot certificates 2>/dev/null | grep -E "Certificate Name:|Expiry Date:" | \
            while IFS= read -r name; read -r expiry; do
                cert_name=$(echo "$name" | awk '{print $3}')
                days=$(echo "$expiry" | grep -oP '\d+(?= days)' || echo "0")
                
                if [[ "$days" -lt 7 ]]; then
                    echo "   🚨 $cert_name: $days days"
                elif [[ "$days" -lt 30 ]]; then
                    echo "   ⚠️  $cert_name: $days days"
                else
                    echo "   ✓ $cert_name: $days days"
                fi
            done
        echo ""
        
        # SSH sessions
        echo "🔑 SSH Sessions:"
        echo "   Active: $(who | grep -E "pts/|tty" | wc -l)"
        who | grep -E "pts/|tty" | head -3 | while read line; do
            echo "   → $(echo "$line" | awk '{print $1" from "$5}')"
        done
        echo ""
        
        # System resources
        echo "💻 System Resources:"
        echo "   CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
        echo "   Memory: $(free -h | awk '/^Mem:/ {print $3" / "$2}')"
        echo "   Disk: $(df -h / | awk 'NR==2 {print $3" / "$2" ("$5")"}')"
        echo ""
        
        echo "Press 'q' to quit, 'r' to refresh, or wait 5 seconds..."
        read -t 5 -n 1 key
        
        if [[ "$key" == "q" ]]; then
            break
        elif [[ "$key" == "r" ]]; then
            continue
        fi
    done
}

# 注意：說明已整合到主要的 fzf_help 功能中
# 靜默初始化 - 透過 fzf_help 查看可用功能
# Note: Help is now integrated into main fzf_help function
# Initialize silently - help available via fzf_help