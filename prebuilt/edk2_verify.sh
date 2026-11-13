#!/bin/sh
# Read-only validation of the 7K-EDK2-BUNDLE in the SM-A205W recovery ramdisk.
# Fail closed. This script never writes to boot, recovery, or vbmeta.

EDK2_DIR="/system/etc/edk2"
BUNDLE="$EDK2_DIR/UEFI"
EXPECTED_BUNDLE_SIZE=2228224

log() { echo "[EDK2-VERIFY] $1" > /dev/kmsg; echo "[EDK2-VERIFY] $1"; }
error() { log "ERROR: $1"; exit 1; }
info() { log "INFO: $1"; }

for file in UEFI UEFI.manifest.json UEFI.sec-manifest.json SHA256SUMS; do
    [ -s "$EDK2_DIR/$file" ] || error "Required bundle file missing or empty: $file"
done

cd "$EDK2_DIR" || error "Cannot enter EDK2 bundle directory"
info "Checking artifact SHA256SUMS"
sha256sum -c SHA256SUMS >/dev/null 2>&1 || error "Artifact checksum verification failed"

FILESIZE=$(wc -c < "$BUNDLE" | tr -d ' ')
[ "$FILESIZE" -eq "$EXPECTED_BUNDLE_SIZE" ] || error "Unexpected bundle size: $FILESIZE (expected $EXPECTED_BUNDLE_SIZE)"
info "Bundle size verified: $FILESIZE bytes"

grep -Eq '"format"[[:space:]]*:[[:space:]]*"7K-EDK2-BUNDLE"' UEFI.manifest.json || error "Unknown bundle format"
grep -Eq '"format_version"[[:space:]]*:[[:space:]]*1' UEFI.manifest.json || error "Unsupported bundle format version"
grep -Eq '"architecture"[[:space:]]*:[[:space:]]*"AARCH64"' UEFI.manifest.json || error "Bundle architecture is not AARCH64"
grep -Eq '"size"[[:space:]]*:[[:space:]]*65536' UEFI.manifest.json || error "BootShim size is not 64 KiB"
grep -Eq '"offset"[[:space:]]*:[[:space:]]*65536' UEFI.manifest.json || error "Firmware offset is not 0x10000"
grep -Eq '"padded_size"[[:space:]]*:[[:space:]]*2097152' UEFI.manifest.json || error "Firmware padded size is not 2 MiB"
grep -Eq '"copy_size"[[:space:]]*:[[:space:]]*2097152' UEFI.manifest.json || error "Firmware copy size is not 2 MiB"
grep -Eq '"load_address"[[:space:]]*:[[:space:]]*"0x90000000"' UEFI.manifest.json || error "Unexpected firmware load address"
info "Bundle layout manifest verified"

grep -Eq '"format"[[:space:]]*:[[:space:]]*"7K-EDK2-BUNDLE-SEC-MANIFEST"' UEFI.sec-manifest.json || error "SEC manifest format mismatch"
grep -Eq '"handoff_enabled"[[:space:]]*:[[:space:]]*false' UEFI.sec-manifest.json || error "Unsafe manifest: handoff must remain disabled"
grep -Eq '"base"[[:space:]]*:[[:space:]]*"0x90000000"' UEFI.sec-manifest.json || error "SEC manifest FD base mismatch"
grep -Eq '"bundle_offset"[[:space:]]*:[[:space:]]*65536' UEFI.sec-manifest.json || error "SEC manifest bundle offset mismatch"
grep -Eq '"sec_entry"' UEFI.sec-manifest.json || error "SEC entry metadata missing"
info "Static SEC metadata verified; runtime handoff remains disabled"

if ! dd if="$BUNDLE" bs=1 skip=65536 count=2097152 2>/dev/null | grep -a -q "_FVH"; then
    error "UEFI firmware volume signature not found in FD region"
fi
info "UEFI firmware volume signature found"

BUNDLE_SHA256=$(sha256sum UEFI | cut -d' ' -f1)
[ -n "$BUNDLE_SHA256" ] || error "Unable to calculate bundle SHA256"
# Compatibility keys consumed by the existing TWRP GUI action.
echo "KERNEL_SIZE=$FILESIZE" > /tmp/edk2_verify_result
echo "KERNEL_SHA256=$BUNDLE_SHA256" >> /tmp/edk2_verify_result
info "7K-EDK2-BUNDLE validation PASSED"
exit 0
