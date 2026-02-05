# 🚀 Paqet Tunnel - ONE Script for Everything

## The Only File You Need: `paqet.sh`

One intelligent script that handles **installation AND management** automatically!

---

## 📥 Installation

### 1. Download
```bash
wget https://raw.githubusercontent.com/Recoba86/paqet-automation/main/paqet.sh
chmod +x paqet.sh
```

### 2. Run on Foreign Server
```bash
sudo ./paqet.sh
```

**Menu shows:**
```
╔════════════════════════════════════╗
║   Paqet Tunnel Installer          ║
╚════════════════════════════════════╝

Select Installation Type:
  1) Foreign Server (Outside Iran)  ← Choose this
  2) Iran Client (Inside Iran)
  0) Exit
```

**Result:** Auto-installs, shows Server IP + Secret Key

---

### 3. Run on Iran Server
```bash
sudo ./paqet.sh
```

**Menu shows:**
```
╔════════════════════════════════════╗
║   Paqet Tunnel Installer          ║
╚════════════════════════════════════╝

Select Installation Type:
  1) Foreign Server (Outside Iran)
  2) Iran Client (Inside Iran)  ← Choose this
  0) Exit
```

**Prompts:**
- Paste Server IP
- Paste Secret Key

**Result:** Auto-installs everything!

---

## 🎛️ Management (After Installation)

Run the same script again:
```bash
sudo ./paqet.sh
```

**Now shows Management Menu:**
```
╔════════════════════════════════════╗
║   Paqet Tunnel Management          ║
╚════════════════════════════════════╝

Status: ● Running | Mode: client

━━━ Service ━━━
  1) Service Control
  2) View Logs

━━━ Monitoring ━━━
  3) Health Check
  4) Performance Stats
  5) Test Tunnel

━━━ Maintenance ━━━
  6) Backup Configuration
  7) Update Paqet
  
  0) Exit
```

---

## ✨ Features

### Auto-Detection
- ✅ Knows if paqet is installed or not
- ✅ Shows installation menu if not installed
- ✅ Shows management menu if installed
- ✅ One command for everything!

### Installation
- ✅ Dynamic GitHub versioning
- ✅ Auto network discovery
- ✅ TCP BBR optimization
- ✅ Extreme speed mode (fast3)
- ✅ AES encryption
- ✅ Full automation

### Management
- ✅ Service control (start/stop/restart)
- ✅ Live log viewing
- ✅ Health checks with auto-recovery
- ✅ Performance monitoring
- ✅ Connection testing
- ✅ Configuration backups
- ✅ One-click updates

---

## 🎯 Complete Workflow

### Step 1: Foreign Server
```bash
# Download script
wget https://url/paqet.sh && chmod +x paqet.sh

# Run it
sudo ./paqet.sh

# Choose: 1) Foreign Server
# SAVE the IP + Secret Key shown!
```

### Step 2: Iran Client
```bash
# Download same script
wget https://url/paqet.sh && chmod +x paqet.sh

# Run it
sudo ./paqet.sh

# Choose: 2) Iran Client
# Enter: IP + Secret

# Test it works:
# Choose: 5) Test Tunnel
```

### Step 3: Daily Use
```bash
# Anytime you want to manage:
sudo ./paqet.sh

# Quick checks:
# → 3) Health Check
# → 4) Performance Stats
# → 5) Test Tunnel
```

---

## 🔧 What It Does

### During Installation

**Server Mode:**
1. Installs dependencies
2. Downloads latest paqet from GitHub
3. Auto-detects network (interface, gateway, MAC)
4. Configures extreme speed mode
5. Generates random secret key
6. Creates systemd service
7. **Displays Server IP + Secret Key**

**Client Mode:**
1. Asks for Server IP + Secret
2. Installs dependencies
3. Downloads latest paqet from GitHub
4. Auto-detects network
5. Configures extreme speed mode
6. Installs proxychains4
7. Creates systemd service
8. **Ready to use!**

### After Installation

**Service Control:**
- Start/stop/restart paqet
- View detailed status
- Monitor live logs

**Health & Monitoring:**
- Check service health
- Auto-restart on failure
- Performance stats (CPU, memory, bandwidth)
- Active connection count

**Testing:**
- 4-step validation test
- Connection verification (client)
- Real IP check

**Maintenance:**
- Automated config backups
- One-click version updates
- Preserves all settings

---

## 📊 Performance

- **Mode:** fast3 (extreme speed)
- **Latency:** 30-40% lower than TCP
- **Connections:** 16 concurrent
- **Windows:** 8192 (high throughput)
- **Encryption:** AES-256
- **Multi-user:** Ready!

---

## 💡 Pro Tips

1. **Bookmark this command:**
   ```bash
   alias paqet='sudo /path/to/paqet.sh'
   ```
   Then just type: `paqet`

2. **Regular checks** (weekly):
   - Option 3: Health Check
   - Option 4: Performance Stats
   - Option 6: Backup Config

3. **Monthly updates:**
   - Option 7: Update Paqet

4. **Troubleshooting:**
   - Option 5: Test Tunnel (diagnoses issues)
   - Option 2: View Logs (see what's happening)

---

## 🆘 Help

### Service won't start?
```bash
sudo ./paqet.sh
→ Choose: 3) Health Check
   (Auto-diagnoses and fixes)
```

### Connection issues?
```bash
sudo ./paqet.sh
→ Choose: 5) Test Tunnel
   (Runs comprehensive tests)
```

### Check performance?
```bash
sudo ./paqet.sh
→ Choose: 4) Performance Stats
   (Shows all metrics)
```

---

## 📁 Files Created

After installation:
```
/usr/local/bin/paqet              # Binary
/etc/paqet/config.json            # Configuration
/etc/systemd/system/paqet.service # Service
/etc/proxychains4.conf            # Proxy config (client)
/root/paqet-backups/              # Backups (when created)
```

Logs:
```bash
journalctl -u paqet -f   # Live logs
journalctl -u paqet --since today  # Today's logs
```

---

## 🎉 That's It!

**One script. Install + Manage. Forever.**

No confusion. No multiple files. Just run `./paqet.sh` anytime!

---

## 📚 Technical Details

For deep dive into performance tuning, see:
- [PERFORMANCE.md](PERFORMANCE.md) - Speed optimization guide
- [MANAGEMENT.md](MANAGEMENT.md) - Advanced management

---

**Made with ❤️ for seamless deployment**

**Questions?** Just run the script and explore the menu! 🚀
