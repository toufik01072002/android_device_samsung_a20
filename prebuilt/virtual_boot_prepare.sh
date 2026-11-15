#!/system/bin/sh
# Stage the SM-A205W Virtual Boot kernel in RAM only.
# This script loads the next kernel into RAM only; it never executes that kernel or reboots.
set -eu

LOG=/tmp/virtual_boot_prepare.log
exec >"$LOG" 2>&1

ROOT=/system/etc/virtual-boot
KEXEC=/system/bin/kexec
IMAGE="$ROOT/Image"
DTB="$ROOT/exynos7885-a205w-virtual.dtb"
INITRD="$ROOT/initramfs.cpio.gz"
MANIFEST="$ROOT/hardware-manifest.json"
PROVENANCE="$ROOT/handoff-producer-report.json"

echo "[Virtual Boot] Starting read-only bundle validation"

for file in "$IMAGE" "$DTB" "$INITRD" "$MANIFEST" "$PROVENANCE" "$ROOT/SHA256SUMS"; do
    if [ ! -s "$file" ]; then
        echo "ERROR: required file missing or empty: $file"
        exit 1
    fi
done

if [ ! -x "$KEXEC" ]; then
    echo "ERROR: kexec binary is missing or not executable: $KEXEC"
    exit 1
fi

grep -q 'Samsung SM-A205W / Exynos 7885' "$MANIFEST" || {
    echo "ERROR: hardware manifest does not target SM-A205W / Exynos 7885"
    exit 1
}

grep -Eq '"architecture"[[:space:]]*:[[:space:]]*"AARCH64"' "$MANIFEST" || {
    echo "ERROR: Virtual Boot manifest architecture is not AARCH64"
    exit 1
}
grep -Eq '"state"[[:space:]]*:[[:space:]]*"DISABLED"' "$MANIFEST" || {
    echo "ERROR: handoff state must remain DISABLED"
    exit 1
}
grep -Fq 'CONFIGURATION_CANDIDATES_ONLY_NOT_RUNTIME_RESERVATIONS' "$MANIFEST" || {
    echo "ERROR: physical addresses are not marked as unverified"
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
