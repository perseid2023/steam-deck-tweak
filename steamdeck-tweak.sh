#!/bin/bash
set -e

echo "=== SteamOS ZRAM + Swapfile + Performance Tweaks Setup ==="

# 1. Disable readonly filesystem
echo "[1/11] Disabling SteamOS readonly mode..."
sudo steamos-readonly disable

# 2. Configure zram-generator
ZRAM_CONF="/usr/lib/systemd/zram-generator.conf"
echo "[2/11] Writing zram-generator configuration..."
sudo tee "$ZRAM_CONF" > /dev/null <<EOF
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

# 3. Create swapfile
SWAPFILE="/home/swapfile2"

if [ ! -f "$SWAPFILE" ]; then
    echo "[3/11] Creating 8GB swapfile..."
    sudo dd if=/dev/zero of="$SWAPFILE" bs=1G count=8 status=progress
    sudo chmod 600 "$SWAPFILE"
    sudo mkswap "$SWAPFILE"
else
    echo "[3/11] Swapfile already exists, skipping creation."
fi

# 4. Enable swapfile
echo "[4/11] Enabling swapfile..."
sudo swapon "$SWAPFILE" || true

# 5. Make swapfile persistent
FSTAB_LINE="$SWAPFILE none swap sw 0 0"

if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo "[5/11] Adding swapfile to /etc/fstab..."
    echo "$FSTAB_LINE" | sudo tee -a /etc/fstab > /dev/null
else
    echo "[5/11] Swapfile already in /etc/fstab."
fi

# 6. Configure swappiness
SYSCTL_CONF="/etc/sysctl.d/99-swappiness.conf"
echo "[6/11] Setting vm.swappiness=200..."
sudo tee "$SYSCTL_CONF" > /dev/null <<EOF
vm.swappiness=200
EOF

# 7. CPU performance governor systemd service
echo "[7/11] Creating CPU performance governor service..."
sudo tee /etc/systemd/system/cpu_performance.service > /dev/null <<EOF
[Unit]
Description=CPU performance governor

[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g performance

[Install]
WantedBy=multi-user.target
EOF

# 8. Enable CPU performance service
echo "[8/11] Enabling CPU performance service..."
sudo systemctl daemon-reload
sudo systemctl enable cpu_performance.service

# 9. Configure MGLRU (Multi-Gen LRU)
echo "[9/11] Configuring MGLRU..."
sudo tee /etc/tmpfiles.d/mglru.conf > /dev/null <<EOF
w /sys/kernel/mm/lru_gen/enabled - - - - 7
w /sys/kernel/mm/lru_gen/min_ttl_ms - - - - 0
EOF

# 10. Configure memlock limits
echo "[10/11] Configuring memlock limits..."
sudo tee /etc/security/limits.d/memlock.conf > /dev/null <<EOF
* hard memlock 2147484
* soft memlock 2147484
EOF

# 11. Reload systemd + sysctl and show status
echo "[11/11] Reloading services and showing final status..."
sudo systemctl daemon-reexec
sudo systemctl restart systemd-zram-setup@zram0 || true
sudo sysctl --system

echo
echo "Final swap status:"
swapon --show
free -h

echo "=== Setup complete. Reboot recommended. ==="
