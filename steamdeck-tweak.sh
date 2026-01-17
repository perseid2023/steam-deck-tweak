#!/bin/bash
set -e

echo "=== SteamOS ZRAM (disabled) + ZSWAP + Swapfile + Performance Tweaks Setup ==="

# 1. Disable readonly filesystem
echo "[1/14] Disabling SteamOS readonly mode..."
sudo steamos-readonly disable

# 2. Configure zram-generator (DISABLE ZRAM)
ZRAM_CONF="/usr/lib/systemd/zram-generator.conf"
echo "[2/14] Writing zram-generator configuration (zram disabled)..."
sudo tee "$ZRAM_CONF" > /dev/null <<EOF
[zram0]
zram-size = 0
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

# 3. Enable ZSWAP (Using tmpfiles.d instead of GRUB)
echo "[3/14] Configuring zswap via tmpfiles.d (SteamOS persistent method)..."
ZSWAP_TMP_CONF="/etc/tmpfiles.d/zswap.conf"
sudo tee "$ZSWAP_TMP_CONF" > /dev/null <<EOF
# Setting zswap parameters at boot (SteamOS Compatible)
w /sys/module/zswap/parameters/enabled - - - - 1
w /sys/module/zswap/parameters/compressor - - - - zstd
w /sys/module/zswap/parameters/zpool - - - - zsmalloc
w /sys/module/zswap/parameters/max_pool_percent - - - - 25
EOF

# Apply zswap settings immediately
sudo systemd-tmpfiles --create "$ZSWAP_TMP_CONF"

# 4. Create swapfile
SWAPFILE="/home/swapfile2"
if [ ! -f "$SWAPFILE" ]; then
    echo "[4/14] Creating 8GB swapfile..."
    sudo dd if=/dev/zero of="$SWAPFILE" bs=1G count=8 status=progress
    sudo chmod 600 "$SWAPFILE"
    sudo mkswap "$SWAPFILE"
else
    echo "[4/14] Swapfile already exists, skipping creation."
fi

# 5. Enable swapfile
echo "[5/14] Enabling swapfile..."
sudo swapon "$SWAPFILE" || true

# 6. Make swapfile persistent
FSTAB_LINE="$SWAPFILE none swap sw 0 0"
if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo "[6/14] Adding swapfile to /etc/fstab..."
    echo "$FSTAB_LINE" | sudo tee -a /etc/fstab > /dev/null
else
    echo "[6/14] Swapfile already in /etc/fstab."
fi

# 7. Configure swappiness
SYSCTL_CONF="/etc/sysctl.d/99-swappiness.conf"
echo "[7/14] Setting vm.swappiness=10..."
sudo tee "$SYSCTL_CONF" > /dev/null <<EOF
vm.swappiness=10
EOF

# 8. CPU performance governor service
echo "[8/14] Creating CPU performance governor service..."
sudo tee /etc/systemd/system/cpu_performance.service > /dev/null <<EOF
[Unit]
Description=CPU performance governor
[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g performance
[Install]
WantedBy=multi-user.target
EOF

# 9. Enable CPU performance service
echo "[9/14] Enabling CPU performance service..."
sudo systemctl daemon-reload
sudo systemctl enable cpu_performance.service

# 10. Configure MGLRU
echo "[10/14] Configuring MGLRU..."
sudo tee /etc/tmpfiles.d/mglru.conf > /dev/null <<EOF
w /sys/kernel/mm/lru_gen/enabled - - - - 7
w /sys/kernel/mm/lru_gen/min_ttl_ms - - - - 0
EOF

# 11. Configure memlock limits
echo "[11/14] Configuring memlock limits..."
sudo tee /etc/security/limits.d/memlock.conf > /dev/null <<EOF
* hard memlock 2147484
* soft memlock 2147484
EOF

# 12. Enable ntsync kernel module
echo "[12/14] Enabling ntsync kernel module..."
echo ntsync | sudo tee /etc/modules-load.d/ntsync.conf > /dev/null

# 13. Disable CPU security mitigations (Note: This still requires a bootloader)
echo
echo "[13/14] OPTIONAL: Disable CPU security mitigations"
echo "NOTE: This remains in /etc/default/grub as there is no other way to set it."
read -r -p "Disable mitigations (mitigations=off)? [y/N]: " MITIGATIONS_CHOICE

if [[ "$MITIGATIONS_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    GRUB_FILE="/etc/default/grub"
    if ! grep -q "mitigations=off" "$GRUB_FILE"; then
        echo "Applying mitigations=off to GRUB..."
        sudo sed -i 's/\bGRUB_CMDLINE_LINUX_DEFAULT="/&mitigations=off /' "$GRUB_FILE"
        sudo grub-mkconfig -o /boot/efi/EFI/steamos/grub.cfg || echo "Warning: grub-mkconfig failed, but zswap will still work via tmpfiles."
    else
        echo "mitigations=off already present in GRUB config."
    fi
fi

# 14. Reload and Status
echo "[14/14] Reloading services..."
sudo systemctl daemon-reexec
sudo sysctl --system

echo "=== Setup complete. ==="
echo "Zswap status:"
grep -r . /sys/module/zswap/parameters/enabled /sys/module/zswap/parameters/compressor /sys/module/zswap/parameters/zpool
