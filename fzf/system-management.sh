#!/bin/bash

# FZF 系統管理功能 (FZF System Management Functions)
# 使用 fzf 實現的系統管理功能集合
# A collection of fzf-powered functions for system administration

# FZF 預設選項，提供更好的使用體驗
# FZF default options for better UX
export FZF_DEFAULT_OPTS="--height 90% --layout=reverse --border --inline-info --preview-window=right:70%:wrap --bind 'ctrl-p:toggle-preview,ctrl-u:preview-page-up,ctrl-d:preview-page-down,alt-up:preview-up,alt-down:preview-down,page-down:preview-page-down,page-up:preview-page-up' --color=hl:bright-yellow,hl+:bright-red,bg+:black,pointer:bright-blue,info:bright-green"

# ============================================
# 系統服務管理 (Systemctl Service Management)
# ============================================

# fsvc - 互動式管理系統服務
# 功能：啟動、停止、重啟、查看狀態、查看日誌
# fsvc - Manage systemctl services interactively
fsvc() {
    local service
    service=$(systemctl list-units --type=service --all --no-pager --no-legend | \
        awk '{print $1}' | \
        fzf --prompt="Select service: " \
            --preview 'echo "=== Service Status ===" && systemctl status {1} --no-pager --lines=20 2>/dev/null && echo -e "\n=== Recent Logs ===" && journalctl -u {1} --no-pager -n 30 --since "24 hours ago" 2>/dev/null' \
            --preview-window=right:70%:wrap)
    
    if [[ -n "$service" ]]; then
        echo "Selected: $service"
        echo "What would you like to do?"
        local action
        action=$(echo -e "status\nstart\nstop\nrestart\nenable\ndisable\njournalctl\ndetailed logs\nservice info" | \
            fzf --prompt="Action for $service: " --height=50%)
        
        if [[ -n "$action" ]]; then
            case "$action" in
                journalctl)
                    sudo journalctl -u "$service" -f
                    ;;
                "detailed logs")
                    echo "=== Service Details ==="
                    systemctl show "$service" --no-pager | grep -E "LoadState|ActiveState|SubState|MainPID|ExecStart|Restart"
                    echo -e "\n=== Choose log timeframe ==="
                    local timeframe
                    timeframe=$(echo -e "Last 1 hour\nLast 6 hours\nLast 24 hours\nLast 7 days\nAll logs (last 1000)\nCustom time" | \
                        fzf --prompt="Select timeframe: " --height=40%)
                    
                    case "$timeframe" in
                        "Last 1 hour")
                            sudo journalctl -u "$service" --no-pager --since "1 hour ago" | less
                            ;;
                        "Last 6 hours")
                            sudo journalctl -u "$service" --no-pager --since "6 hours ago" | less
                            ;;
                        "Last 24 hours")
                            sudo journalctl -u "$service" --no-pager --since "24 hours ago" | less
                            ;;
                        "Last 7 days")
                            sudo journalctl -u "$service" --no-pager --since "7 days ago" | less
                            ;;
                        "All logs (last 1000)")
                            sudo journalctl -u "$service" --no-pager -n 1000 | less
                            ;;
                        "Custom time")
                            echo "Enter time (e.g., '2023-09-01', 'yesterday', '2 days ago'):"
                            read -r custom_time
                            sudo journalctl -u "$service" --no-pager --since "$custom_time" | less
                            ;;
                    esac
                    ;;
                "service info")
                    echo "=== Service Configuration ==="
                    systemctl cat "$service" 2>/dev/null | less
                    ;;
                status)
                    systemctl status "$service" --no-pager --lines=30
                    ;;
                *)
                    echo "Executing: sudo systemctl $action $service"
                    sudo systemctl "$action" "$service"
                    systemctl status "$service" --no-pager | head -10
                    ;;
            esac
        fi
    fi
}

# fsvs - 查看服務詳細狀態
# 功能：顯示服務的完整狀態資訊
# fsvs - View service status with details
fsvs() {
    local service
    service=$(systemctl list-units --type=service --no-pager --no-legend | \
        awk '{print $1, $2, $3, $4}' | \
        column -t | \
        fzf --prompt="View service status: " \
            --preview 'systemctl status $(echo {} | awk "{print \$1}") 2>/dev/null' \
            --preview-window=right:70%:wrap)
    
    if [[ -n "$service" ]]; then
        local service_name=$(echo "$service" | awk '{print $1}')
        systemctl status "$service_name"
    fi
}

# fjlog - 查看服務的系統日誌
# 功能：即時追蹤特定服務的 journalctl 日誌
# fjlog - View journalctl logs for a service
fjlog() {
    local service
    service=$(systemctl list-units --type=service --all --no-pager --no-legend | \
        awk '{print $1}' | \
        fzf --prompt="Select service for logs: " \
            --preview 'echo "=== Last 24 Hours ===" && journalctl -u {1} --no-pager -n 50 --since "24 hours ago" 2>/dev/null && echo -e "\n=== All Time (Last 100) ===" && journalctl -u {1} --no-pager -n 100 2>/dev/null' \
            --preview-window=right:70%:wrap)
    
    if [[ -n "$service" ]]; then
        echo "=== Log Viewer for: $service ==="
        local action
        action=$(echo -e "Follow live logs\nHistorical logs\nError logs only" | \
            fzf --prompt="Select log type: " --height=40%)
        
        case "$action" in
            "Follow live logs")
                echo "Following live logs for $service (Ctrl+C to exit)..."
                sudo journalctl -u "$service" -f
                ;;
            "Historical logs")
                local timeframe
                timeframe=$(echo -e "Last 1 hour\nLast 6 hours\nLast 24 hours\nLast 7 days\nAll logs (last 1000)\nCustom time" | \
                    fzf --prompt="Select timeframe: " --height=40%)
                
                case "$timeframe" in
                    "Last 1 hour")
                        sudo journalctl -u "$service" --no-pager --since "1 hour ago" | less
                        ;;
                    "Last 6 hours")
                        sudo journalctl -u "$service" --no-pager --since "6 hours ago" | less
                        ;;
                    "Last 24 hours")
                        sudo journalctl -u "$service" --no-pager --since "24 hours ago" | less
                        ;;
                    "Last 7 days")
                        sudo journalctl -u "$service" --no-pager --since "7 days ago" | less
                        ;;
                    "All logs (last 1000)")
                        sudo journalctl -u "$service" --no-pager -n 1000 | less
                        ;;
                    "Custom time")
                        echo "Enter time (e.g., '2023-09-01', 'yesterday', '2 days ago'):"
                        read -r custom_time
                        sudo journalctl -u "$service" --no-pager --since "$custom_time" | less
                        ;;
                esac
                ;;
            "Error logs only")
                local timeframe
                timeframe=$(echo -e "Last 1 hour\nLast 24 hours\nLast 7 days" | \
                    fzf --prompt="Error logs timeframe: " --height=40%)
                
                case "$timeframe" in
                    "Last 1 hour")
                        sudo journalctl -u "$service" --no-pager --since "1 hour ago" -p err | less
                        ;;
                    "Last 24 hours")
                        sudo journalctl -u "$service" --no-pager --since "24 hours ago" -p err | less
                        ;;
                    "Last 7 days")
                        sudo journalctl -u "$service" --no-pager --since "7 days ago" -p err | less
                        ;;
                esac
                ;;
        esac
    fi
}

