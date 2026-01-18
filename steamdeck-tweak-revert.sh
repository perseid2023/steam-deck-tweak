#!/bin/bash
set -e

echo "=== Reverting SteamOS Performance Tweaks (Keeping zRAM) ==="

# 1. Disable and remove THP service
echo "[1/9] Reverting Transparent Huge Pages (THP) settings..."
sudo systemctl stop disable-thp.service || true
sudo systemctl disable disable-thp.service || true
sudo rm -f /etc/systemd/system/disable-thp.service

# 2. Revert CPU mitigations in GRUB
echo "[2/9] Reverting CPU security mitigations..."
GRUB_FILE="/etc/default/grub"
if grep -q "mitigations=off" "$GRUB_FILE"; then
    sudo sed -i 's/mitigations=off //' "$GRUB_FILE"
    sudo grub-mkconfig -o /boot/efi/EFI/steamos/grub.cfg || echo "Warning: grub-mkconfig failed."
else
    echo "No mitigation changes found in GRUB."
fi

# 3. Remove ntsync module load
echo "[3/9] Removing ntsync kernel module config..."
sudo rm -f /etc/modules-load.d/ntsync.conf

# 4. Remove memlock limits
echo "[4/9] Removing custom memlock limits..."
sudo rm -f /etc/security/limits.d/memlock.conf

# 5. Remove MGLRU config
echo "[5/9] Removing MGLRU configuration..."
sudo rm -f /etc/tmpfiles.d/mglru.conf

# 6. Disable and remove CPU performance service
echo "[6/9] Removing CPU performance governor service..."
sudo systemctl stop cpu_performance.service || true
sudo systemctl disable cpu_performance.service || true
sudo rm -f /etc/systemd/system/cpu_performance.service

# 7. Revert swappiness
echo "[7/9] Reverting swappiness to default (SteamOS default is usually 100)..."
sudo rm -f /etc/sysctl.d/99-swappiness.conf
sudo sysctl vm.swappiness=100 || true

# 8. Remove Swapfile and clean fstab
SWAPFILE="/home/swapfile2"
echo "[8/9] Removing 8GB swapfile..."
sudo swapoff "$SWAPFILE" || true
if [ -f "$SWAPFILE" ]; then
    sudo rm -f "$SWAPFILE"
fi
sudo sed -i "\|$SWAPFILE|d" /etc/fstab

# 9. Reload Systemd
echo "[9/9] Reloading system services..."
sudo systemctl daemon-reload
sudo systemctl daemon-reexec

# Re-enable readonly filesystem
echo "Re-enabling SteamOS readonly mode..."
sudo steamos-readonly enable

echo "=== Revert complete. Performance tweaks and swapfile removed. ==="
echo "=== zRAM configuration was left untouched. ==="
