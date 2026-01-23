#!/bin/bash
set -e

echo "=== SteamOS ZRAM (disabled) + ZSWAP + Swapfile + Performance Tweaks Setup ==="

# 1. Disable readonly filesystem
echo "[1/15] Disabling SteamOS readonly mode..."
sudo steamos-readonly disable

# 2. Configure zram-generator (DISABLE ZRAM)
ZRAM_CONF="/usr/lib/systemd/zram-generator.conf"
echo "[2/15] Writing zram-generator configuration (zram disabled)..."
sudo tee "$ZRAM_CONF" > /dev/null <<EOF
[zram0]
zram-size = 0
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

# 3. Enable ZSWAP (Using Systemd Service for Persistence)
echo "[3/15] Configuring zswap via systemd service..."
ZSWAP_SERVICE="/etc/systemd/system/zswap-configure.service"
sudo tee "$ZSWAP_SERVICE" > /dev/null <<EOF
[Unit]
Description=Configure zswap parameters at boot
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/bash -c 'echo zstd > /sys/module/zswap/parameters/compressor'
ExecStart=/usr/bin/bash -c 'echo zsmalloc > /sys/module/zswap/parameters/zpool'
ExecStart=/usr/bin/bash -c 'echo 25 > /sys/module/zswap/parameters/max_pool_percent'
ExecStart=/usr/bin/bash -c 'echo 1 > /sys/module/zswap/parameters/enabled'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable zswap-configure.service
sudo systemctl start zswap-configure.service

# 4. Create swapfile
SWAPFILE="/home/swapfile2"
if [ ! -f "$SWAPFILE" ]; then
    echo "[4/15] Creating 8GB swapfile..."
    sudo dd if=/dev/zero of="$SWAPFILE" bs=1G count=8 status=progress
    sudo chmod 600 "$SWAPFILE"
    sudo mkswap "$SWAPFILE"
else
    echo "[4/15] Swapfile already exists, skipping creation."
fi

# 5. Enable swapfile
echo "[5/15] Enabling swapfile..."
sudo swapon "$SWAPFILE" || true

# 6. Make swapfile persistent
FSTAB_LINE="$SWAPFILE none swap sw 0 0"
if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo "[6/15] Adding swapfile to /etc/fstab..."
    echo "$FSTAB_LINE" | sudo tee -a /etc/fstab > /dev/null
else
    echo "[6/15] Swapfile already in /etc/fstab."
fi

# 7. Configure swappiness
SYSCTL_CONF="/etc/sysctl.d/99-swappiness.conf"
echo "[7/15] Setting vm.swappiness=10..."
sudo tee "$SYSCTL_CONF" > /dev/null <<EOF
vm.swappiness=10
EOF

# 8. CPU performance governor service
echo "[8/15] Creating CPU performance governor service..."
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
echo "[9/15] Enabling CPU performance service..."
sudo systemctl daemon-reload
sudo systemctl enable cpu_performance.service

# 10. Configure MGLRU
echo "[10/15] Configuring MGLRU..."
sudo tee /etc/tmpfiles.d/mglru.conf > /dev/null <<EOF
w /sys/kernel/mm/lru_gen/enabled - - - - 7
w /sys/kernel/mm/lru_gen/min_ttl_ms - - - - 0
EOF

# 11. Configure memlock limits
echo "[11/15] Configuring memlock limits..."
sudo tee /etc/security/limits.d/memlock.conf > /dev/null <<EOF
* hard memlock 2147484
* soft memlock 2147484
EOF

# 12. Enable ntsync kernel module
echo "[12/15] Enabling ntsync kernel module..."
echo ntsync | sudo tee /etc/modules-load.d/ntsync.conf > /dev/null

# 13. Disable Transparent Huge Pages (THP)
echo "[13/15] Configuring service to disable Transparent Huge Pages (THP)..."
THP_SERVICE="/etc/systemd/system/disable-thp.service"
sudo tee "$THP_SERVICE" > /dev/null <<EOF
[Unit]
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysfsutils.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'
ExecStart=/bin/sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/defrag'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable disable-thp.service
sudo systemctl start disable-thp.service

# 14. Disable CPU security mitigations
echo
echo "[14/15] OPTIONAL: Disable CPU security mitigations"
read -r -p "Disable mitigations (mitigations=off)? [y/N]: " MITIGATIONS_CHOICE
if [[ "$MITIGATIONS_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    GRUB_FILE="/etc/default/grub"
    if ! grep -q "mitigations=off" "$GRUB_FILE"; then
        echo "Applying mitigations=off to GRUB..."
        sudo sed -i 's/\bGRUB_CMDLINE_LINUX_DEFAULT="/&mitigations=off /' "$GRUB_FILE"
        sudo grub-mkconfig -o /boot/efi/EFI/steamos/grub.cfg || echo "Warning: grub-mkconfig failed."
    fi
fi

# 15. Reload and Status
echo "[15/15] Reloading services..."
sudo systemctl daemon-reexec
sudo sysctl --system

echo "=== Setup complete. ==="
