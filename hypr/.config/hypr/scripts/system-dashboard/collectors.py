import os
import sys
import time
import socket
import platform
import subprocess
import threading
import json
import re

class SystemCollector:
    def __init__(self):
        self.static_data = self._get_static_data()

    def _get_static_data(self):
        # OS Name & Version
        os_name = "Linux"
        os_version = ""
        if os.path.exists("/etc/os-release"):
            with open("/etc/os-release", "r") as f:
                for line in f:
                    if line.startswith("NAME="):
                        os_name = line.split("=")[1].strip().strip('"')
                    elif line.startswith("VERSION_ID="):
                        os_version = line.split("=")[1].strip().strip('"')
        
        # Shell
        shell = os.environ.get("SHELL", "")
        if shell:
            shell = os.path.basename(shell)
        else:
            shell = "unknown"

        # Theme detection (GTK Theme)
        gtk_theme = "Unknown"
        try:
            # Try reading from gtk-3.0 config
            gtk3_conf = os.path.expanduser("~/.config/gtk-3.0/settings.ini")
            if os.path.exists(gtk3_conf):
                with open(gtk3_conf, "r") as f:
                    for line in f:
                        if "gtk-theme-name" in line:
                            gtk_theme = line.split("=")[1].strip()
        except Exception:
            pass

        return {
            "hostname": socket.gethostname(),
            "username": os.environ.get("USER") or os.environ.get("LOGNAME") or "user",
            "os": f"{os_name} {os_version}".strip(),
            "kernel": platform.release(),
            "arch": platform.machine(),
            "shell": shell,
            "de": os.environ.get("XDG_CURRENT_DESKTOP", "Hyprland"),
            "wm": "Hyprland",
            "theme": gtk_theme
        }

    def get_data(self):
        # Uptime
        uptime_secs = 0.0
        uptime_str = "unknown"
        boot_time_str = "unknown"
        try:
            with open("/proc/uptime", "r") as f:
                uptime_secs = float(f.readline().split()[0])
            
            # Format uptime
            days = int(uptime_secs // 86400)
            hours = int((uptime_secs % 86400) // 3600)
            minutes = int((uptime_secs % 3600) // 60)
            
            parts = []
            if days > 0:
                parts.append(f"{days}d")
            if hours > 0:
                parts.append(f"{hours}h")
            parts.append(f"{minutes}m")
            uptime_str = " ".join(parts)
            
            # Boot time
            boot_epoch = time.time() - uptime_secs
            boot_time_str = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(boot_epoch))
        except Exception:
            pass

        # Active sessions/users
        users = []
        try:
            res = subprocess.run(["who"], capture_output=True, text=True, check=True)
            for line in res.stdout.strip().split("\n"):
                if line:
                    parts = line.split()
                    if len(parts) >= 2:
                        users.append(f"{parts[0]} ({parts[1]})")
        except Exception:
            pass

        data = self.static_data.copy()
        data["uptime"] = uptime_str
        data["boot_time"] = boot_time_str
        data["active_users"] = list(set(users))
        return data


class CPUCollector:
    def __init__(self):
        self.last_cpu_times = {}
        self.last_time = 0.0
        self.core_count = 0
        self.thread_count = 0
        self.cpu_model = "Unknown"
        self._get_static_info()
        # Initialize times
        self._read_cpu_times()

    def _get_static_info(self):
        try:
            with open("/proc/cpuinfo", "r") as f:
                cores = set()
                processors = 0
                for line in f:
                    if line.startswith("model name"):
                        self.cpu_model = line.split(":")[1].strip()
                    elif line.startswith("cpu cores"):
                        self.core_count = int(line.split(":")[1].strip())
                    elif line.startswith("processor"):
                        processors += 1
                self.thread_count = processors
                if self.core_count == 0:
                    self.core_count = processors
        except Exception:
            pass

    def _read_cpu_times(self):
        times = {}
        try:
            with open("/proc/stat", "r") as f:
                for line in f:
                    if line.startswith("cpu"):
                        parts = line.split()
                        name = parts[0]
                        # user, nice, system, idle, iowait, irq, softirq, steal
                        vals = [float(x) for x in parts[1:9]]
                        times[name] = {
                            "total": sum(vals),
                            "idle": vals[3] + vals[4] # idle + iowait
                        }
        except Exception:
            pass
        return times

    def get_data(self):
        current_times = self._read_cpu_times()
        now = time.time()
        
        cpu_util = 0.0
        per_core_util = {}

        if self.last_cpu_times:
            for name, curr in current_times.items():
                if name in self.last_cpu_times:
                    prev = self.last_cpu_times[name]
                    total_diff = curr["total"] - prev["total"]
                    idle_diff = curr["idle"] - prev["idle"]
                    if total_diff > 0:
                        util = (1.0 - (idle_diff / total_diff)) * 100.0
                        util = max(0.0, min(100.0, util))
                        if name == "cpu":
                            cpu_util = util
                        else:
                            # e.g. cpu0, cpu1
                            core_idx = name[3:]
                            per_core_util[core_idx] = round(util, 1)

        self.last_cpu_times = current_times
        self.last_time = now

        # Frequency
        freqs = []
        try:
            for i in range(self.thread_count):
                path = f"/sys/devices/system/cpu/cpu{i}/cpufreq/scaling_cur_freq"
                if os.path.exists(path):
                    with open(path, "r") as f:
                        freqs.append(float(f.readline().strip()) / 1000.0) # to MHz
            avg_freq = sum(freqs) / len(freqs) if freqs else 0.0
        except Exception:
            avg_freq = 0.0

        # Temperature
        temp = 0.0
        try:
            # Find coretemp in hwmon
            for h in os.listdir("/sys/class/hwmon"):
                name_path = f"/sys/class/hwmon/{h}/name"
                if os.path.exists(name_path):
                    with open(name_path, "r") as f:
                        name = f.readline().strip()
                    if name == "coretemp" or name == "k10temp" or name == "zenpower":
                        # Read temp1_input (usually Package temp)
                        temp_path = f"/sys/class/hwmon/{h}/temp1_input"
                        if os.path.exists(temp_path):
                            with open(temp_path, "r") as f:
                                temp = float(f.readline().strip()) / 1000.0
                                break
        except Exception:
            pass

        # Load Average
        load_avg = [0.0, 0.0, 0.0]
        try:
            with open("/proc/loadavg", "r") as f:
                parts = f.readline().split()
                load_avg = [float(x) for x in parts[:3]]
        except Exception:
            pass

        return {
            "model": self.cpu_model,
            "utilization": round(cpu_util, 1),
            "per_core": per_core_util,
            "frequency": round(avg_freq, 0),
            "temperature": round(temp, 1),
            "cores": self.core_count,
            "threads": self.thread_count,
            "load_avg": load_avg
        }


class MemoryCollector:
    def get_data(self):
        mem = {}
        try:
            with open("/proc/meminfo", "r") as f:
                for line in f:
                    parts = line.split()
                    if len(parts) >= 2:
                        key = parts[0].strip(":")
                        val = int(parts[1]) * 1024 # Convert kB to bytes
                        mem[key] = val
        except Exception:
            return {}

        total = mem.get("MemTotal", 0)
        free = mem.get("MemFree", 0)
        available = mem.get("MemAvailable", free) # Fallback to free if Available not supported
        buffers = mem.get("Buffers", 0)
        cached = mem.get("Cached", 0)
        used = total - available

        swap_total = mem.get("SwapTotal", 0)
        swap_free = mem.get("SwapFree", 0)
        swap_used = swap_total - swap_free

        return {
            "total": total,
            "used": used,
            "available": available,
            "buffers": buffers,
            "cached": cached,
            "utilization": round((used / total * 100.0), 1) if total > 0 else 0.0,
            "swap_total": swap_total,
            "swap_used": swap_used,
            "swap_free": swap_free,
            "swap_utilization": round((swap_used / swap_total * 100.0), 1) if swap_total > 0 else 0.0
        }


class GPUCollector:
    def __init__(self):
        self.gpu_type = "unknown"
        self.gpu_model = "Unknown GPU"
        self.sysfs_path = None
        self._detect_gpu()

    def _detect_gpu(self):
        # Check if nvidia-smi is available
        if subprocess.run(["which", "nvidia-smi"], capture_output=True).returncode == 0:
            self.gpu_type = "nvidia"
            # Get model
            try:
                res = subprocess.run(["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"], capture_output=True, text=True)
                self.gpu_model = res.stdout.strip()
            except Exception:
                self.gpu_model = "NVIDIA GPU"
            return

        # Check for Intel / AMD cards in sysfs
        if os.path.exists("/sys/class/drm"):
            for card in os.listdir("/sys/class/drm"):
                if card.startswith("card") and not "-" in card:
                    vendor_path = f"/sys/class/drm/{card}/device/vendor"
                    if os.path.exists(vendor_path):
                        with open(vendor_path, "r") as f:
                            vendor = f.readline().strip()
                        
                        if vendor == "0x1002":
                            self.gpu_type = "amd"
                            self.sysfs_path = f"/sys/class/drm/{card}/device"
                            self.gpu_model = self._get_lspci_name("1002")
                            break
                        elif vendor == "0x8086":
                            self.gpu_type = "intel"
                            self.sysfs_path = f"/sys/class/drm/{card}/device"
                            self.gpu_model = self._get_lspci_name("8086")
                            break

    def _get_lspci_name(self, vendor_id):
        try:
            res = subprocess.run(["lspci", "-d", f"{vendor_id}:", "-k"], capture_output=True, text=True)
            for line in res.stdout.split("\n"):
                if "VGA compatible controller" in line or "3D controller" in line:
                    # e.g. "00:02.0 VGA compatible controller: Intel Corporation Alder Lake-UP3 GT2 [Iris Xe Graphics] (rev 0c)"
                    parts = line.split(":")
                    if len(parts) >= 3:
                        return parts[2].strip().replace("Corporation", "").replace("Advanced Micro Devices, Inc. [AMD/ATI]", "AMD")
        except Exception:
            pass
        return "Intel HD Graphics" if vendor_id == "8086" else "AMD Radeon GPU"

    def get_data(self):
        if self.gpu_type == "nvidia":
            try:
                # Query nvidia-smi
                res = subprocess.run([
                    "nvidia-smi", 
                    "--query-gpu=utilization.gpu,utilization.memory,memory.total,memory.used,temperature.gpu,power.draw", 
                    "--format=csv,noheader,nounits"
                ], capture_output=True, text=True, check=True)
                
                parts = res.stdout.strip().split(",")
                if len(parts) >= 6:
                    return {
                        "type": "NVIDIA",
                        "model": self.gpu_model,
                        "utilization": float(parts[0].strip()),
                        "vram_total": float(parts[2].strip()) * 1024 * 1024, # to bytes
                        "vram_used": float(parts[3].strip()) * 1024 * 1024,
                        "vram_utilization": float(parts[1].strip()),
                        "temperature": float(parts[4].strip()),
                        "power": float(parts[5].strip())
                    }
            except Exception:
                pass

        elif self.gpu_type == "amd":
            try:
                # Read AMD sysfs nodes
                util = 0.0
                busy_path = f"{self.sysfs_path}/gpu_busy_percent"
                if os.path.exists(busy_path):
                    with open(busy_path, "r") as f:
                        util = float(f.readline().strip())

                # Temp
                temp = 0.0
                hwmon_dir = f"{self.sysfs_path}/hwmon"
                if os.path.exists(hwmon_dir):
                    for h in os.listdir(hwmon_dir):
                        temp_path = f"{hwmon_dir}/{h}/temp1_input"
                        if os.path.exists(temp_path):
                            with open(temp_path, "r") as f:
                                temp = float(f.readline().strip()) / 1000.0
                                break

                # VRAM
                vram_total = 0
                vram_used = 0
                total_path = f"{self.sysfs_path}/mem_info_vram_total"
                used_path = f"{self.sysfs_path}/mem_info_vram_used"
                if os.path.exists(total_path) and os.path.exists(used_path):
                    with open(total_path, "r") as f:
                        vram_total = int(f.readline().strip())
                    with open(used_path, "r") as f:
                        vram_used = int(f.readline().strip())

                # Power
                power = 0.0
                if os.path.exists(hwmon_dir):
                    for h in os.listdir(hwmon_dir):
                        power_path = f"{hwmon_dir}/{h}/power1_average"
                        if os.path.exists(power_path):
                            with open(power_path, "r") as f:
                                power = float(f.readline().strip()) / 1000000.0 # microwatts to watts
                                break

                return {
                    "type": "AMD",
                    "model": self.gpu_model,
                    "utilization": util,
                    "vram_total": vram_total,
                    "vram_used": vram_used,
                    "vram_utilization": round((vram_used / vram_total * 100.0), 1) if vram_total > 0 else 0.0,
                    "temperature": temp,
                    "power": round(power, 1)
                }
            except Exception:
                pass

        elif self.gpu_type == "intel":
            try:
                # Intel GPU
                # We can read frequency and use it to estimate load or just display it.
                act_freq = 0
                max_freq = 0
                
                # Check under /sys/class/drm/card1/device/drm/card1/ or card0
                card_dir = None
                for d in os.listdir(self.sysfs_path):
                    if d.startswith("drm"):
                        for sub in os.listdir(f"{self.sysfs_path}/{d}"):
                            if sub.startswith("card") and not "-" in sub:
                                card_dir = f"{self.sysfs_path}/{d}/{sub}"
                                break
                
                if card_dir:
                    act_path = f"{card_dir}/gt_act_freq_mhz"
                    max_path = f"{card_dir}/gt_max_freq_mhz"
                    min_path = f"{card_dir}/gt_min_freq_mhz"
                    
                    if os.path.exists(act_path) and os.path.exists(max_path):
                        with open(act_path, "r") as f:
                            act_freq = int(f.readline().strip())
                        with open(max_path, "r") as f:
                            max_freq = int(f.readline().strip())
                        
                        min_freq = 0
                        if os.path.exists(min_path):
                            with open(min_path, "r") as f:
                                min_freq = int(f.readline().strip())
                        
                        # Estimate utilization based on frequency
                        if max_freq - min_freq > 0:
                            util = (act_freq - min_freq) / (max_freq - min_freq) * 100.0
                            util = max(0.0, min(100.0, util))
                        else:
                            util = 0.0
                
                # Power / Temp (usually CPU package temp)
                # VRAM is Shared
                return {
                    "type": "Intel",
                    "model": self.gpu_model,
                    "utilization": round(util, 1) if 'util' in locals() else 0.0,
                    "frequency": f"{act_freq} MHz / {max_freq} MHz",
                    "vram_total": 0, # Shared
                    "vram_used": 0,
                    "vram_utilization": 0,
                    "is_shared_vram": True,
                    "temperature": 0.0, # Handled by CPU temp mostly
                    "power": 0.0
                }
            except Exception:
                pass

        return {
            "type": "Unknown",
            "model": "Intel Integrated Graphics" if self.gpu_type == "intel" else "No Dedicated GPU detected",
            "utilization": 0.0,
            "vram_total": 0,
            "vram_used": 0,
            "vram_utilization": 0,
            "temperature": 0.0,
            "power": 0.0
        }


class StorageCollector:
    def get_data(self):
        drives = []
        try:
            # Parse df -h -T
            res = subprocess.run(["df", "-h", "-T"], capture_output=True, text=True, check=True)
            lines = res.stdout.strip().split("\n")
            
            # Header: Filesystem Type Size Used Avail Use% Mounted on
            for line in lines[1:]:
                parts = line.split()
                if len(parts) < 7:
                    continue
                
                fs = parts[0]
                fstype = parts[1]
                size = parts[2]
                used = parts[3]
                avail = parts[4]
                pct = parts[5].replace("%", "")
                mnt = parts[6]
                
                # Filter out virtual filesystems
                if fstype in ["tmpfs", "devtmpfs", "squashfs", "loop", "overlay"]:
                    continue
                if fs.startswith("/dev/loop") or fs.startswith("udev"):
                    continue
                    
                drives.append({
                    "filesystem": fs,
                    "type": fstype,
                    "size": size,
                    "used": used,
                    "available": avail,
                    "utilization": int(pct) if pct.isdigit() else 0,
                    "mount_point": mnt
                })
        except Exception:
            pass

        return {
            "drives": drives,
            "smart_health": "SMART not available (requires smartctl/sudo)"
        }


class NetworkCollector:
    def __init__(self):
        self.last_net_bytes = {}
        self.last_time = 0.0
        self.public_ip = "Fetching..."
        self.last_public_ip_fetch = 0.0
        self.ping_latency = "N/A"
        
        # Initial read
        self._read_net_bytes()
        
        # Start background ping worker
        threading.Thread(target=self._ping_worker, daemon=True).start()

    def _ping_worker(self):
        while True:
            try:
                # Ping 8.8.8.8 with 1s timeout
                res = subprocess.run(["ping", "-c", "1", "-W", "1", "8.8.8.8"], capture_output=True, text=True)
                if res.returncode == 0:
                    import re
                    m = re.search(r"time=([\d\.]+)\s*ms", res.stdout)
                    if m:
                        self.ping_latency = f"{float(m.group(1)):.0f} ms"
                    else:
                        self.ping_latency = "OK"
                else:
                    self.ping_latency = "Offline"
            except Exception:
                self.ping_latency = "Offline"
            time.sleep(2.0)

    def _read_net_bytes(self):
        bytes_map = {}
        try:
            with open("/proc/net/dev", "r") as f:
                lines = f.readlines()
                for line in lines[2:]: # Skip headers
                    if ":" in line:
                        parts = line.split(":")
                        iface = parts[0].strip()
                        vals = parts[1].split()
                        bytes_map[iface] = {
                            "recv": float(vals[0]),
                            "sent": float(vals[8])
                        }
        except Exception:
            pass
        return bytes_map

    def _fetch_public_ip(self):
        # Fetch public IP in background
        def worker():
            try:
                # Use standard library to fetch
                import urllib.request
                req = urllib.request.Request(
                    "https://api.ipify.org?format=json", 
                    headers={'User-Agent': 'Mozilla/5.0'}
                )
                with urllib.request.urlopen(req, timeout=5) as response:
                    data = json.loads(response.read().decode())
                    self.public_ip = data.get("ip", "Unknown")
            except Exception:
                try:
                    import urllib.request
                    with urllib.request.urlopen("https://icanhazip.com", timeout=5) as response:
                        self.public_ip = response.read().decode().strip()
                except Exception:
                    self.public_ip = "Offline"

        threading.Thread(target=worker, daemon=True).start()

    def get_data(self):
        # Trigger public IP fetch if not fetched in last 10 minutes
        now = time.time()
        if now - self.last_public_ip_fetch > 600 or self.public_ip == "Fetching...":
            self.last_public_ip_fetch = now
            self._fetch_public_ip()

        curr_bytes = self._read_net_bytes()
        
        # Find active interface by default route
        active_iface = "unknown"
        gateway = "unknown"
        try:
            with open("/proc/net/route", "r") as f:
                lines = f.readlines()
                for line in lines[1:]:
                    parts = line.split()
                    if len(parts) >= 3 and parts[1] == "00000000":
                        active_iface = parts[0]
                        # Gateway IP in hex
                        gw_hex = parts[2]
                        # Convert to decimal
                        gw_bytes = [int(gw_hex[i:i+2], 16) for i in range(0, 8, 2)]
                        gw_bytes.reverse() # Little endian
                        gateway = ".".join(str(b) for b in gw_bytes)
                        break
        except Exception:
            pass

        # If no default route, pick first non-lo interface with traffic
        if active_iface == "unknown" and curr_bytes:
            for iface in curr_bytes:
                if iface != "lo" and curr_bytes[iface]["recv"] > 0:
                    active_iface = iface
                    break

        # Calculate speeds
        down_speed = 0.0
        up_speed = 0.0
        if self.last_net_bytes and active_iface in curr_bytes and active_iface in self.last_net_bytes:
            time_diff = now - self.last_time
            if time_diff > 0:
                curr_iface = curr_bytes[active_iface]
                prev_iface = self.last_net_bytes[active_iface]
                down_speed = (curr_iface["recv"] - prev_iface["recv"]) / time_diff # Bytes/sec
                up_speed = (curr_iface["sent"] - prev_iface["sent"]) / time_diff

        self.last_net_bytes = curr_bytes
        self.last_time = now

        # Local IP
        local_ip = "Disconnected"
        if active_iface != "unknown":
            try:
                # Use socket to connect to a public IP (doesn't send traffic) to find local IP
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.settimeout(0.1)
                s.connect(("8.8.8.8", 80))
                local_ip = s.getsockname()[0]
                s.close()
            except Exception:
                # Fallback: parse ip addr
                try:
                    res = subprocess.run(["ip", "addr", "show", active_iface], capture_output=True, text=True)
                    m = re.search(r"inet\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})", res.stdout)
                    if m:
                        local_ip = m.group(1)
                except Exception:
                    pass

        # DNS
        dns_servers = []
        try:
            with open("/etc/resolv.conf", "r") as f:
                for line in f:
                    if line.startswith("nameserver"):
                        dns_servers.append(line.split()[1])
        except Exception:
            pass

        # Wi-Fi Info
        ssid = "N/A"
        signal = 0
        if active_iface.startswith("w"):
            try:
                res = subprocess.run([
                    "nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL", "dev", "wifi"
                ], capture_output=True, text=True)
                for line in res.stdout.strip().split("\n"):
                    if line.startswith("yes:"):
                        parts = line.split(":")
                        if len(parts) >= 3:
                            ssid = parts[1]
                            signal = int(parts[2]) if parts[2].isdigit() else 0
                            break
            except Exception:
                pass

        # MAC Address
        mac = "N/A"
        link_speed = "N/A"
        if active_iface != "unknown":
            try:
                with open(f"/sys/class/net/{active_iface}/address", "r") as f:
                    mac = f.readline().strip().upper()
            except Exception:
                pass

            # Try sysfs speed first
            try:
                speed_path = f"/sys/class/net/{active_iface}/speed"
                if os.path.exists(speed_path):
                    with open(speed_path, "r") as f:
                        val = int(f.readline().strip())
                        if val > 0:
                            link_speed = f"{val} Mbps"
            except Exception:
                pass
                
            # Fallback for Wi-Fi using nmcli
            if link_speed == "N/A" and active_iface.startswith("w"):
                try:
                    res = subprocess.run([
                        "nmcli", "-t", "-f", "ACTIVE,SSID,RATE", "dev", "wifi"
                    ], capture_output=True, text=True)
                    for line in res.stdout.strip().split("\n"):
                        if line.startswith("yes:"):
                            parts = line.split(":")
                            if len(parts) >= 3:
                                link_speed = parts[2].replace("Mbit/s", "Mbps").strip()
                                break
                except Exception:
                    pass

        return {
            "interface": active_iface,
            "local_ip": local_ip,
            "public_ip": self.public_ip,
            "gateway": gateway,
            "dns": dns_servers[:2] if dns_servers else ["None"],
            "download_speed": round(down_speed, 0), # Bytes/sec
            "upload_speed": round(up_speed, 0),
            "wifi_ssid": ssid,
            "wifi_signal": signal,
            "ping": self.ping_latency,
            "mac": mac,
            "link_speed": link_speed
        }


class BatteryCollector:
    def get_data(self):
        bat_dir = None
        if os.path.exists("/sys/class/power_supply"):
            for d in os.listdir("/sys/class/power_supply"):
                if d.startswith("BAT"):
                    bat_dir = f"/sys/class/power_supply/{d}"
                    break

        if not bat_dir:
            return {"present": False}

        try:
            # Percentage
            pct = 0
            with open(f"{bat_dir}/capacity", "r") as f:
                pct = int(f.readline().strip())

            # Status
            status = "Unknown"
            with open(f"{bat_dir}/status", "r") as f:
                status = f.readline().strip()

            # Power, energy, and remaining time
            power_now = 0.0
            energy_now = 0.0
            energy_full = 0.0
            energy_full_design = 0.0
            
            # Handle systems exposing energy or charge
            power_file = "power_now"
            energy_now_file = "energy_now"
            energy_full_file = "energy_full"
            energy_design_file = "energy_full_design"
            
            if not os.path.exists(f"{bat_dir}/{power_file}"):
                power_file = "current_now"
                energy_now_file = "charge_now"
                energy_full_file = "charge_full"
                energy_design_file = "charge_full_design"

            try:
                with open(f"{bat_dir}/{power_file}", "r") as f:
                    power_now = float(f.readline().strip())
                with open(f"{bat_dir}/{energy_now_file}", "r") as f:
                    energy_now = float(f.readline().strip())
                with open(f"{bat_dir}/{energy_full_file}", "r") as f:
                    energy_full = float(f.readline().strip())
                with open(f"{bat_dir}/{energy_design_file}", "r") as f:
                    energy_full_design = float(f.readline().strip())
            except Exception:
                pass

            # Calculate remaining time
            remaining_str = "Calculating..."
            if status == "Discharging":
                if power_now > 0:
                    hours = energy_now / power_now
                    h = int(hours)
                    m = int((hours - h) * 60)
                    remaining_str = f"{h}h {m}m remaining"
                else:
                    remaining_str = "Discharging"
            elif status == "Charging":
                if power_now > 0:
                    hours = (energy_full - energy_now) / power_now
                    h = int(hours)
                    m = int((hours - h) * 60)
                    remaining_str = f"{h}h {m}m to full"
                else:
                    remaining_str = "Charging"
            elif status == "Full":
                remaining_str = "Fully Charged"
            elif status == "Not charging":
                remaining_str = "Plugged in, not charging"
            else:
                remaining_str = status

            # Health
            health = 100.0
            if energy_full_design > 0:
                health = (energy_full / energy_full_design) * 100.0
                health = min(100.0, max(0.0, health))

            # Power profile
            profile = "Unknown"
            try:
                res = subprocess.run(["powerprofilesctl", "get"], capture_output=True, text=True)
                if res.returncode == 0:
                    profile = res.stdout.strip()
            except Exception:
                if os.path.exists("/sys/firmware/acpi/platform_profile"):
                    with open("/sys/firmware/acpi/platform_profile", "r") as f:
                        profile = f.readline().strip()

            return {
                "present": True,
                "percentage": pct,
                "status": status,
                "remaining": remaining_str,
                "health": round(health, 1),
                "profile": profile
            }
        except Exception:
            return {"present": False}


class ProcessCollector:
    def get_data(self):
        processes = []
        try:
            # Use ps to get processes. Extremely fast and lightweight!
            # Fields: pid, ppid, user, %cpu, %mem, comm
            res = subprocess.run([
                "ps", "-eo", "pid,user,%cpu,%mem,comm", "--no-headers"
            ], capture_output=True, text=True, check=True)
            
            lines = res.stdout.strip().split("\n")
            for line in lines:
                parts = line.split(None, 4)
                if len(parts) >= 5:
                    try:
                        pid = int(parts[0])
                        user = parts[1]
                        cpu = float(parts[2])
                        mem = float(parts[3])
                        name = parts[4].strip()
                        
                        processes.append({
                            "pid": pid,
                            "user": user,
                            "cpu": cpu,
                            "mem": mem,
                            "name": name
                        })
                    except ValueError:
                        continue
        except Exception:
            pass
        
        return {
            "processes": processes
        }


class ServiceCollector:
    def __init__(self):
        self.system_services = [
            "docker", "postgresql", "redis", "sshd", "bluetooth"
        ]
        self.user_services = []

    def get_data(self):
        services_status = {}
        
        # Check system services
        try:
            # Run a single systemctl show to get all status info at once
            cmd = ["systemctl", "show", "-p", "Id,ActiveState,SubState"] + self.system_services
            res = subprocess.run(cmd, capture_output=True, text=True, check=True)
            
            current_service = {}
            for line in res.stdout.split("\n"):
                if "=" in line:
                    k, v = line.split("=", 1)
                    current_service[k] = v
                elif not line.strip() and current_service:
                    # End of a service block
                    srv_id = current_service.get("Id")
                    if srv_id:
                        # Extract base name (e.g. docker.service -> docker)
                        name = srv_id.replace(".service", "")
                        services_status[name] = {
                            "active": current_service.get("ActiveState", "inactive"),
                            "sub": current_service.get("SubState", "dead"),
                            "is_user": False
                        }
                    current_service = {}
        except Exception:
            # Fallback one by one
            for s in self.system_services:
                services_status[s] = {"active": "unknown", "sub": "unknown", "is_user": False}

        # Check user services
        try:
            cmd = ["systemctl", "--user", "show", "-p", "Id,ActiveState,SubState"] + self.user_services
            res = subprocess.run(cmd, capture_output=True, text=True, check=True)
            
            current_service = {}
            for line in res.stdout.split("\n"):
                if "=" in line:
                    k, v = line.split("=", 1)
                    current_service[k] = v
                elif not line.strip() and current_service:
                    srv_id = current_service.get("Id")
                    if srv_id:
                        name = srv_id.replace(".service", "")
                        services_status[name] = {
                            "active": current_service.get("ActiveState", "inactive"),
                            "sub": current_service.get("SubState", "dead"),
                            "is_user": True
                        }
                    current_service = {}
        except Exception:
            for s in self.user_services:
                services_status[s] = {"active": "unknown", "sub": "unknown", "is_user": True}

        return {
            "services": services_status
        }


class LogCollector:
    def get_data(self):
        logs = []
        try:
            # Fetch latest 50 logs in JSON
            res = subprocess.run([
                "journalctl", "-n", "50", "--no-pager", "-o", "json"
            ], capture_output=True, text=True, check=True)
            
            for line in res.stdout.strip().split("\n"):
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    # Extract fields
                    usec = int(entry.get("__REALTIME_TIMESTAMP", 0))
                    timestamp = time.strftime("%H:%M:%S", time.localtime(usec / 1000000))
                    message = entry.get("MESSAGE", "")
                    process = entry.get("SYSLOG_IDENTIFIER") or entry.get("_COMM", "system")
                    priority = int(entry.get("PRIORITY", 5))
                    
                    logs.append({
                        "time": timestamp,
                        "process": process,
                        "message": message,
                        "priority": priority # 0-3: Error/Crit, 4: Warning, 5-7: Info/Debug
                    })
                except Exception:
                    continue
        except Exception:
            pass

        # Sort logs descending (newest first)
        logs.reverse()
        return {
            "logs": logs
        }


class UpdateCollector:
    def __init__(self):
        self.update_count = 0
        self.last_check = 0.0
        self._check_updates()

    def _check_updates(self):
        def worker():
            try:
                # checkupdates returns a list of pending updates
                res = subprocess.run(["checkupdates"], capture_output=True, text=True)
                if res.returncode == 0:
                    lines = res.stdout.strip().split("\n")
                    self.update_count = len([l for l in lines if l])
                elif res.returncode == 2: # No updates pending
                    self.update_count = 0
                else:
                    self.update_count = 0
            except Exception:
                self.update_count = 0

        threading.Thread(target=worker, daemon=True).start()

    def get_data(self):
        now = time.time()
        # Check every 30 minutes
        if now - self.last_check > 1800:
            self.last_check = now
            self._check_updates()
            
        return {
            "pending_updates": self.update_count
        }


class PortsCollector:
    def get_data(self):
        ports = []
        try:
            # Run ss -tuln (listening TCP/UDP)
            res = subprocess.run(["ss", "-tuln"], capture_output=True, text=True, check=True)
            lines = res.stdout.strip().split("\n")
            for line in lines[1:]: # Skip header
                parts = line.split()
                if len(parts) >= 5:
                    proto = parts[0].upper()
                    local_address = parts[4]
                    
                    # Split address and port
                    # Handle IPv6 [::]:port
                    if "]" in local_address:
                        port = local_address.split("]")[-1].replace(":", "")
                        addr = local_address.split("]")[0] + "]"
                    else:
                        addr_parts = local_address.split(":")
                        port = addr_parts[-1]
                        addr = ":".join(addr_parts[:-1])

                    # Only show unique ports
                    ports.append({
                        "protocol": proto,
                        "address": addr,
                        "port": port
                    })
        except Exception:
            pass

        # Deduplicate and sort by port
        unique_ports = []
        seen = set()
        for p in ports:
            key = (p["protocol"], p["port"])
            if key not in seen:
                seen.add(key)
                unique_ports.append(p)
        
        unique_ports.sort(key=lambda x: int(x["port"]) if x["port"].isdigit() else 99999)
        return {
            "listening_ports": unique_ports[:20] # Limit to top 20
        }