# ============================================
# 系統目標管理 (Systemctl Target Management)
# ============================================

# ftarget - 管理系統目標 (運行級別)
# 功能：切換、設定預設、查看依賴、重啟目標
# ftarget - Manage systemctl targets
ftarget() {
    local target
    target=$(systemctl list-units --type=target --all --no-pager --no-legend | \
        awk '{print $1, $2, $3, $4, $5}' | \
        column -t | \
        fzf --prompt="Select target: " \
            --header="TARGET                    LOAD   ACTIVE SUB  DESCRIPTION" \
            --preview 'systemctl status $(echo {} | awk "{print \$1}") 2>/dev/null' \
            --preview-window=right:60%:wrap)
    
    if [[ -n "$target" ]]; then
        local target_name=$(echo "$target" | awk '{print $1}')
        echo "Selected target: $target_name"
        echo "Current default target: $(systemctl get-default)"
        
        local action
        action=$(echo -e "status\nisolate (switch to)\nset as default\nshow dependencies\nlist units in target\nrestart target\nreload-or-restart services\ndaemon-reload" | \
            fzf --prompt="Action for $target_name: " --height=50%)
        
        case "$action" in
            status)
                systemctl status "$target_name"
                ;;
            "isolate (switch to)")
                echo "This will switch to $target_name immediately."
                echo "WARNING: This may stop current services!"
                read -p "Type 'yes' to confirm: " confirm
                if [[ "$confirm" == "yes" ]]; then
                    sudo systemctl isolate "$target_name"
                    echo "Switched to $target_name"
                fi
                ;;
            "set as default")
                echo "Set $target_name as default boot target?"
                read -p "Type 'yes' to confirm: " confirm
                if [[ "$confirm" == "yes" ]]; then
                    sudo systemctl set-default "$target_name"
                    echo "Default target set to: $(systemctl get-default)"
                fi
                ;;
            "show dependencies")
                systemctl list-dependencies "$target_name"
                ;;
            "list units in target")
                systemctl list-units --type=service,socket,mount,timer --state=active | grep -E "WantedBy=$target_name|RequiredBy=$target_name" || \
                systemctl list-dependencies "$target_name" --all
                ;;
            "restart target")
                echo "This will restart the target unit itself (may not restart all services)"
                read -p "Type 'yes' to confirm: " confirm
                if [[ "$confirm" == "yes" ]]; then
                    sudo systemctl restart "$target_name"
                    echo "Target $target_name restarted"
                    systemctl status "$target_name" --no-pager | head -10
                fi
                ;;
            "reload-or-restart services")
                echo "This will reload or restart all services in $target_name"
                read -p "Type 'yes' to confirm: " confirm
                if [[ "$confirm" == "yes" ]]; then
                    # Get all services in this target and reload-or-restart them
                    systemctl list-dependencies "$target_name" --plain | \
                    grep '\.service' | \
                    while read service; do
                        echo "Reloading/restarting $service..."
                        sudo systemctl reload-or-restart "$service" 2>/dev/null
                    done
                    echo "All services in $target_name reloaded or restarted"
                fi
                ;;
            "daemon-reload")
                echo "Reload systemd manager configuration"
                sudo systemctl daemon-reload
                echo "Systemd configuration reloaded"
                ;;
        esac
    fi
}

# ftarget-compare - 比較兩個系統目標的差異
# 功能：顯示兩個目標的依賴差異
# ftarget-compare - Compare two targets
ftarget-compare() {
    echo "Select first target:"
    local target1
    target1=$(systemctl list-units --type=target --all --no-pager --no-legend | \
        awk '{print $1}' | \
        fzf --prompt="First target: ")
    
    if [[ -z "$target1" ]]; then
        return
    fi
    
    echo "Select second target:"
    local target2
    target2=$(systemctl list-units --type=target --all --no-pager --no-legend | \
        awk '{print $1}' | \
        fzf --prompt="Second target: ")
    
    if [[ -z "$target2" ]]; then
        return
    fi
    
    echo "Comparing $target1 vs $target2"
    echo ""
    echo "=== Dependencies in $target1 ==="
    systemctl list-dependencies "$target1" --all | head -20
    echo ""
    echo "=== Dependencies in $target2 ==="
    systemctl list-dependencies "$target2" --all | head -20
    echo ""
    echo "Use 'systemctl list-dependencies <target>' for full listing"
}

