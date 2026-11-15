#!/system/bin/sh
# Stage the SM-A205W Virtual Boot kernel in RAM only.
# This script deliberately never executes kexec or reboots the device.
set -eu

LOG=/tmp/virtual_boot_prepare.log
exec >"$LOG" 2>&1

ROOT=/system/etc/virtual-boot
KEXEC=/system/bin/kexec
IMAGE="$ROOT/Image"
DTB="$ROOT/exynos7885-a205w-virtual.dtb"
INITRD="$ROOT/initramfs.cpio.gz"

echo "[Virtual Boot] Starting read-only bundle validation"

for file in "$IMAGE" "$DTB" "$INITRD" "$ROOT/hardware-manifest.json" "$ROOT/SHA256SUMS"; do
    if [ ! -s "$file" ]; then
        echo "ERROR: required file missing or empty: $file"
        exit 1
    fi
done

if [ ! -x "$KEXEC" ]; then
    echo "ERROR: kexec binary is missing or not executable: $KEXEC"
    exit 1
fi

grep -q 'Samsung SM-A205W / Exynos 7885' "$ROOT/hardware-manifest.json" || {
    echo "ERROR: hardware manifest does not target SM-A205W / Exynos 7885"
    exit 1
}

(
    cd "$ROOT"
    sha256sum -c SHA256SUMS
)

echo "[Virtual Boot] Bundle hashes verified"
echo "[Virtual Boot] Requesting load-only kexec staging"

# -l only loads the next kernel into RAM. No -e, reboot, or partition writes.
"$KEXEC" -l "$IMAGE" \
    --dtb="$DTB" \
    --initrd="$INITRD" \
    --command-line="rdinit=/init loglevel=7"

echo "VIRTUAL_BOOT_STAGED=1"
echo "Virtual Boot kernel, DTB and initramfs staged in RAM."
echo "Execution intentionally remains disabled."
