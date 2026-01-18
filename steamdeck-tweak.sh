#!/bin/bash
set -e

echo "=== SteamOS ZRAM + Performance Tweaks Setup ==="

# 1. Disable readonly filesystem
echo "[1/11] Disabling SteamOS readonly mode..."
sudo steamos-readonly disable

# 2. Configure zram-generator
ZRAM_CONF="/usr/lib/systemd/zram-generator.conf"
echo "[2/11] Writing zram-generator configuration..."
sudo tee "$ZRAM_CONF" > /dev/null <<EOF
[zram0]
zram-size = ram*2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

# 3. Configure swappiness
SYSCTL_CONF="/etc/sysctl.d/99-swappiness.conf"
echo "[3/11] Setting vm.swappiness=1..."
sudo tee "$SYSCTL_CONF" > /dev/null <<EOF
vm.swappiness=1
EOF

# 4. CPU performance governor service
echo "[4/11] Creating CPU performance governor service..."
sudo tee /etc/systemd/system/cpu_performance.service > /dev/null <<EOF
[Unit]
Description=CPU performance governor
[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g performance
[Install]
WantedBy=multi-user.target
EOF

# 5. Enable CPU performance service
echo "[5/11] Enabling CPU performance service..."
sudo systemctl daemon-reload
sudo systemctl enable cpu_performance.service

# 6. Configure MGLRU
echo "[6/11] Configuring MGLRU..."
sudo tee /etc/tmpfiles.d/mglru.conf > /dev/null <<EOF
w /sys/kernel/mm/lru_gen/enabled - - - - 7
w /sys/kernel/mm/lru_gen/min_ttl_ms - - - - 0
EOF

# 7. Configure memlock limits
echo "[7/11] Configuring memlock limits..."
sudo tee /etc/security/limits.d/memlock.conf > /dev/null <<EOF
* hard memlock 2147484
* soft memlock 2147484
EOF

# 8. Enable ntsync kernel module
echo "[8/11] Enabling ntsync kernel module..."
echo ntsync | sudo tee /etc/modules-load.d/ntsync.conf > /dev/null

# 9. Disable CPU security mitigations
echo "[9/11] OPTIONAL: Disable CPU security mitigations"
read -r -p "Disable mitigations (mitigations=off)? [y/N]: " MITIGATIONS_CHOICE

if [[ "$MITIGATIONS_CHOICE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    GRUB_FILE="/etc/default/grub"
    if ! grep -q "mitigations=off" "$GRUB_FILE"; then
        echo "Applying mitigations=off to GRUB..."
        sudo sed -i 's/\bGRUB_CMDLINE_LINUX_DEFAULT="/&mitigations=off /' "$GRUB_FILE"
        sudo grub-mkconfig -o /boot/efi/EFI/steamos/grub.cfg || echo "Warning: grub-mkconfig failed."
    else
        echo "mitigations=off already present in GRUB config."
    fi
fi

# 10. Disable Transparent Huge Pages (THP)
echo "[10/11] Configuring service to disable Transparent Huge Pages (THP)..."
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

sudo systemctl daemon-reload
sudo systemctl enable disable-thp.service
sudo systemctl start disable-thp.service

# 11. Reload and Status
echo "[11/11] Reloading services..."
sudo systemctl daemon-reexec
sudo sysctl --system

echo "=== Setup complete. ==="
echo "THP status:"
cat /sys/kernel/mm/transparent_hugepage/enabled