# frunlevel - 快速切換常用運行級別
# 功能：救援模式、多用戶、圖形介面等
# frunlevel - Quick switch between common targets (runlevels)
frunlevel() {
    local runlevels="rescue.target:Rescue Mode (Single User)
multi-user.target:Multi-User System (No GUI)
graphical.target:Graphical Interface
emergency.target:Emergency Mode
halt.target:Halt System
reboot.target:Reboot System
poweroff.target:Power Off System"
    
    local selected
    selected=$(echo "$runlevels" | \
        fzf --prompt="Select target/runlevel: " \
            --delimiter=":" \
            --with-nth=2 \
            --preview 'systemctl status $(echo {} | cut -d: -f1) 2>/dev/null' \
            --preview-window=right:60%:wrap)
    
    if [[ -n "$selected" ]]; then
        local target=$(echo "$selected" | cut -d: -f1)
        local description=$(echo "$selected" | cut -d: -f2)
        
        echo "Selected: $description ($target)"
        echo "Current target: $(systemctl get-default)"
        
        local action
        action=$(echo -e "Switch now (isolate)\nSet as default boot target\nBoth\nCancel" | \
            fzf --prompt="Action: " --height=40%)
        
        case "$action" in
            "Switch now (isolate)")
                echo "WARNING: Switching to $target will affect running services!"
                read -p "Type 'yes' to confirm: " confirm
                if [[ "$confirm" == "yes" ]]; then
                    sudo systemctl isolate "$target"
                    echo "Switched to $target"
                fi
                ;;
            "Set as default boot target")
                sudo systemctl set-default "$target"
                echo "Default boot target set to: $target"
                ;;
            Both)
                echo "WARNING: This will switch immediately AND set as default!"
                read -p "Type 'yes' to confirm: " confirm
                if [[ "$confirm" == "yes" ]]; then
                    sudo systemctl set-default "$target"
                    sudo systemctl isolate "$target"
                    echo "Switched to and set default: $target"
                fi
                ;;
        esac
    fi
}

# ============================================
# Nginx 網站管理 (Nginx Management)
# ============================================

# fnx - 管理 Nginx 站點
# 功能：啟用、停用、編輯、查看站點配置
# fnx - Manage nginx sites
fnx() {
    local site
    local available_sites="/etc/nginx/sites-available"
    local enabled_sites="/etc/nginx/sites-enabled"
    
    if [[ ! -d "$available_sites" ]]; then
        echo "Nginx sites directory not found. Is nginx installed?"
        return 1
    fi
    
    site=$(ls -1 "$available_sites" | \
        fzf --prompt="Select nginx site: " \
            --preview "cat $available_sites/{} 2>/dev/null | head -50")
    
    if [[ -n "$site" ]]; then
        echo "Selected site: $site"
        local action
        action=$(echo -e "view\nedit\nenable\ndisable\ntest config\nreload nginx" | \
            fzf --prompt="Action for $site: " --height=40%)
        
        case "$action" in
            view)
                less "$available_sites/$site"
                ;;
            edit)
                sudo ${EDITOR:-nvim} "$available_sites/$site"
                ;;
            enable)
                if [[ ! -L "$enabled_sites/$site" ]]; then
                    sudo ln -s "$available_sites/$site" "$enabled_sites/$site"
                    echo "Site $site enabled"
                    sudo nginx -t && sudo systemctl reload nginx
                else
                    echo "Site $site is already enabled"
                fi
                ;;
            disable)
                if [[ -L "$enabled_sites/$site" ]]; then
                    sudo rm "$enabled_sites/$site"
                    echo "Site $site disabled"
                    sudo nginx -t && sudo systemctl reload nginx
                else
                    echo "Site $site is not enabled"
                fi
                ;;
            "test config")
                sudo nginx -t
                ;;
            "reload nginx")
                sudo nginx -t && sudo systemctl reload nginx
                ;;
        esac
    fi
}

# fnxl - 查看 Nginx 日誌
# 功能：存取日誌、錯誤日誌即時查看
# fnxl - View nginx logs
fnxl() {
    local log_type
    log_type=$(echo -e "access.log\nerror.log\naccess.log.1\nerror.log.1" | \
        fzf --prompt="Select log type: " --height=40%)
    
    if [[ -n "$log_type" ]]; then
        local log_file="/var/log/nginx/$log_type"
        if [[ -f "$log_file" ]]; then
            echo "Viewing: $log_file"
            echo "Press Ctrl+C to exit"
            sudo tail -f "$log_file"
        else
            echo "Log file not found: $log_file"
        fi
    fi
}

# fnxe - 編輯 Nginx 配置檔
# 功能：選擇並編輯任何 nginx 配置檔
# fnxe - Edit nginx configuration files
fnxe() {
    local config_file
    config_file=$(find /etc/nginx -type f -name "*.conf" 2>/dev/null | \
        fzf --prompt="Select nginx config: " \
            --preview 'cat {} 2>/dev/null | head -50')
    
    if [[ -n "$config_file" ]]; then
        sudo ${EDITOR:-nvim} "$config_file"
        echo "Test nginx configuration?"
        read -p "Press Enter to test, Ctrl+C to skip: "
        sudo nginx -t
    fi
}

# ============================================
# Docker 容器管理 (Docker Container Management)
# ============================================

# fdc - Docker 容器管理
# 功能：查看日誌、進入容器、啟動停止、檢查狀態
# fdc - Docker container management
fdc() {
    local container
    container=$(docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}" | \
        tail -n +2 | \
        fzf --prompt="Select container: " \
            --preview 'docker logs --tail 50 $(echo {} | awk "{print \$1}") 2>/dev/null' \
            --preview-window=right:60%:wrap)
    
    if [[ -n "$container" ]]; then
        local container_id=$(echo "$container" | awk '{print $1}')
        local container_name=$(echo "$container" | awk '{print $2}')
        echo "Selected: $container_name ($container_id)"
        
        local action
        action=$(echo -e "logs\nexec bash\nexec sh\nstart\nstop\nrestart\ninspect\nstats\nremove" | \
            fzf --prompt="Action for $container_name: " --height=40%)
        
        case "$action" in
            logs)
                local log_action
                log_action=$(echo -e "Follow live logs\nRecent logs\nAll logs" | \
                    fzf --prompt="Select log type: " --height=40%)
                
                case "$log_action" in
                    "Follow live logs")
                        docker logs -f "$container_id"
                        ;;
                    "Recent logs")
                        local lines
                        lines=$(echo -e "50 lines\n100 lines\n500 lines\n1000 lines" | \
                            fzf --prompt="How many lines: " --height=40%)
                        lines=$(echo "$lines" | awk '{print $1}')
                        docker logs --tail "$lines" "$container_id" | less
                        ;;
                    "All logs")
                        docker logs "$container_id" | less
                        ;;
                esac
                ;;
            "exec bash")
                docker exec -it "$container_id" bash
                ;;
            "exec sh")
                docker exec -it "$container_id" sh
                ;;
            start|stop|restart)
                docker "$action" "$container_id"
                docker ps -a | grep "$container_id"
                ;;
            inspect)
                docker inspect "$container_id" | less
                ;;
            stats)
                docker stats "$container_id"
                ;;
            remove)
                echo "Are you sure you want to remove $container_name?"
                read -p "Type 'yes' to confirm: " confirm
                if [[ "$confirm" == "yes" ]]; then
                    docker rm "$container_id"
                fi
                ;;
        esac
    fi
}

