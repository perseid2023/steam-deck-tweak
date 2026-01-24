#!/bin/bash
set -e

echo "=== Reverting SteamOS Tweaks & Reconfiguring ZRAM (ram/2) ==="

# 1. Re-enable readonly filesystem (Standard SteamOS state)
echo "[1/13] Re-enabling SteamOS readonly mode..."
sudo steamos-readonly enable

# 2. Reconfigure ZRAM to ram/2
ZRAM_CONF="/usr/lib/systemd/zram-generator.conf"
echo "[2/13] Setting ZRAM to ram/2..."
sudo tee "$ZRAM_CONF" > /dev/null <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
sudo systemctl daemon-reload
sudo systemctl restart /dev/zram0 || echo "Note: ZRAM will fully update on next reboot."

# 3. Disable and remove ZSWAP service
echo "[3/13] Removing ZSWAP configuration service..."
sudo systemctl stop zswap-configure.service || true
sudo systemctl disable zswap-configure.service || true
sudo rm -f /etc/systemd/system/zswap-configure.service

# 4. Disable and remove Swapfile
SWAPFILE="/home/swapfile2"
if [ -f "$SWAPFILE" ]; then
    echo "[4/13] Disabling and removing swapfile..."
    sudo swapoff "$SWAPFILE" || true
    sudo rm -f "$SWAPFILE"
fi

# 5. Remove swapfile from fstab
echo "[5/13] Removing swapfile entry from /etc/fstab..."
sudo sed -i "\|/home/swapfile2|d" /etc/fstab

# 6. Revert Swappiness (SteamOS default is usually 100 or 1, we will remove the override)
echo "[6/13] Removing swappiness override..."
sudo rm -f /etc/sysctl.d/99-swappiness.conf

# 7. Disable and remove CPU performance service
echo "[7/13] Removing CPU performance service..."
sudo systemctl stop cpu_performance.service || true
sudo systemctl disable cpu_performance.service || true
sudo rm -f /etc/systemd/system/cpu_performance.service

# 8. Remove MGLRU configuration
echo "[8/13] Removing MGLRU configuration..."
sudo rm -f /etc/tmpfiles.d/mglru.conf

# 9. Remove memlock limits
echo "[9/13] Removing memlock limits..."
sudo rm -f /etc/security/limits.d/memlock.conf

# 10. Disable ntsync module loading
echo "[10/13] Removing ntsync module config..."
sudo rm -f /etc/modules-load.d/ntsync.conf

# 11. Disable and remove THP disable service
echo "[11/13] Re-enabling Transparent Huge Pages (standard behavior)..."
sudo systemctl stop disable-thp.service || true
sudo systemctl disable disable-thp.service || true
sudo rm -f /etc/systemd/system/disable-thp.service

# 12. Re-enable CPU security mitigations (If they were disabled)
GRUB_FILE="/etc/default/grub"
if grep -q "mitigations=off" "$GRUB_FILE"; then
    echo "[12/13] Re-enabling CPU security mitigations..."
    sudo sed -i 's/mitigations=off //' "$GRUB_FILE"
    sudo grub-mkconfig -o /boot/efi/EFI/steamos/grub.cfg || echo "Warning: grub-mkconfig failed."
fi

# 13. Finalize
echo "[13/13] Reloading system settings..."
sudo systemctl daemon-reload
sudo systemctl daemon-reexec
sudo sysctl --system

echo "=== Revert complete. Please reboot your Steam Deck to ensure all changes take effect. ==="
