#!/bin/bash
set -e

echo "=== Reverting Tweaks & Re-configuring ZRAM (RAM/2) ==="

# 1. Re-enable readonly filesystem (Optional, but returns to SteamOS default)
echo "[1/11] Enabling SteamOS readonly mode..."
sudo steamos-readonly enable || true

# 2. Re-configure ZRAM (Set to RAM / 2)
ZRAM_CONF="/usr/lib/systemd/zram-generator.conf"
echo "[2/11] Setting ZRAM to RAM / 2..."
sudo tee "$ZRAM_CONF" > /dev/null <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
# Restart zram-generator
sudo systemctl daemon-reload
sudo systemctl restart /dev/zram0 || echo "ZRAM will refresh on next reboot."

# 3. Disable and Remove ZSWAP Service
echo "[3/11] Removing zswap configuration service..."
ZSWAP_SERVICE="/etc/systemd/system/zswap-configure.service"
sudo systemctl stop zswap-configure.service || true
sudo systemctl disable zswap-configure.service || true
sudo rm -f "$ZSWAP_SERVICE"

# 4. Remove Swapfile
SWAPFILE="/home/swapfile2"
if [ -f "$SWAPFILE" ]; then
    echo "[4/11] Disabling and removing 8GB swapfile..."
    sudo swapoff "$SWAPFILE" || true
    sudo rm -f "$SWAPFILE"
fi

# 5. Remove Swapfile from fstab
echo "[5/11] Removing swapfile entry from /etc/fstab..."
sudo sed -i "\|$SWAPFILE|d" /etc/fstab

# 6. Revert Swappiness
echo "[6/11] Removing custom swappiness..."
sudo rm -f /etc/sysctl.d/99-swappiness.conf
sudo sysctl vm.swappiness=60 # SteamOS default is usually higher than 10

# 7. Remove CPU Performance Service
echo "[7/11] Removing CPU performance service..."
sudo systemctl stop cpu_performance.service || true
sudo systemctl disable cpu_performance.service || true
sudo rm -f /etc/systemd/system/cpu_performance.service

# 8. Remove MGLRU Tweaks
echo "[8/11] Removing MGLRU configuration..."
sudo rm -f /etc/tmpfiles.d/mglru.conf

# 9. Remove Memlock Limits
echo "[9/11] Removing memlock limits..."
sudo rm -f /etc/security/limits.d/memlock.conf

# 10. Remove ntsync module loading
echo "[10/11] Removing ntsync module config..."
sudo rm -f /etc/modules-load.d/ntsync.conf

# 11. Revert CPU Security Mitigations (If applied)
GRUB_FILE="/etc/default/grub"
if grep -q "mitigations=off" "$GRUB_FILE"; then
    echo "[11/11] Re-enabling CPU security mitigations..."
    sudo sed -i 's/mitigations=off //' "$GRUB_FILE"
    sudo grub-mkconfig -o /boot/efi/EFI/steamos/grub.cfg || echo "Warning: grub-mkconfig failed."
else
    echo "[11/11] No mitigation changes detected in GRUB."
fi

echo "=== Revert complete. Please reboot to ensure all changes (especially ZRAM) take effect. ==="