# fdl - Docker 日誌查看器
# 功能：即時追蹤容器日誌
# fdl - Docker logs viewer
fdl() {
    local container
    container=$(docker ps --format "table {{.Names}}\t{{.Status}}" | \
        tail -n +2 | \
        fzf --prompt="Select container for logs: " \
            --preview 'docker logs --tail 30 $(echo {} | awk "{print \$1}") 2>&1')
    
    if [[ -n "$container" ]]; then
        local container_name=$(echo "$container" | awk '{print $1}')
        echo "=== Docker Logs for: $container_name ==="
        
        local log_action
        log_action=$(echo -e "Follow live logs\nTail recent logs\nAll logs with timestamps\nError logs only" | \
            fzf --prompt="Select log action: " --height=40%)
        
        case "$log_action" in
            "Follow live logs")
                echo "Following live logs (Ctrl+C to exit)..."
                docker logs -f "$container_name"
                ;;
            "Tail recent logs")
                local lines
                lines=$(echo -e "50\n100\n500\n1000" | \
                    fzf --prompt="Number of lines: " --height=40%)
                docker logs --tail "$lines" -t "$container_name" | less
                ;;
            "All logs with timestamps")
                docker logs -t "$container_name" | less
                ;;
            "Error logs only")
                echo "Filtering stderr logs..."
                docker logs "$container_name" 2>&1 | grep -i error | less
                ;;
        esac
    fi
}

# fdi - Docker 映像管理
# 功能：檢查、執行、刪除、標記映像
# fdi - Docker image management
fdi() {
    local image
    image=$(docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedSince}}" | \
        tail -n +2 | \
        fzf --prompt="Select image: " \
            --preview 'docker image inspect $(echo {} | awk "{print \$2}") 2>/dev/null | head -50')
    
    if [[ -n "$image" ]]; then
        local image_id=$(echo "$image" | awk '{print $2}')
        local image_name=$(echo "$image" | awk '{print $1}')
        echo "Selected: $image_name"
        
        local action
        action=$(echo -e "inspect\nhistory\nrun\nremove\ntag" | \
            fzf --prompt="Action for $image_name: " --height=40%)
        
        case "$action" in
            inspect)
                docker image inspect "$image_id" | less
                ;;
            history)
                docker history "$image_id"
                ;;
            run)
                echo "Enter run command options (or press Enter for defaults):"
                read -p "Options: " options
                docker run $options "$image_id"
                ;;
            remove)
                echo "Remove image $image_name?"
                read -p "Type 'yes' to confirm: " confirm
                if [[ "$confirm" == "yes" ]]; then
                    docker rmi "$image_id"
                fi
                ;;
            tag)
                read -p "Enter new tag: " new_tag
                docker tag "$image_id" "$new_tag"
                ;;
        esac
    fi
}

# ============================================
# 進程管理 (Process Management)
# ============================================

# fkill - 互動式終止進程
# 功能：選擇進程並發送終止信號
# fkill - Kill processes interactively
fkill() {
    local pid
    pid=$(ps aux | \
        sed 1d | \
        fzf -m --prompt="Select process to kill: " \
            --preview 'echo {}' \
            --preview-window=up:3:wrap | \
        awk '{print $2}')
    
    if [[ -n "$pid" ]]; then
        echo "Selected PID(s): $pid"
        echo "Select signal:"
        local signal
        signal=$(echo -e "TERM (15) - Graceful termination\nKILL (9) - Force kill\nHUP (1) - Reload\nINT (2) - Interrupt" | \
            fzf --prompt="Signal: " --height=40% | \
            awk '{print $2}' | tr -d '()')
        
        if [[ -n "$signal" ]]; then
            echo "$pid" | xargs -r kill -${signal:-15}
            echo "Sent signal $signal to process(es)"
        fi
    fi
}

