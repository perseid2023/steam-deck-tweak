#!/bin/bash
set -e

echo "=== Reverting Tweaks & Restoring ZRAM (RAM/2) ==="

# 1. Restore ZRAM-Generator to 50% of RAM
ZRAM_CONF="/usr/lib/systemd/zram-generator.conf"
echo "[1/10] Restoring ZRAM to 50% of total RAM..."
sudo tee "$ZRAM_CONF" > /dev/null <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

# 2. Disable ZSWAP (Delete the tmpfiles config and turn off)
echo "[2/10] Disabling ZSWAP tweaks..."
sudo rm -f /etc/tmpfiles.d/zswap.conf
echo 0 | sudo tee /sys/module/zswap/parameters/enabled > /dev/null

# 3. Remove Swapfile
SWAPFILE="/home/swapfile2"
if [ -f "$SWAPFILE" ]; then
    echo "[3/10] Disabling and removing swapfile ($SWAPFILE)..."
    sudo swapoff "$SWAPFILE" || true
    sudo rm -f "$SWAPFILE"
    # Remove specifically the line matching our swapfile from fstab
    sudo sed -i "\|$SWAPFILE|d" /etc/fstab
else
    echo "[3/10] No swapfile found to remove."
fi

# 4. Remove Swappiness tweak
echo "[4/10] Removing swappiness configuration..."
sudo rm -f /etc/sysctl.d/99-swappiness.conf

# 5. Disable and Remove CPU Performance Service
echo "[5/10] Removing CPU performance service..."
sudo systemctl disable cpu_performance.service --now || true
sudo rm -f /etc/systemd/system/cpu_performance.service

# 6. Remove MGLRU tweak
echo "[6/10] Removing MGLRU configuration..."
sudo rm -f /etc/tmpfiles.d/mglru.conf

# 7. Remove Memlock limits
echo "[7/10] Removing memlock limits..."
sudo rm -f /etc/security/limits.d/memlock.conf

# 8. Remove ntsync module load
echo "[8/10] Removing ntsync configuration..."
sudo rm -f /etc/modules-load.d/ntsync.conf

# 9. Clean up GRUB (Remove all instances of mitigations=off)
echo "[9/10] Cleaning up /etc/default/grub..."
GRUB_FILE="/etc/default/grub"
if [ -f "$GRUB_FILE" ]; then
    # This removes all occurrences of mitigations=off and cleans up double spaces
    sudo sed -i 's/mitigations=off//g' "$GRUB_FILE"
    sudo sed -i 's/  / /g' "$GRUB_FILE"
    sudo grub-mkconfig -o /boot/efi/EFI/steamos/grub.cfg || true
fi

# 10. Reload systemd and restart ZRAM
echo "[10/10] Reloading systemd and starting ZRAM..."
sudo systemctl daemon-reload
sudo systemctl daemon-reexec
# This forces the generator to run and create the zram0 device
sudo systemctl stop systemd-zram-setup@zram0 || true
sudo systemctl start systemd-zram-setup@zram0 || true

echo "=== Revert Complete. Reboot is recommended. ==="
echo "Final Swap Status:"
swapon --show
