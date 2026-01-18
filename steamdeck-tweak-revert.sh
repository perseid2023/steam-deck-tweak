#!/bin/bash
set -e

echo "=== Reverting Performance Tweaks & Reconfiguring zRAM ==="

# 1. Re-enable readonly filesystem (Standard SteamOS behavior)
echo "[1/10] Enabling SteamOS readonly mode..."
sudo steamos-readonly enable

# 2. Reconfigure zram-generator to RAM/2
ZRAM_CONF="/usr/lib/systemd/zram-generator.conf"
echo "[2/10] Adjusting zram-generator to ram/2..."
sudo steamos-readonly disable # Need to disable briefly to edit /usr
sudo tee "$ZRAM_CONF" > /dev/null <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
sudo steamos-readonly enable

# 3. Restore Default Swappiness
# Removing the custom conf file returns it to the system default (usually 60)
echo "[3/10] Removing custom swappiness configuration..."
sudo rm -f /etc/sysctl.d/99-swappiness.conf

# 4. Remove CPU performance service
echo "[4/10] Disabling and removing CPU performance service..."
sudo systemctl disable cpu_performance.service || true
sudo rm -f /etc/systemd/system/cpu_performance.service

# 5. Remove MGLRU configuration
echo "[5/10] Removing MGLRU tweaks..."
sudo rm -f /etc/tmpfiles.d/mglru.conf

# 6. Remove memlock limits
echo "[6/10] Removing custom memlock limits..."
sudo rm -f /etc/security/limits.d/memlock.conf

# 7. Disable ntsync module loading
echo "[7/10] Removing ntsync from auto-load..."
sudo rm -f /etc/modules-load.d/ntsync.conf

# 8. Re-enable CPU security mitigations (If they were disabled)
echo "[8/10] Re-enabling CPU security mitigations..."
GRUB_FILE="/etc/default/grub"
if grep -q "mitigations=off" "$GRUB_FILE"; then
    sudo sed -i 's/mitigations=off //' "$GRUB_FILE"
    sudo grub-mkconfig -o /boot/efi/EFI/steamos/grub.cfg || echo "Warning: grub-mkconfig failed."
fi

# 9. Re-enable Transparent Huge Pages (THP)
echo "[9/10] Removing service to disable THP (Restoring default)..."
sudo systemctl stop disable-thp.service || true
sudo systemctl disable disable-thp.service || true
sudo rm -f /etc/systemd/system/disable-thp.service

# 10. Reload and Apply
echo "[10/10] Reloading system configuration..."
sudo systemctl daemon-reload
sudo sysctl --system

echo "=== Revert complete. Please reboot your Steam Deck for all changes to take effect. ==="