# fport - 檢查並管理端口使用
# 功能：查看端口佔用，快速釋放端口
# fport - Check and manage port usage (simplified version)
fport() {
    # Combine netstat and lsof for better coverage
    local port_line
    port_line=$(
        {
            # Get IPv4 and IPv6 ports from netstat
            sudo netstat -tlnp 2>/dev/null | grep LISTEN | awk '
                /^tcp/ {
                    # Extract port from the 4th field
                    split($4, addr, ":")
                    port = addr[length(addr)]
                    # Extract PID and process name
                    split($7, proc, "/")
                    if (port && proc[1] && proc[2]) {
                        printf "%-10s PID:%-8s %s\n", port, proc[1], proc[2]
                    }
                }
            '
        } | sort -n -u | \
        fzf --prompt="Select port to free up: " \
            --header="PORT       PID        PROCESS" \
            --preview 'port=$(echo {} | awk "{print \$1}"); echo "=== Port $port details ===" && sudo netstat -tlnp 2>/dev/null | grep ":$port "' \
            --preview-window=right:60%:wrap
    )
    
    if [[ -n "$port_line" ]]; then
        local port=$(echo "$port_line" | awk '{print $1}')
        local pid=$(echo "$port_line" | awk -F'PID:' '{print $2}' | awk '{print $1}')
        local process=$(echo "$port_line" | awk '{print $3}')
        
        echo "Port $port is used by: $process (PID: $pid)"
        echo ""
        
        # Quick action selection
        local action
        action=$(echo -e "Free this port (kill process)\nForce kill\nCancel" | \
            fzf --prompt="Free port $port? " --height=30%)
        
        case "$action" in
            "Free this port (kill process)")
                if [[ -n "$pid" ]]; then
                    echo "Killing $process (PID: $pid) to free port $port..."
                    if sudo kill "$pid" 2>/dev/null; then
                        echo "✓ Process killed"
                        sleep 1
                        if ! sudo netstat -tlnp 2>/dev/null | grep -q ":$port "; then
                            echo "✓ Port $port is now free!"
                        else
                            echo "⚠ Trying force kill..."
                            sudo kill -9 "$pid" 2>/dev/null
                            echo "✓ Port $port should be free now"
                        fi
                    else
                        echo "✗ Failed - trying force kill..."
                        sudo kill -9 "$pid" 2>/dev/null
                        echo "✓ Force killed"
                    fi
                fi
                ;;
            "Force kill")
                if [[ -n "$pid" ]]; then
                    echo "Force killing $process (PID: $pid)..."
                    sudo kill -9 "$pid" 2>/dev/null
                    echo "✓ Process force killed - port $port is now free"
                fi
                ;;
            "Cancel")
                echo "Cancelled - port $port remains in use"
                ;;
        esac
    fi
}

# ftop - 互動式進程查看器
# 功能：查看進程詳細資訊、記憶體映射、開啟檔案
# ftop - Interactive process viewer
ftop() {
    local process
    process=$(ps aux --sort=-%cpu | \
        head -30 | \
        fzf --prompt="Select process for details: " \
            --header="USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND" \
            --preview 'echo {} | awk "{print \$2}" | xargs -I {} ps -p {} -o pid,ppid,user,%cpu,%mem,etime,cmd' \
            --preview-window=up:40%:wrap)
    
    if [[ -n "$process" ]]; then
        local pid=$(echo "$process" | awk '{print $2}')
        echo "Process details for PID $pid:"
        ps -p "$pid" -f
        echo -e "\nMemory maps:"
        sudo pmap "$pid" 2>/dev/null | head -20
        
        echo -e "\nOpen files:"
        sudo lsof -p "$pid" 2>/dev/null | head -20
    fi
}

# ============================================
# 日誌查看功能 (Log Viewing Functions)
# ============================================

# flog - 統一日誌查看器
# 功能：查看系統、應用程式各種日誌
# flog - Unified log viewer
flog() {
    local log_source
    log_source=$(echo -e "journalctl\nsyslog\nauth.log\nkern.log\nnginx\napache2\nmysql\ncustom" | \
        fzf --prompt="Select log source: " --height=40%)
    
    case "$log_source" in
        journalctl)
            local unit
            unit=$(systemctl list-units --all --no-pager --no-legend | \
                awk '{print $1}' | \
                fzf --prompt="Select unit (or press Esc for all): ")
            
            if [[ -n "$unit" ]]; then
                sudo journalctl -u "$unit" -f
            else
                sudo journalctl -f
            fi
            ;;
        syslog|auth.log|kern.log)
            sudo tail -f "/var/log/$log_source"
            ;;
        nginx)
            fnxl
            ;;
        mysql)
            local mysql_log="/var/log/mysql/error.log"
            if [[ -f "$mysql_log" ]]; then
                sudo tail -f "$mysql_log"
            else
                echo "MySQL log not found at $mysql_log"
            fi
            ;;
        custom)
            local custom_log
            custom_log=$(find /var/log -type f -name "*.log" 2>/dev/null | \
                fzf --prompt="Select log file: " \
                    --preview 'sudo tail -20 {} 2>/dev/null')
            
            if [[ -n "$custom_log" ]]; then
                sudo tail -f "$custom_log"
            fi
            ;;
    esac
}

# ferr - 快速錯誤日誌查找器
# 功能：按時間範圍搜尋系統錯誤
# ferr - Quick error log finder
ferr() {
    echo "Searching for errors in system logs..."
    local timeframe
    timeframe=$(echo -e "1 hour\n6 hours\n24 hours\n7 days\nAll" | \
        fzf --prompt="Select timeframe: " --height=40%)
    
    local since_flag=""
    case "$timeframe" in
        "1 hour")
            since_flag="--since '1 hour ago'"
            ;;
        "6 hours")
            since_flag="--since '6 hours ago'"
            ;;
        "24 hours")
            since_flag="--since '24 hours ago'"
            ;;
        "7 days")
            since_flag="--since '7 days ago'"
            ;;
    esac
    
    eval "sudo journalctl $since_flag | grep -iE 'error|fail|critical|alert|emerg'" | \
        fzf --prompt="Select error to view context: " \
            --preview "echo {} | awk '{print \$3}' | xargs -I {} sudo journalctl --no-pager -u {} -n 20" \
            --preview-window=right:60%:wrap
}

# ============================================
# 安全掃描功能 (Security Scanning Functions)
# ============================================

# fleak - 掃描當前目錄的敏感資訊
# 功能：使用 gitleaks 掃描當前目錄中的密鑰洩漏
fleak() {
    echo "🔍 Scanning current directory for secrets..."

    # 檢查 gitleaks 是否存在
    local gitleaks_path=""
    if command -v gitleaks &> /dev/null; then
        gitleaks_path="gitleaks"
    elif [ -f "$HOME/dotfiles/gitleaks" ]; then
        gitleaks_path="$HOME/dotfiles/gitleaks"
    elif [ -f "/usr/local/bin/gitleaks" ]; then
        gitleaks_path="/usr/local/bin/gitleaks"
    else
        echo "❌ Gitleaks not found. Installing..."
        wget -q https://github.com/gitleaks/gitleaks/releases/download/v8.21.2/gitleaks_8.21.2_linux_x64.tar.gz
        tar -xzf gitleaks_8.21.2_linux_x64.tar.gz
        rm gitleaks_8.21.2_linux_x64.tar.gz
        gitleaks_path="./gitleaks"
    fi

    # 執行掃描
    $gitleaks_path detect --source . --no-git

    if [ $? -eq 0 ]; then
        echo "✅ No secrets found! Your code is clean."
    else
        echo "⚠️  Secrets detected! Review and remove them immediately."
        echo "💡 Tip: Add sensitive files to .gitignore"
    fi
}

