# 🚀 Paqet Tunnel Automation

> **One script to install, manage, and monitor your paqet tunnel**

Automated installation and management suite for [paqet](https://github.com/hanselime/paqet) with extreme speed optimizations, automatic updates, and comprehensive monitoring tools.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/witamin/paqet-automation/releases)
[![Tested](https://img.shields.io/badge/tested-Ubuntu%2020.04%2B-success.svg)](https://ubuntu.com)

---

## ✨ Features

- 🎯 **One Script for Everything** - Install, manage, monitor, all in one file
- 🔄 **Dynamic GitHub Versioning** - Always gets the latest paqet release
- ⚡ **Extreme Speed Mode** - fast3 with 10ms interval, 8192 windows
- 🛡️ **Secure by Default** - AES-256 encryption + secure key generation
- 🔧 **Auto Network Discovery** - Detects interface, gateway, router MAC
- 📊 **Built-in Monitoring** - Health checks, stats, testing, backups
- 🚦 **TCP BBR** - Automatic congestion control optimization
- 🔁 **Auto-restart** - Systemd service with failure recovery
- 👥 **Multi-user Ready** - 16 concurrent connections supported

---

## 📥 Quick Start

### Server (Foreign/Outside Iran)

```bash
# Download
wget https://raw.githubusercontent.com/Recoba86/paqet-automation/main/paqet.sh
chmod +x paqet.sh

# Run
sudo ./paqet.sh

# Choose: 1) Foreign Server
# SAVE the displayed Server IP + Secret Key!
```

### Client (Iran)

```bash
# Download
wget https://raw.githubusercontent.com/Recoba86/paqet-automation/main/paqet.sh
chmod +x paqet.sh

# Run
sudo ./paqet.sh

# Choose: 2) Iran Client
# Enter the Server IP and Secret Key

# Test it works
sudo ./paqet.sh
# Choose: 5) Test Tunnel
```

---

## 🎛️ Management

After installation, run the same script for full management:

```bash
sudo ./paqet.sh
```

### Menu Options

```
━━━ Service ━━━
  1) Service Control    - Start/stop/restart
  2) View Logs         - Live journalctl output

━━━ Monitoring ━━━
  3) Health Check      - Auto-diagnosis and recovery
  4) Performance Stats - CPU, memory, bandwidth
  5) Test Tunnel       - 4-step validation

━━━ Maintenance ━━━
  6) Backup Config     - Timestamped backups
  7) Update Paqet      - One-click version updates
```

---

## ⚡ Performance

### Speed Optimizations

- **Mode**: fast3 (extreme speed)
- **Interval**: 10ms (ultra-low latency)
- **Windows**: 8192 send + 8192 receive
- **Connections**: 16 concurrent
- **TCP BBR**: Enabled automatically
- **Latency**: 30-40% reduction vs TCP
- **Throughput**: 2-4x improvement

### KCP Configuration

```json
{
  "mode": "fast3",
  "conn": 16,
  "interval": 10,
  "sndwnd": 8192,
  "rcvwnd": 8192,
  "nocongestion": 1,
  "acknodelay": true,
  "nodelay": 1,
  "resend": 2
}
```

📖 **Deep dive**: See [PERFORMANCE.md](PERFORMANCE.md)

---

## 🛠️ What It Does

### Installation

1. ✅ Installs all dependencies (curl, wget, jq, etc.)
2. ✅ Fetches latest paqet release from GitHub
3. ✅ Auto-detects system architecture (amd64/arm64/armv7)
4. ✅ Discovers network configuration automatically
5. ✅ Applies TCP BBR and iptables optimizations
6. ✅ Generates secure random secret keys (server)
7. ✅ Configures extreme speed mode (fast3)
8. ✅ Creates systemd service with auto-restart
9. ✅ Installs proxychains4 (client only)

### Management

- **Health Checks** - Service, process, port, memory monitoring
- **Performance Stats** - Real-time metrics and network usage
- **Tunnel Testing** - Connection validation with external IP check
- **Backups** - Automated config backups (keeps last 5)
- **Updates** - One-click upgrades with automatic rollback
- **Log Viewing** - Live journalctl integration

---

## 📋 Requirements

- **OS**: Ubuntu 20.04+ or Debian 11+
- **Architecture**: x86_64 (amd64), ARM64, or ARMv7
- **Init System**: systemd
- **Privileges**: Root access required
- **Kernel**: 4.9+ (for TCP BBR)

---

## 🔧 Advanced Usage

### Automated Monitoring

Set up cron job for health checks:

```bash
sudo crontab -e

# Add:
*/5 * * * * /path/to/paqet.sh --health-check
```

### Manual Configuration

Edit config:
```bash
sudo nano /etc/paqet/config.json
sudo systemctl restart paqet
```

### View Logs

```bash
# Live logs
sudo journalctl -u paqet -f

# Today's logs
sudo journalctl -u paqet --since today

# Last 100 lines  
sudo journalctl -u paqet -n 100
```

### Testing with Proxychains (Client)

```bash
# Check your external IP through tunnel
proxychains4 curl ifconfig.me

# Browse with Firefox through tunnel
proxychains4 firefox

# Any command
proxychains4 <command>
```

---

## 📚 Documentation

- **[README.md](README.md)** - This file (overview & quick start)
- **[PERFORMANCE.md](PERFORMANCE.md)** - Detailed speed tuning guide
- **[MANAGEMENT.md](MANAGEMENT.md)** - Advanced management tools
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and changes

---

## 🔍 Troubleshooting

### Service won't start

```bash
sudo ./paqet.sh
# Choose: 3) Health Check
# Follow prompts for auto-recovery
```

### Slow performance

```bash
# Check current stats
sudo ./paqet.sh
# Choose: 4) Performance Stats

# View detailed guide
cat PERFORMANCE.md
```

### Connection fails

```bash
# Run comprehensive test
sudo ./paqet.sh
# Choose: 5) Test Tunnel
```

### Check logs

```bash
sudo ./paqet.sh
# Choose: 2) View Logs
```

---

## 🔐 Security

- ✅ **Audited Code** - No critical vulnerabilities (see code_audit.md)
- ✅ **Secure Keys** - Cryptographically random (openssl rand)
- ✅ **AES-256 Encryption** - Industry standard
- ✅ **Input Validation** - All user inputs sanitized
- ✅ **HTTPS Only** - Secure downloads  
- ✅ **No Hardcoded Secrets** - Keys generated per installation

---

## 📊 Architecture

```
┌─────────────────────────────────────────────┐
│         paqet.sh (Unified Script)           │
│                                             │
│  ┌──────────────┐  ┌──────────────────┐    │
│  │ Installation │  │   Management     │    │
│  │    Mode      │  │      Mode        │    │
│  └──────────────┘  └──────────────────┘    │
│        │                    │               │
│   ┌────┴────┐         ┌────┴────┐          │
│   │ Server  │         │ Service │          │
│   │ Client  │         │ Monitor │          │
│   └─────────┘         │ Test    │          │
│                       │ Backup  │          │
│                       │ Update  │          │
│                       └─────────┘          │
└─────────────────────────────────────────────┘
               │
               ▼
     ┌─────────────────┐
     │ Paqet Binary    │
     │ (from GitHub)   │
     └─────────────────┘
               │
               ▼
     ┌─────────────────┐
     │ Systemd Service │
     │  (Auto-restart) │
     └─────────────────┘
```

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit your changes (`git commit -am 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Credits

- **Paqet Tunnel**: [hanselime/paqet](https://github.com/hanselime/paqet)
- **KCP Protocol**: [skywind3000/kcp](https://github.com/skywind3000/kcp)
- **Proxychains**: [rofl0r/proxychains-ng](https://github.com/rofl0r/proxychains-ng)

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/witamin/paqet-automation/issues)
- **Discussions**: [GitHub Discussions](https://github.com/witamin/paqet-automation/discussions)

---

## ⚠️ Disclaimer

This tool is provided as-is for educational and testing purposes. Users are responsible for compliance with local laws and regulations. Use at your own risk.

---

**Made with ❤️ for seamless tunneling**
