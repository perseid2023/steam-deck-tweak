#!/bin/bash
set -e

echo "=== SteamOS ZRAM + Performance Tweaks Setup ==="

# 1. Disable readonly filesystem
echo "[1/11] Disabling SteamOS readonly mode..."
sudo steamos-readonly disable

# 2. Disable and Remove ZSWAP Service
echo "[2/11] Removing zswap configuration service..."
ZSWAP_SERVICE="/etc/systemd/system/zswap-configure.service"
sudo systemctl stop zswap-configure.service || true
sudo systemctl disable zswap-configure.service || true
sudo rm -f "$ZSWAP_SERVICE"

# 3. Configure zram-generator
ZRAM_CONF="/usr/lib/systemd/zram-generator.conf"
echo "[3/11] Writing zram-generator configuration..."
sudo tee "$ZRAM_CONF" > /dev/null <<EOF
[zram0]
zram-size = 8000
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

# 4. Create swapfile
SWAPFILE="/home/swapfile2"
if [ ! -f "$SWAPFILE" ]; then
    echo "[4/12] Creating 8GB swapfile..."

    # Try fallocate first (fast, no I/O)
    if sudo fallocate -l 8G "$SWAPFILE"; then
        echo "[4/12] Swapfile created with fallocate."
    else
        echo "[4/12] fallocate failed, falling back to dd..."
        sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count=8192 status=progress
    fi

    sudo chmod 600 "$SWAPFILE"
    sudo mkswap "$SWAPFILE"
else
    echo "[4/12] Swapfile already exists, skipping creation."
fi

# 5. Enable swapfile
echo "[5/11] Enabling swapfile..."
sudo swapon "$SWAPFILE" || true

# 6. Make swapfile persistent
FSTAB_LINE="$SWAPFILE none swap sw 0 0"
if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo "[6/11] Adding swapfile to /etc/fstab..."
    echo "$FSTAB_LINE" | sudo tee -a /etc/fstab > /dev/null
else
    echo "[6/11] Swapfile already in /etc/fstab."
fi

# 7. Configure swappiness
SYSCTL_CONF="/etc/sysctl.d/99-swappiness.conf"
echo "[7/11] Setting vm.swappiness=50..."
sudo tee "$SYSCTL_CONF" > /dev/null <<EOF
vm.swappiness=50
EOF

# 8. Configure MGLRU
echo "[8/11] Configuring MGLRU..."
sudo tee /etc/tmpfiles.d/mglru.conf > /dev/null <<EOF
w /sys/kernel/mm/lru_gen/enabled - - - - 7
w /sys/kernel/mm/lru_gen/min_ttl_ms - - - - 0
EOF

# 9. Configure memlock limits
echo "[9/11] Configuring memlock limits..."
sudo tee /etc/security/limits.d/memlock.conf > /dev/null <<EOF
* hard memlock 2147484
* soft memlock 2147484
EOF

# 10. Enable ntsync kernel module
echo "[10/11] Enabling ntsync kernel module..."
echo ntsync | sudo tee /etc/modules-load.d/ntsync.conf > /dev/null

# 11. Disable CPU security mitigations
echo "[11/11] OPTIONAL: Disable CPU security mitigations"
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

# 12. Disable Transparent Huge Pages (THP)
echo "[12/12] Configuring service to disable Transparent Huge Pages (THP)..."
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

# Final Reload and Status
echo "Reloading services and checking status..."
sudo systemctl daemon-reexec
sudo sysctl --system

echo "=== Setup complete. ==="
echo "THP status:"
cat /sys/kernel/mm/transparent_hugepage/enabled