# fleak-all - 掃描整個 Git 歷史
# 功能：深度掃描包含所有 commits 的敏感資訊
fleak-all() {
    echo "🔎 Deep scanning entire Git history..."

    # 檢查是否在 git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "❌ Not in a git repository"
        return 1
    fi

    # 檢查 gitleaks
    local gitleaks_path=""
    if command -v gitleaks &> /dev/null; then
        gitleaks_path="gitleaks"
    elif [ -f "$HOME/dotfiles/gitleaks" ]; then
        gitleaks_path="$HOME/dotfiles/gitleaks"
    else
        gitleaks_path="/usr/local/bin/gitleaks"
    fi

    # 執行完整掃描
    $gitleaks_path detect --source . --verbose

    if [ $? -ne 0 ]; then
        echo ""
        echo "⚠️  Found secrets in git history!"
        echo "To clean history, use:"
        echo "  git filter-branch --force --index-filter \\"
        echo "  'git rm --cached --ignore-unmatch <file>' \\"
        echo "  --prune-empty --tag-name-filter cat -- --all"
    fi
}

# fleak-pre - 設置 pre-commit 保護
# 功能：安裝 gitleaks 作為 pre-commit hook
fleak-pre() {
    echo "🛡️  Setting up pre-commit protection..."

    # 檢查是否在 git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "❌ Not in a git repository"
        return 1
    fi

    # 檢查 gitleaks 路徑
    local gitleaks_path=""
    if command -v gitleaks &> /dev/null; then
        gitleaks_path="gitleaks"
    elif [ -f "$HOME/dotfiles/gitleaks" ]; then
        gitleaks_path="$HOME/dotfiles/gitleaks"
    else
        gitleaks_path="/usr/local/bin/gitleaks"
    fi

    # 建立 pre-commit hook
    local hook_file=".git/hooks/pre-commit"

    cat > "$hook_file" << EOF
#!/bin/bash
# Gitleaks pre-commit hook
echo "🔍 Scanning for secrets before commit..."
$gitleaks_path protect --staged --verbose
if [ \$? -ne 0 ]; then
    echo "❌ Commit blocked: secrets detected!"
    echo "Remove secrets and try again."
    exit 1
fi
echo "✅ No secrets detected, proceeding with commit."
EOF

    chmod +x "$hook_file"
    echo "✅ Pre-commit hook installed!"
    echo "📝 Gitleaks will now scan before every commit."
}

# fleak-report - 生成安全報告
# 功能：生成詳細的 JSON/SARIF 格式報告
fleak-report() {
    echo "📊 Generating security report..."

    # 選擇報告格式
    local format=$(echo -e "json\nsarif\ncsv" | \
        fzf --prompt="Select report format: " --height=30%)

    if [ -z "$format" ]; then
        echo "Cancelled"
        return
    fi

    # 檢查 gitleaks
    local gitleaks_path=""
    if command -v gitleaks &> /dev/null; then
        gitleaks_path="gitleaks"
    elif [ -f "$HOME/dotfiles/gitleaks" ]; then
        gitleaks_path="$HOME/dotfiles/gitleaks"
    else
        gitleaks_path="/usr/local/bin/gitleaks"
    fi

    # 生成報告
    local report_file="gitleaks-report-$(date +%Y%m%d-%H%M%S).$format"

    echo "Generating $format report..."
    $gitleaks_path detect --source . --report-format "$format" --report-path "$report_file"

    if [ -f "$report_file" ]; then
        echo "✅ Report saved to: $report_file"
        echo ""

        # 顯示摘要
        if [ "$format" = "json" ]; then
            local count=$(jq '. | length' "$report_file" 2>/dev/null || echo "0")
            echo "📈 Summary: Found $count potential secrets"

            if [ "$count" -gt 0 ]; then
                echo "Top findings:"
                jq -r '.[:3] | .[] | "  - \(.RuleID): \(.File):\(.Line)"' "$report_file" 2>/dev/null
            fi
        fi
    else
        echo "❌ Failed to generate report"
    fi
}

# ============================================
# 輔助功能 (Helper Functions)
# ============================================

# check_permissions - 檢查執行權限
# 功能：確認是否有足夠權限執行管理功能
# Check if running with required permissions
check_permissions() {
    if [[ $EUID -ne 0 ]] && ! groups | grep -qE "docker|sudo"; then
        echo "Warning: Some functions may require sudo permissions"
    fi
}

