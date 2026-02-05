# ⚡ Extreme Speed Mode - Performance Guide

## What Changed?

The scripts have been optimized for **extreme speed mode** based on official KCP protocol documentation while maintaining AES encryption security.

---

## 🎯 Optimizations Applied

### KCP Configuration Changes

| Parameter | Old (fast2) | New (fast3) | Impact |
|-----------|-------------|-------------|--------|
| `mode` | fast2 | **fast3** | Preset for extreme speed |
| `interval` | 10ms | **10ms** | ✅ Maximum responsiveness |
| `conn` | 8 | **16** | 2x concurrent connections |
| `sndwnd` (server) | 4096 | **8192** | 2x send window |
| `rcvwnd` (server) | 4096 | **8192** | 2x receive window |
| `sndwnd` (client) | 2048 | **8192** | 4x send window |
| `rcvwnd` (client) | 2048 | **8192** | 4x receive window |
| `mtu` (client) | 1300 | **1400** | Larger packets |
| `acknodelay` | false | **true** | Instant ACKs |

### What This Means

**Official KCP "Extreme Speed Mode" formula:**
```
ikcp_nodelay(kcp, 1, 10, 2, 1)
```

Translated to our config:
- ✅ `nodelay: 1` - No delay mode enabled
- ✅ `interval: 10` - 10ms update interval (ultra-low latency)
- ✅ `resend: 2` - Fast retransmission after 2 ACK gaps
- ✅ `nc: 1` - Flow control disabled (nocongestion)
- ✅ `acknodelay: true` - Immediate ACK responses

---

## 🚀 Expected Performance Improvements

### Latency Reduction
- **30-40% lower average latency** compared to TCP
- **Up to 3x lower maximum delay** in lossy networks
- **10ms response time** for protocol updates

### Throughput Increase
- **16 concurrent connections** (vs 8) = better parallelization
- **8192 window size** allows more in-flight packets
- **1400 MTU** reduces fragmentation overhead

### Multi-User Capacity
With `conn: 16` and larger windows, the tunnel can efficiently handle:
- ✅ **Multiple simultaneous users**
- ✅ **Concurrent downloads/streams**
- ✅ **Better bandwidth utilization**

---

## 📊 Performance vs. Resource Trade-offs

### Bandwidth Overhead
- **~10-20% additional bandwidth** (KCP protocol overhead)
- Worth it for the latency reduction
- FEC (10 data + 3 parity shards) adds redundancy for reliability

### CPU Usage
- ✅ **Moderate increase** due to 10ms interval
- Modern servers handle this easily
- The `interval: 10` processes state updates 4x more frequently than default (40ms)

### Memory Usage
- **8192 windows require more RAM** per connection
- Each sndwnd/rcvwnd packet is ~1400 bytes
- ~23MB per connection (8192 × 1400 × 2)
- With 16 connections: ~370MB total (acceptable for modern systems)

---

## 🔒 Security Status

### Encryption: **ENABLED** ✅

```json
"kcp": {
  "block": "aes"  // AES encryption (default, secure)
}
```

- All traffic is **encrypted with AES**
- Secret key exchange remains secure
- Perfect for sharing with multiple people

If you ever want **maximum speed without encryption** (testing only):
```json
"block": "null"  // NO encryption, NO header (fastest)
```

⚠️ **NOT RECOMMENDED** unless on a completely trusted network!

---

## 💡 Real-World Scenarios

### Scenario 1: Sharing with Friends (Your Use Case)
- ✅ **16 connections** handle multiple users smoothly
- ✅ **8192 windows** prevent congestion
- ✅ **AES encryption** keeps everyone's traffic secure
- ✅ **Low latency** improves browsing/gaming experience

### Scenario 2: High-Bandwidth Tasks
- Video streaming (YouTube, Netflix)
- Large file downloads
- Video conferencing

### Scenario 3: Low-Latency Tasks
- Online gaming
- SSH sessions
- Real-time trading platforms

---

## 🧪 Testing Performance

### Bandwidth Test
```bash
# Via tunnel
proxychains4 curl -o /dev/null http://speedtest.tele2.net/100MB.zip

# Compare with direct connection
curl -o /dev/null http://speedtest.tele2.net/100MB.zip
```

### Latency Test
```bash
# Via tunnel
proxychains4 ping -c 10 8.8.8.8

# Direct
ping -c 10 8.8.8.8
```

### Multi-User Simulation
```bash
# Run 5 concurrent downloads
for i in {1..5}; do
  proxychains4 wget -O /dev/null http://speedtest.tele2.net/10MB.zip &
done
```

---

## 🔧 Fine-Tuning (Advanced)

### If You Experience Packet Loss
Increase FEC redundancy:
```json
"datashard": 10,
"parityshard": 5  // Increased from 3
```

### If You Have Tons of Bandwidth
Increase connections further:
```json
"conn": 32  // Doubled from 16
```

### If CPU Usage is Too High
Increase interval slightly:
```json
"interval": 20  // Still fast, lower CPU
```

### If You Have Gigabit Connection
Maximize windows:
```json
"sndwnd": 16384,
"rcvwnd": 16384
```

---

## 📈 Comparison Chart

| Mode | Latency | Throughput | CPU | Use Case |
|------|---------|------------|-----|----------|
| **Normal** (40ms interval) | High | Low | Low | Basic forwarding |
| **Fast** (20ms interval) | Medium | Medium | Medium | General use |
| **Fast2** (10ms interval) | Low | High | Medium-High | Your old config |
| **Fast3** (10ms + large windows) | **Lowest** | **Highest** | Medium-High | **Your new config** |
| **Unsafe** (no encryption) | Lowest | Maximum | High | Testing only ⚠️ |

---

## ✅ Summary

Your scripts now use **the fastest secure configuration** recommended by KCP documentation:

- ✅ **10ms interval** = ultra-low latency
- ✅ **8192 windows** = high throughput  
- ✅ **16 connections** = multi-user ready
- ✅ **AES encryption** = secure sharing
- ✅ **FEC enabled** = reliable on lossy networks

Perfect for your use case: **good connection + sharing with multiple people**!

---

## 🚦 Deployment

Just run the updated scripts:
```bash
# Server (foreign)
sudo ./server_setup.sh

# Client (Iran) 
sudo ./client_setup.sh
```

The extreme speed mode is now **the default**! 🎉
