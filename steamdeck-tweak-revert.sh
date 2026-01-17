#!/bin/bash
set -e

echo "=== Reverting SteamOS Tweaks and Restoring ZRAM (RAM/2) ==="

# 1. Re-enable ZRAM with requested size (zram/2)
ZRAM_CONF="/usr/lib/systemd/zram-generator.conf"
echo "[1/13] Restoring ZRAM configuration to RAM/2..."
sudo tee "$ZRAM_CONF" > /dev/null <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
# Restart ZRAM generator
sudo systemctl daemon-reload
sudo systemctl start /dev/zram0 || echo "Note: ZRAM will fully apply after reboot."

# 2. Disable and Remove ZSWAP Service
echo "[2/13] Removing zswap configuration service..."
sudo systemctl stop zswap-configure.service || true
sudo systemctl disable zswap-configure.service || true
sudo rm -f /etc/systemd/system/zswap-configure.service

# 3. Disable and Remove Swapfile
SWAPFILE="/home/swapfile2"
if [ -f "$SWAPFILE" ]; then
    echo "[3/13] Disabling and removing swapfile..."
    sudo swapoff "$SWAPFILE" || true
    sudo rm -f "$SWAPFILE"
fi

# 4. Remove Swapfile from fstab
echo "[4/13] Removing swapfile entry from /etc/fstab..."
sudo sed -i "\|$SWAPFILE|d" /etc/fstab

# 5. Remove swappiness override
echo "[5/13] Removing swappiness configuration..."
sudo rm -f /etc/sysctl.d/99-swappiness.conf

# 6. Disable and Remove CPU Performance Service
echo "[6/13] Removing CPU performance governor service..."
sudo systemctl stop cpu_performance.service || true
sudo systemctl disable cpu_performance.service || true
sudo rm -f /etc/systemd/system/cpu_performance.service

# 7. Remove MGLRU tweaks
echo "[7/13] Removing MGLRU configuration..."
sudo rm -f /etc/tmpfiles.d/mglru.conf

# 8. Remove memlock limits
echo "[8/13] Removing memlock limits..."
sudo rm -f /etc/security/limits.d/memlock.conf

# 9. Remove ntsync kernel module auto-load
echo "[9/13] Removing ntsync module configuration..."
sudo rm -f /etc/modules-load.d/ntsync.conf

# 10. Re-enable CPU security mitigations (if applied)
GRUB_FILE="/etc/default/grub"
if grep -q "mitigations=off" "$GRUB_FILE"; then
    echo "[10/13] Re-enabling CPU security mitigations in GRUB..."
    sudo sed -i 's/mitigations=off //' "$GRUB_FILE"
    sudo grub-mkconfig -o /boot/efi/EFI/steamos/grub.cfg || echo "Warning: grub-mkconfig failed."
fi

# 11. Final system reload
echo "[11/13] Reloading system settings..."
sudo systemctl daemon-reload
sudo systemctl daemon-reexec
sudo sysctl --system

# 12. Re-enable Read-only filesystem
echo "[12/13] Re-enabling SteamOS readonly mode..."
sudo steamos-readonly enable

echo "[13/13] Revert complete. Please reboot your Steam Deck to ensure all changes (especially ZRAM and GRUB) are active."