# f1 - 互動式 FOne 賽車維修站選單
# 功能：使用 FZF 選擇並執行 FOne 管理功能
# Interactive FOne Racing Pit Stop Menu
f1() {
    # 定義所有可用命令及其說明
    local commands="
🏎️ 系統服務管理:HEADER:系統服務管理
fsvc:🔧:管理服務 (啟動/停止/重啟/狀態)
fsvs:📊:查看服務詳細狀態
fjlog:📝:查看服務日誌 (journalctl)
ftarget:🎯:管理系統目標 (systemctl targets)
ftarget-compare:⚖️:比較兩個 targets 的差異
frunlevel:🚦:快速切換運行級別 (救援/多用戶/圖形介面)
---:---:---
🏎️ Nginx 網站管理:HEADER:Nginx 網站管理
fnx:🌐:管理 nginx 站點 (啟用/停用/編輯)
fnxl:📋:查看 nginx 日誌
fnxe:⚙️:編輯 nginx 配置檔
fnx-upstream:🔄:管理上游配置 (負載平衡)
fnx-backend:🖥️:管理後端伺服器
fnx-reload:♻️:安全重載 nginx (先測試配置)
fnx-status:💚:顯示後端伺服器健康狀態
---:---:---
🏎️ 容器管理:HEADER:容器管理
fdc:🐳:Docker 容器管理
fdl:📜:查看容器日誌
fdi:💿:管理 Docker 映像
---:---:---
🏎️ 進程管理:HEADER:進程管理
fkill:🔨:互動式終止進程
fport:🔌:檢查並釋放端口佔用
ftop:📈:互動式進程查看器
---:---:---
🏎️ SSL 憑證管理:HEADER:SSL 憑證管理
fcert:🔐:憑證管理主介面 (Certbot)
fcert-status:📅:快速查看憑證狀態 (到期日期)
fcert-renew:🔄:互動式更新憑證
---:---:---
🏎️ SSH 授權管理:HEADER:SSH 授權管理
fssh-keys:🔑:管理 authorized_keys (誰可以連入)
fssh-audit:🔍:審計 SSH 存取記錄
fssh-add:➕:新增 SSH 公鑰 (支援 GitHub)
fssh-who:👥:查看當前 SSH 連線
---:---:---
🏎️ 開發工具:HEADER:開發工具
fsync-dot:🔄:自動同步 dotfiles 到 GitHub
---:---:---
🏎️ 安全掃描:HEADER:安全掃描工具
fleak:🔍:掃描當前目錄的敏感資訊
fleak-all:🔎:掃描整個 Git 歷史
fleak-pre:🛡️:設置 pre-commit 保護
fleak-report:📊:生成安全報告
---:---:---
🏎️ 整合功能:HEADER:整合功能
fsite:🏗️:網站綜合管理 (Nginx + SSL)
fmonitor:📊:系統監控儀表板
---:---:---
🏎️ 日誌查看:HEADER:日誌查看
flog:📚:統一日誌查看器
ferr:⚠️:快速查找錯誤日誌"
    
    # 使用 FZF 選擇功能 - 加強賽車風格顯示
    local selected
    selected=$(echo "$commands" | tr ' ' '\n' | \
        awk -F: '
            $2 == "HEADER" { 
                # 分類標題用賽車風格顯示
                printf "\n%s %s %s\n", "━━━━━━━━", $3, "━━━━━━━━"
                next
            }
            $1 == "---" { 
                print ""
                next
            }
            $1 != "" && $2 != "" && $3 != "" { 
                # 格式化輸出：命令名稱 + 圖示 + 說明
                printf "  %-16s %s %s\n", $1, $2, $3
            }
        ' | \
        fzf --prompt="🏎️  SELECT YOUR TOOL » " \
            --header=$'╔═══════════════════════════════════════════╗\n║   🏁 F1 RACING PIT STOP - QUICK SERVICE 🏁  ║\n║        按 / 搜尋 · Enter 執行 · ESC 離開       ║\n╚═══════════════════════════════════════════╝' \
            --preview-window=right:55%:wrap:border-left \
            --preview 'source ~/.config/fzf/system-management.sh 2>/dev/null; 
                      source ~/.config/fzf/nginx-ssl-ssh-management.sh 2>/dev/null;
                      cmd=$(echo {} | awk "{print \$1}"); 
                      if [[ -z "$cmd" ]] || [[ "$cmd" =~ ^━ ]]; then
                          echo ""
                          echo "    🏎️  F1 RACING TOOLS 🏎️"
                          echo ""
                          echo "  快速選擇您需要的工具"
                          echo "  輸入關鍵字即時搜尋"
                          echo ""
                          echo "  ⚡ QUICK TIPS:"
                          echo "  • 使用方向鍵瀏覽"
                          echo "  • 輸入文字過濾選項"  
                          echo "  • Ctrl+/ 切換預覽"
                          echo "  • Ctrl+H 顯示說明"
                      elif type "$cmd" &>/dev/null; then
                          echo ""
                          echo "  🏎️  TOOL: $cmd"
                          echo "  ━━━━━━━━━━━━━━━━━━━━━━"
                          echo "  功能說明："
                          case "$cmd" in
                              fsvc) echo "  管理系統服務 - 啟動/停止/重啟/查看狀態";;
                              fsvs) echo "  查看服務詳細狀態資訊";;
                              fjlog) echo "  查看服務的 journalctl 日誌";;
                              ftarget) echo "  管理 systemctl targets (系統目標)";;
                              ftarget-compare) echo "  比較兩個系統目標的差異";;
                              frunlevel) echo "  快速切換運行級別 (救援/多用戶/圖形)";;
                              fnx) echo "  管理 nginx 站點 - 啟用/停用/編輯";;
                              fnxl) echo "  查看 nginx access/error 日誌";;
                              fnxe) echo "  編輯 nginx 配置檔案";;
                              fnx-upstream) echo "  管理 nginx 上游配置 (負載平衡)";;
                              fnx-backend) echo "  管理後端伺服器設定";;
                              fnx-reload) echo "  安全重載 nginx (先測試配置)";;
                              fnx-status) echo "  顯示後端伺服器健康狀態";;
                              fdc) echo "  Docker 容器管理 - 查看/啟動/停止";;
                              fdl) echo "  查看 Docker 容器日誌";;
                              fdi) echo "  管理 Docker 映像";;
                              fkill) echo "  互動式選擇並終止進程";;
                              fport) echo "  檢查端口佔用並釋放端口";;
                              ftop) echo "  互動式進程查看器";;
                              fcert) echo "  SSL 憑證管理主介面 (Certbot)";;
                              fcert-status) echo "  快速查看憑證狀態和到期日期";;
                              fcert-renew) echo "  互動式更新 SSL 憑證";;
                              fssh-keys) echo "  管理 authorized_keys 檔案";;
                              fssh-audit) echo "  審計 SSH 存取記錄";;
                              fssh-add) echo "  新增 SSH 公鑰 (支援 GitHub)";;
                              fssh-who) echo "  查看當前 SSH 連線狀態";;
                              fsync-dot) echo "  同步 dotfiles 到 GitHub";;
                              fsite) echo "  網站綜合管理 (Nginx + SSL)";;
                              fmonitor) echo "  系統監控儀表板";;
                              flog) echo "  統一日誌查看器";;
                              ferr) echo "  快速查找系統錯誤日誌";;
                              fleak) echo "  掃描當前目錄的敏感資訊（API keys等）";;
                              fleak-all) echo "  深度掃描整個 Git 歷史的敏感資訊";;
                              fleak-pre) echo "  設置 pre-commit hook 自動保護";;
                              fleak-report) echo "  生成詳細的安全掃描報告";;
                              *) echo "  檢查功能說明...";;
                          esac
                          echo "  ━━━━━━━━━━━━━━━━━━━━━━"
                          echo "  🏁 Press ENTER to START"
                          echo "  🚫 Press ESC to CANCEL"
                      else
                          echo ""
                          echo "  ⚠️  TOOL NOT IMPLEMENTED: $cmd"
                          echo "  This feature is under development"
                          echo "  此功能開發中"
                      fi' \
            --bind 'ctrl-/:toggle-preview' \
            --bind 'ctrl-h:preview(echo -e "🏎️  PIT STOP CONTROLS 🏎️\n━━━━━━━━━━━━━━━━━━━━━━\n\n⌨️  KEYBOARD SHORTCUTS:\n\n↑↓         Navigate menu\nEnter      Execute tool\nESC        Exit pit stop\n/text      Search tools\n\nCtrl+/     Toggle preview\nCtrl+U     Preview page up\nCtrl+D     Preview page down\nCtrl+H     Show this help\n\n━━━━━━━━━━━━━━━━━━━━━━\n🏁 RACE ON! 🏁")' \
            --color='fg:#f8f8f2,bg:#282a36,hl:#ff79c6,fg+:#f8f8f2,bg+:#44475a,hl+:#ff79c6,info:#8be9fd,prompt:#ff79c6,pointer:#ff79c6,marker:#50fa7b,spinner:#ffb86c,header:#6272a4')
    
    # 執行選中的命令
    if [[ -n "$selected" ]]; then
        local cmd=$(echo "$selected" | awk '{print $1}')
        
        # 檢查是否為空行或分類標題
        if [[ -z "$cmd" ]] || [[ "$cmd" =~ ^━ ]]; then
            f1  # 重新顯示選單
            return
        fi
        
        # 檢查命令是否存在並執行
        if type "$cmd" &>/dev/null; then
            echo ""
            echo "🏎️  STARTING: $cmd"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            $cmd
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🏁 Task completed. Press Enter to return to pit stop..."
            read -r
            f1  # 返回選單
        else
            echo ""
            echo "⚠️  TOOL NOT AVAILABLE: $cmd"
            echo "This feature is under development."
            sleep 2
            f1
        fi
    fi
}

