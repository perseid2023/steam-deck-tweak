#!/bin/bash
set -e

echo "=== SteamOS Revert Script (ZRAM half RAM) ==="

# 1. Ensure readonly is disabled (needed to modify system files)
echo "[1/11] Ensuring SteamOS readonly mode is disabled..."
sudo steamos-readonly disable

# 2. Set ZRAM to half of RAM
ZRAM_CONF="/usr/lib/systemd/zram-generator.conf"
echo "[2/11] Setting ZRAM size to half of RAM..."
sudo tee "$ZRAM_CONF" > /dev/null <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

# 3. Disable and remove swapfile
SWAPFILE="/home/swapfile2"
echo "[3/11] Removing swapfile..."

sudo swapoff "$SWAPFILE" 2>/dev/null || true
sudo rm -f "$SWAPFILE"
sudo sed -i "\|$SWAPFILE|d" /etc/fstab

# 4. Remove swappiness override
echo "[4/11] Removing swappiness override..."
sudo rm -f /etc/sysctl.d/99-swappiness.conf

# 5. Disable and remove CPU performance governor service
echo "[5/11] Removing CPU performance governor service..."
sudo systemctl disable cpu_performance.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/cpu_performance.service

# 6. Remove MGLRU configuration
echo "[6/11] Removing MGLRU configuration..."
sudo rm -f /etc/tmpfiles.d/mglru.conf

# 7. Remove memlock limits
echo "[7/11] Removing memlock limits..."
sudo rm -f /etc/security/limits.d/memlock.conf

# 8. Remove ntsync autoload
echo "[8/11] Removing ntsync module autoload..."
sudo rm -f /etc/modules-load.d/ntsync.conf

# 9. Optional: Restore CPU security mitigations
echo
echo "[9/11] OPTIONAL: Restore CPU security mitigations"
read -r -p "Remove mitigations=off from GRUB? [y/N]: " REVERT_MITIGATIONS

if [[ "$REVERT_MITIGATIONS" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Restoring default mitigations..."
    sudo sed -i 's/mitigations=off //' /etc/default/grub
    sudo grub-mkconfig -o /boot/efi/EFI/steamos/grub.cfg
else
    echo "Leaving GRUB mitigations unchanged."
fi

# 10. Reload services and sysctl
echo "[10/11] Reloading system services..."
sudo systemctl daemon-reload
sudo systemctl daemon-reexec
sudo sysctl --system
sudo systemctl restart systemd-zram-setup@zram0 || true

# 11. Show final status
echo "[11/11] Final memory & swap status:"
swapon --show
free -h

echo
echo "=== Revert complete. Reboot recommended. ==="
