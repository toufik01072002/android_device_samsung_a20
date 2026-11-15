#!/system/bin/sh
# Validate the SM-A205W Virtual Boot bundle without loading or executing it.
# The current memory map and handoff are unvalidated; KEXEC loading stays blocked.
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

echo "[Virtual Boot] Bundle hashes and hardware manifest verified"
echo "[Virtual Boot] KEXEC load is blocked until memory-map and handoff gates are validated."

# Do not invoke kexec -l, kexec -e, reboot, or write any partition.
echo "VIRTUAL_BOOT_READY=1"
echo "VIRTUAL_BOOT_KEXEC_LOAD=BLOCKED"
echo "VIRTUAL_BOOT_HANDOFF=DISABLED"
