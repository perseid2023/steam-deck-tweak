#!/bin/bash
set -e

echo "=== Reverting SteamOS Tweaks & Reconfiguring ZRAM (ram/2) ==="

# 1. Reconfigure ZRAM to ram/2
ZRAM_CONF="/usr/lib/systemd/zram-generator.conf"
echo "[1/11] Setting ZRAM to ram/2..."
sudo tee "$ZRAM_CONF" > /dev/null <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
sudo systemctl daemon-reload
sudo systemctl restart /dev/zram0 || echo "Note: ZRAM will fully update on next reboot."

# 2. Disable and remove ZSWAP service
echo "[2/11] Removing ZSWAP configuration service..."
sudo systemctl stop zswap-configure.service || true
sudo systemctl disable zswap-configure.service || true
sudo rm -f /etc/systemd/system/zswap-configure.service

# 3. Disable and remove Swapfile
SWAPFILE="/home/swapfile2"
if [ -f "$SWAPFILE" ]; then
    echo "[3/11] Disabling and removing swapfile..."
    sudo swapoff "$SWAPFILE" || true
    sudo rm -f "$SWAPFILE"
fi

# 4. Remove swapfile from fstab
echo "[4/11] Removing swapfile entry from /etc/fstab..."
sudo sed -i "\|/home/swapfile2|d" /etc/fstab

# 5. Revert Swappiness
echo "[5/11] Removing swappiness override..."
sudo rm -f /etc/sysctl.d/99-swappiness.conf

# 6. Remove MGLRU configuration
echo "[6/11] Removing MGLRU configuration..."
sudo rm -f /etc/tmpfiles.d/mglru.conf

# 7. Remove memlock limits
echo "[7/11] Removing memlock limits..."
sudo rm -f /etc/security/limits.d/memlock.conf

# 8. Disable ntsync module loading
echo "[8/11] Removing ntsync module config..."
sudo rm -f /etc/modules-load.d/ntsync.conf

# 9. Disable and remove THP disable service
echo "[9/11] Re-enabling Transparent Huge Pages (standard behavior)..."
sudo systemctl stop disable-thp.service || true
sudo systemctl disable disable-thp.service || true
sudo rm -f /etc/systemd/system/disable-thp.service

# 10. Re-enable CPU security mitigations (If they were disabled)
GRUB_FILE="/etc/default/grub"
if grep -q "mitigations=off" "$GRUB_FILE"; then
    echo "[10/11] Re-enabling CPU security mitigations..."
    sudo sed -i 's/mitigations=off //' "$GRUB_FILE"
    sudo grub-mkconfig -o /boot/efi/EFI/steamos/grub.cfg || echo "Warning: grub-mkconfig failed."
fi

# 11. Finalize and Re-enable readonly filesystem
echo "[11/11] Finalizing and re-enabling SteamOS readonly mode..."
sudo systemctl daemon-reload
sudo systemctl daemon-reexec
sudo sysctl --system
sudo steamos-readonly enable

echo "=== Revert complete. Please reboot your Steam Deck to ensure all changes take effect. ==="