# ============================================
# 開發工具 (Development Tools)
# ============================================

# fsync-dot - 同步 dotfiles 到 GitHub
# 功能：自動提交並推送 dotfiles 變更到 GitHub
# fsync-dot - Sync dotfiles to GitHub
fsync-dot() {
    local dotfiles_dir="/home/ubuntu/dotfiles"
    
    if [[ ! -d "$dotfiles_dir" ]]; then
        echo "⚠️  Dotfiles directory not found: $dotfiles_dir"
        return 1
    fi
    
    cd "$dotfiles_dir" || {
        echo "⚠️  Cannot enter dotfiles directory"
        return 1
    }
    
    echo "🏎️  Dotfiles Sync to GitHub"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # 檢查 git status
    echo "📊 Checking git status..."
    if ! git status --porcelain | grep -q .; then
        echo "✅ No changes to sync - dotfiles are up to date!"
        return 0
    fi
    
    # 顯示變更
    echo "📋 Changes detected:"
    git status --short
    echo ""
    
    # 詢問是否繼續
    local action
    action=$(echo -e "Sync all changes\nSelect files to sync\nView detailed diff\nCancel" | \
        fzf --prompt="Choose action: " --height=30%)
    
    case "$action" in
        "Sync all changes")
            echo "🔄 Adding all changes..."
            git add .
            ;;
        "Select files to sync")
            local files
            files=$(git status --porcelain | \
                fzf -m --prompt="Select files to sync: " \
                    --preview 'git diff --color=always {2}' \
                    --preview-window=right:60%:wrap)
            
            if [[ -n "$files" ]]; then
                echo "$files" | while read -r line; do
                    local file=$(echo "$line" | awk '{print $2}')
                    git add "$file"
                    echo "✅ Added: $file"
                done
            else
                echo "❌ No files selected - cancelling sync"
                return 0
            fi
            ;;
        "View detailed diff")
            git diff --color=always | less -R
            echo "Press Enter to continue or Ctrl+C to cancel..."
            read -r
            fsync-dot  # 重新開始選單
            return
            ;;
        *)
            echo "❌ Sync cancelled"
            return 0
            ;;
    esac
    
    # 檢查是否有檔案被暫存
    if ! git diff --cached --quiet; then
        # 產生 commit 訊息
        local commit_msg
        local default_msg="Update dotfiles - $(date '+%Y-%m-%d %H:%M')"
        
        echo ""
        echo "📝 Enter commit message (press Enter for default):"
        echo "Default: $default_msg"
        read -r commit_msg
        
        if [[ -z "$commit_msg" ]]; then
            commit_msg="$default_msg"
        fi
        
        # 提交變更
        echo ""
        echo "💾 Committing changes..."
        if git commit -m "$commit_msg"; then
            echo "✅ Changes committed successfully"
            
            # 推送到 GitHub
            echo ""
            echo "🚀 Pushing to GitHub..."
            if git push; then
                echo "✅ Successfully synced to GitHub!"
                echo ""
                echo "🏁 Dotfiles sync completed!"
            else
                echo "❌ Failed to push to GitHub"
                echo "You may need to resolve conflicts or check your connection"
            fi
        else
            echo "❌ Failed to commit changes"
        fi
    else
        echo "❌ No staged changes to commit"
    fi
}

# 建立別名以保持向後相容
alias fone='f1'
alias FOne='f1'
alias fzf_help='f1'

# 初始化提示
# Initialize
# Only show F1 message for interactive shells
if [[ $- == *i* ]]; then
    echo "🏎️  FOne Racing Tools ready! Type 'f1' for pit stop menu 🏁"
fi