#!/bin/bash
set -e

echo "=== Reverting Performance Tweaks & Setting ZRAM to RAM/2 ==="

# 1. Disable readonly filesystem to allow cleanup
echo "[1/11] Disabling SteamOS readonly mode..."
sudo steamos-readonly disable

# 2. Update ZRAM instead of deleting (Set to RAM/2)
ZRAM_CONF="/usr/lib/systemd/zram-generator.conf"
echo "[2/11] Updating ZRAM configuration to RAM/2..."
sudo tee "$ZRAM_CONF" > /dev/null <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

# 3. Disable and remove ZSWAP service
echo "[3/11] Removing ZSWAP service..."
sudo systemctl stop zswap-configure.service || true
sudo systemctl disable zswap-configure.service || true
sudo rm -f /etc/systemd/system/zswap-configure.service

# 4. Remove custom Swapfile
SWAPFILE="/home/swapfile2"
if [ -f "$SWAPFILE" ]; then
    echo "[4/11] Removing 8GB swapfile..."
    sudo swapoff "$SWAPFILE" || true
    sudo rm -f "$SWAPFILE"
    sudo sed -i "\|$SWAPFILE|d" /etc/fstab
else
    echo "[4/11] Custom swapfile not found, skipping."
fi

# 5. Revert Swappiness (Back to default 60 or just remove custom file)
echo "[5/11] Removing custom swappiness config..."
sudo rm -f /etc/sysctl.d/99-swappiness.conf

# 6. Remove CPU Performance Governor service
echo "[6/11] Removing CPU performance service..."
sudo systemctl stop cpu_performance.service || true
sudo systemctl disable cpu_performance.service || true
sudo rm -f /etc/systemd/system/cpu_performance.service

# 7. Remove MGLRU config
echo "[7/11] Removing MGLRU configuration..."
sudo rm -f /etc/tmpfiles.d/mglru.conf

# 8. Remove memlock limits
echo "[8/11] Removing memlock limits..."
sudo rm -f /etc/security/limits.d/memlock.conf

# 9. Remove ntsync module load
echo "[9/11] Removing ntsync module configuration..."
sudo rm -f /etc/modules-load.d/ntsync.conf

# 10. Revert CPU security mitigations in GRUB
GRUB_FILE="/etc/default/grub"
if grep -q "mitigations=off" "$GRUB_FILE"; then
    echo "[10/11] Re-enabling CPU security mitigations..."
    sudo sed -i 's/mitigations=off //' "$GRUB_FILE"
    sudo grub-mkconfig -o /boot/efi/EFI/steamos/grub.cfg || echo "Warning: grub-mkconfig failed."
else
    echo "[10/11] No mitigation changes found in GRUB."
fi

# 11. Remove THP Disable Service
echo "[11/11] Removing THP disable service..."
sudo systemctl stop disable-thp.service || true
sudo systemctl disable disable-thp.service || true
sudo rm -f /etc/systemd/system/disable-thp.service

# Finalizing
echo "=== Cleanup complete ==="
sudo systemctl daemon-reload
sudo systemctl daemon-reexec
sudo sysctl --system

# Optional: Re-enable readonly
read -p "Would you like to re-enable SteamOS Read-only mode? [y/N]: " RE_ENABLE
if [[ "$RE_ENABLE" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo steamos-readonly enable
fi

echo "Revert finished. Please REBOOT to apply all changes (especially ZRAM and GRUB)."
