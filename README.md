# 🎯 WI SNIPER - Advanced Wireless Security Testing Framework

[![Version](https://img.shields.io/badge/version-3.0-blue.svg)](https://github.com/Athexhacker/WI-SNIPER)
[![Kali Compatible](https://img.shields.io/badge/Kali-Linux%20Rolling-green.svg)](https://www.kali.org)
[![License](https://img.shields.io/badge/license-MIT-red.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.x-yellow.svg)](https://www.python.org)
[![Bash](https://img.shields.io/badge/bash-5.0+-orange.svg)](https://www.gnu.org/software/bash/)

> **"WI SNIPER is the Future of MITM WPA Attacks"** - Advanced wireless security testing for the modern era

## 📋 Overview

WI SNIPER is a sophisticated wireless security auditing tool designed for penetration testers and security professionals. It specializes in WPA/WPA2 security assessment through advanced MITM (Man-in-The-Middle) techniques, rogue access point deployment, and credential harvesting. Built with stability and functionality in mind, it provides a comprehensive framework for testing wireless network security.

### 🎯 Key Features

- **Automated Handshake Capture** - Smart detection and capture of WPA/WPA2 handshakes
- **Rogue Access Point** - Creates convincing fake access points mimicking target networks
- **Advanced Deauthentication** - Multiple methods including aireplay-ng and mdk3
- **Captive Portal** - Professional phishing pages with 40+ language support
- **Credential Validation** - Real-time password verification against captured handshakes
- **Multi-language Support** - 40+ languages including brand-specific templates
- **Headless Mode** - Run without GUI for automated deployments
- **Detailed Logging** - Comprehensive audit trails for all activities

## 🚀 Quick Start

### Prerequisites


# Minimum requirements
- Kali Linux Rolling (recommended) or any Debian-based distribution
- External wireless adapter with monitor mode support
- 2GB RAM minimum
- 10GB free disk space
- Root access



## 🔧 How It Works
WI SNIPER employs a sophisticated multi-stage attack methodology:

1. Reconnaissance Phase
Network scanning and enumeration

Client detection and analysis

Signal strength monitoring

Vendor identification via OUI lookup

2. Handshake Capture
Passive monitoring of target network

Active deauthentication to force reconnections

Handshake verification using aircrack-ng/pyrit

Automatic handshake storage and management

3. Rogue Access Point Deployment
Creates identical SSID to target network

Spoofs target MAC address

Configures proper channel and encryption

Sets up DHCP server for client management

4. Captive Portal
Serves convincing login pages

Supports 40+ languages and router brands

SSL certificate generation for HTTPS

DNS spoofing to redirect all traffic

5. Credential Harvesting
Captures submitted passwords

Real-time validation against handshake

Automatic storage with metadata

Success notification and cleanup


## 📊 Attack Flow Diagram
```
[Network Scan] → [Handshake Capture] → [Rogue AP Setup]
       ↓                 ↓                    ↓
[Client Detection] → [Deauth Attack] → [Captive Portal]
       ↓                 ↓                    ↓
[Credential Capture] → [Validation] → [Success Reporting]
```

## 🛠️ Advanced Features
Headless Mode

*Run completely automated without GUI*

```
FLUX_AUTO=1 KEEP_NETWORK=0 ./wisniper.sh

```
Debug Mode
# Detailed output for troubleshooting
```
FLUX_DEBUG=1 ./wisniper.sh
```

## 🔄 Changelog
Version 3.0 (Current)
Complete code rewrite with improved stability

Added headless mode support

Enhanced error handling and logging

Improved handshake detection

Added 15+ new phishing templates

Better dependency management

Automatic cleanup on exit

Real-time credential validation

Enhanced UI with progress indicators

Version 2.x
Initial release with core functionality

Basic handshake capture

Rogue AP deployment

Captive portal support

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.


### Made with ❤️ by ATHEX H4CK3R
***"WI SNIPER is The Future"***

# Thank you for using WI SNIPER!
*Keep Visiting. Enjoy! 😊*


