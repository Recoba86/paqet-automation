# 🛠️ Management Tools Guide

Complete guide for managing your paqet tunnel with the included tools.

---

## 📋 Available Tools

| Tool | Purpose | Usage |
|------|---------|-------|
| **dashboard.sh** | Unified management interface | `sudo ./dashboard.sh` |
| **monitor.sh** | Health check & auto-recovery | `sudo ./monitor.sh` |
| **stats.sh** | Performance monitoring | `sudo ./stats.sh` |
| **test-tunnel.sh** | Connectivity testing | `sudo ./test-tunnel.sh` |
| **backup.sh** | Configuration backup | `sudo ./backup.sh` |
| **update.sh** | Version updater | `sudo ./update.sh` |

---

## 🎛️ Dashboard (Recommended)

### Interactive Management Interface

```bash
sudo ./dashboard.sh
```

**Features:**
- ✅ Start/Stop/Restart service
- ✅ View live logs
- ✅ Run all monitoring tools
- ✅ Edit configuration
- ✅ System resource monitoring

**Perfect for:** Daily management and troubleshooting

---

## 💓 Health Check (`monitor.sh`)

### Auto-Recovery Monitoring

```bash
# Manual check
sudo ./monitor.sh

# Automated (every 5 minutes)
sudo crontab -e
# Add: */5 * * * * /path/to/monitor.sh
```

**What it checks:**
- ✅ Service status
- ✅ Process running
- ✅ SOCKS5 port (client)
- ✅ Memory usage
- ✅ Auto-restart on failure

**Logs:** `/var/log/paqet-monitor.log`

---

## 📊 Performance Stats (`stats.sh`)

### Real-Time Monitoring

```bash
sudo ./stats.sh
```

**Shows:**
- System information
- Service uptime
- Memory/CPU usage
- Network statistics (RX/TX)
- Active SOCKS5 connections (client)
- Recent log entries
- Live bandwidth (10s sample)

**Perfect for:** Checking current performance

---

## 🧪 Tunnel Testing (`test-tunnel.sh`)

### Comprehensive Tests

```bash
sudo ./test-tunnel.sh
```

**Test Suite:**
1. ✅ Service status
2. ✅ Process check
3. ✅ Configuration validation
4. ✅ Port listening
5. ✅ Network interface
6. ✅ **Actual connection test** (client)

**Client test:** Verifies tunnel works by fetching external IP

---

## 💾 Configuration Backup (`backup.sh`)

### Automated Backups

```bash
# Manual backup
sudo ./backup.sh

# Automated (weekly on Sunday 3 AM)
sudo crontab -e
# Add: 0 3 * * 0 /path/to/backup.sh
```

**What it backs up:**
- `/etc/paqet/config.json`
- `/etc/systemd/system/paqet.service`
- Network settings
- Version info

**Location:** `/root/paqet-backups/`

**Retention:** Last 5 backups

**Restore:**
```bash
sudo tar -xzf /root/paqet-backups/paqet-backup-YYYYMMDD_HHMMSS.tar.gz -C /
sudo systemctl restart paqet
```

---

## 📈 Enhanced Logging

### Systemd Journal

**View logs:**
```bash
# Live logs
sudo journalctl -u paqet -f

# Today's logs
sudo journalctl -u paqet --since today

# Last 100 lines
sudo journalctl -u paqet -n 100

# Specific time range
sudo journalctl -u paqet --since "2026-02-05 00:00:00" --until "2026-02-05 23:59:59"
```

**What's logged:**
- Service start/stop
- Connection events
- Errors and warnings
- All stdout/stderr from paqet

**Log location:** Systemd journal (persistent)

---

## 🔄 Automated Monitoring Setup

### Recommended Cron Jobs

```bash
sudo crontab -e
```

Add these lines:

```bash
# Health check every 5 minutes
*/5 * * * * /path/to/monitor.sh >> /var/log/paqet-monitor.log 2>&1

# Weekly backup (Sunday 3 AM)
0 3 * * 0 /path/to/backup.sh >> /var/log/paqet-backup.log 2>&1

# Daily test (every day 2 AM)
0 2 * * * /path/to/test-tunnel.sh >> /var/log/paqet-test.log 2>&1
```

---

## 📊 Monitoring Best Practices

### Daily Checks
```bash
# Quick status
sudo ./dashboard.sh  # Option 4 (Status)

# Or use systemd
sudo systemctl status paqet
```

### Weekly Tasks
```bash
# Review logs
sudo journalctl -u paqet --since "1 week ago" | grep -i error

# Check stats
sudo ./stats.sh

# Run backup
sudo ./backup.sh
```

### Monthly Tasks
```bash
# Check for updates
sudo ./update.sh

# Review monitoring logs
grep ERROR /var/log/paqet-monitor.log

# Clean old logs
sudo journalctl --vacuum-time=30d
```

---

## 🚨 Troubleshooting Workflow

### Issue: Service Not Running

```bash
# 1. Check status
sudo systemctl status paqet

# 2. View recent errors
sudo journalctl -u paqet -n 50

# 3. Run health check
sudo ./monitor.sh

# 4. Test configuration
sudo ./test-tunnel.sh

# 5. Restart service
sudo systemctl restart paqet
```

### Issue: Slow Performance

```bash
# 1. Check stats
sudo ./stats.sh

# 2. Check memory usage
ps aux | grep paqet

# 3. Check network
ss -tuln | grep 443  # Server
ss -tuln | grep 1080  # Client

# 4. Review logs for errors
sudo journalctl -u paqet --since "1 hour ago" | grep -i error
```

### Issue: Connection Failed (Client)

```bash
# 1. Run comprehensive test
sudo ./test-tunnel.sh

# 2. Check server reachability
nc -zvu SERVER_IP 443

# 3. Verify config
cat /etc/paqet/config.json | jq .

# 4. Check logs
sudo journalctl -u paqet -f
```

---

## 📧 Alerting (Optional)

### Email Alerts on Failure

Create `/usr/local/bin/paqet-alert.sh`:

```bash
#!/bin/bash
if ! systemctl is-active --quiet paqet; then
    echo "Paqet service is down on $(hostname)" | \
    mail -s "ALERT: Paqet Down" your-email@example.com
fi
```

Add to cron:
```bash
*/10 * * * * /usr/local/bin/paqet-alert.sh
```

---

## 📱 Monitoring for Users (Shared Setup)

### Simple User Status Page

Create for users you're sharing with:

```bash
# /var/www/html/paqet-status.html
<!DOCTYPE html>
<html>
<head><title>Proxy Status</title></head>
<body>
<h1>Proxy Status: <span id="status">Checking...</span></h1>
<script>
fetch('http://YOUR-IP:1080')
  .then(() => document.getElementById('status').textContent = '✅ Online')
  .catch(() => document.getElementById('status').textContent = '❌ Offline');
</script>
</body>
</html>
```

---

## 🎯 Quick Reference

| Task | Command |
|------|---------|
| Open dashboard | `sudo ./dashboard.sh` |
| Check health | `sudo ./monitor.sh` |
| View stats | `sudo ./stats.sh` |
| Test tunnel | `sudo ./test-tunnel.sh` |
| Backup config | `sudo ./backup.sh` |
| Update version | `sudo ./update.sh` |
| View live logs | `sudo journalctl -u paqet -f` |
| Restart service | `sudo systemctl restart paqet` |

---

**All tools are executable and ready to use!** 🚀
