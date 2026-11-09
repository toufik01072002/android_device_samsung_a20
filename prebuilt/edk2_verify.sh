#!/bin/sh
# EDK2 verification script for Samsung SM-A205W
# Validates EDK2 boot image on boot partition

BOOT_PARTITION="/dev/block/by-name/boot"
EXPECTED_KERNEL_MAGIC="ANDROID!"
MIN_KERNEL_SIZE=1048576   # 1 MiB
MAX_KERNEL_SIZE=16777216  # 16 MiB
EXPECTED_DEVICE="SM-A205W"
EXPECTED_SOC="Exynos7885"

log() {
    echo "[EDK2-VERIFY] $1" > /dev/kmsg
    echo "[EDK2-VERIFY] $1"
}

error() {
    log "ERROR: $1"
    exit 1
}

info() {
    log "INFO: $1"
}

# Check boot partition exists
if [ ! -b "$BOOT_PARTITION" ]; then
    error "Boot partition not found at $BOOT_PARTITION"
fi
info "Boot partition found: $BOOT_PARTITION"

# Read boot image header (first 2048 bytes)
HEADER=$(dd if="$BOOT_PARTITION" bs=2048 count=1 2>/dev/null | head -c 2048)
if [ ${#HEADER} -lt 2048 ]; then
    error "Failed to read boot image header"
fi

# Check Android boot magic
if [ "${HEADER:0:8}" != "$EXPECTED_KERNEL_MAGIC" ]; then
    error "Invalid boot image magic: expected '$EXPECTED_KERNEL_MAGIC', got '${HEADER:0:8}'"
fi
info "Android boot image magic verified"

# Extract kernel size (offset 0x10, 4 bytes, little-endian)
KERNEL_SIZE_HEX=$(echo -n "${HEADER:16:4}" | od -An -tx4 | tr -d ' \n')
KERNEL_SIZE=$((16#$KERNEL_SIZE_HEX))
info "Kernel size from header: $KERNEL_SIZE bytes (0x$(printf '%x' $KERNEL_SIZE))"

if [ $KERNEL_SIZE -lt $MIN_KERNEL_SIZE ] || [ $KERNEL_SIZE -gt $MAX_KERNEL_SIZE ]; then
    error "Kernel size $KERNEL_SIZE outside expected range [$MIN_KERNEL_SIZE, $MAX_KERNEL_SIZE]"
fi
info "Kernel size within expected range"

# Calculate SHA256 of kernel portion
KERNEL_OFFSET=2048  # page size
KERNEL_DATA=$(dd if="$BOOT_PARTITION" bs=1 skip=$KERNEL_OFFSET count=$KERNEL_SIZE 2>/dev/null)
KERNEL_SHA256=$(echo -n "$KERNEL_DATA" | sha256sum | cut -d' ' -f1)
info "Kernel SHA256: $KERNEL_SHA256"

# TODO: Compare against known good hash for SM-A205W EDK2
# For now, just verify it's not all zeros or all 0xFF
if [ "$KERNEL_SHA256" = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ]; then
    error "Kernel appears to be empty (all zeros)"
fi

# Verify device properties from recovery
if [ -f /system/build.prop ]; then
    DEVICE=$(grep "ro.product.device=" /system/build.prop | cut -d= -f2)
    if [ "$DEVICE" != "a20" ] && [ "$DEVICE" != "a205w" ]; then
        error "Device mismatch: expected a20/a205w, got $DEVICE"
    fi
    info "Device verified: $DEVICE"
fi

# Check EDK2 specific signature in kernel (BootShim + UEFI FD)
# BootShim is at offset 0 in kernel, UEFI FD follows
# Check for BootShim ARM64 magic at kernel offset 0x80 (after Linux header)
KERNEL_FIRST_PAGE=$(dd if="$BOOT_PARTITION" bs=1 skip=$KERNEL_OFFSET count=4096 2>/dev/null)
if echo -n "$KERNEL_FIRST_PAGE" | grep -q "ARM@64"; then
    info "BootShim ARM64 magic found in kernel"
else
    # Check at offset 0 of kernel (if no Linux header)
    if echo -n "$KERNEL_FIRST_PAGE" | dd bs=1 skip=128 count=8 2>/dev/null | grep -q "ARM@64"; then
        info "BootShim ARM64 magic found at offset 128"
    else
        error "BootShim ARM64 magic not found - not an EDK2 boot image"
    fi
fi

# Verify UEFI FD signature (PE/COFF)
UEFI_FD_OFFSET=$((KERNEL_OFFSET + KERNEL_SIZE - 2097152))  # 2 MiB from end (UEFI FD size)
if [ $UEFI_FD_OFFSET -gt $KERNEL_OFFSET ]; then
    UEFI_FD_DATA=$(dd if="$BOOT_PARTITION" bs=1 skip=$UEFI_FD_OFFSET count=2097152 2>/dev/null)
    if echo -n "$UEFI_FD_DATA" | dd bs=1 count=4 2>/dev/null | grep -q "MZ"; then
        info "UEFI FD PE/COFF signature (MZ) found"
    else
        # Check for FV signature
        if echo -n "$UEFI_FD_DATA" | grep -q "_FVH"; then
            info "UEFI Firmware Volume signature (_FVH) found"
        else
            error "UEFI FD signature not found"
        fi
    fi
fi

# All checks passed
info "EDK2 boot image validation PASSED"
echo "KERNEL_SIZE=$KERNEL_SIZE" > /tmp/edk2_verify_result
echo "KERNEL_SHA256=$KERNEL_SHA256" >> /tmp/edk2_verify_result
exit 0