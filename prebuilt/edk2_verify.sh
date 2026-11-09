#!/bin/sh
# EDK2 verification script for Samsung SM-A205W
# Validates EDK2 boot image in recovery ramdisk (read-only)
# FAIL-CLOSED: Any failure results in non-zero exit
# Uses only POSIX shell features, dd, od, sha256sum

EDK2_IMAGE="/system/etc/edk2/boot.img"
EXPECTED_KERNEL_MAGIC="ANDROID!"
MIN_KERNEL_SIZE=1048576   # 1 MiB
MAX_KERNEL_SIZE=16777216  # 16 MiB

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

# Convert 4 little-endian bytes to decimal using POSIX arithmetic
# Input: reads 4 bytes from stdin (binary), outputs decimal
# Uses od -tu1 to get unsigned decimal bytes, no hex arithmetic
# Validates exactly 4 bytes are read, fails on truncated/invalid input
read_le32() {
    # Read raw bytes, convert to 4 unsigned decimal numbers
    output=$(od -An -tu1 2>/dev/null)
    if [ -z "$output" ]; then
        error "read_le32: no input received"
    fi
    # Normalize whitespace and extract first 4 numbers
    set -- $output
    if [ $# -lt 4 ]; then
        error "read_le32: expected 4 bytes, got $#"
    fi
    b0=$1
    b1=$2
    b2=$3
    b3=$4
    # Validate each byte is in range 0-255
    for byte in "$b0" "$b1" "$b2" "$b3"; do
        case $byte in
            ''|*[!0-9]*) error "read_le32: invalid byte value '$byte'";;
        esac
        if [ "$byte" -gt 255 ]; then
            error "read_le32: byte value out of range: $byte"
        fi
    done
    # Little-endian: b0 + b1*256 + b2*65536 + b3*16777216
    echo $((b0 + b1 * 256 + b2 * 65536 + b3 * 16777216))
}

# Check EDK2 image exists in recovery ramdisk
if [ ! -f "$EDK2_IMAGE" ]; then
    error "EDK2 image not found at $EDK2_IMAGE"
fi
info "EDK2 image found: $EDK2_IMAGE"

# Get file size
FILESIZE=$(stat -c%s "$EDK2_IMAGE" 2>/dev/null || wc -c < "$EDK2_IMAGE")
if [ "$FILESIZE" -eq 0 ]; then
    error "EDK2 image is empty"
fi
info "EDK2 image size: $FILESIZE bytes"

# Read Android boot header (first 2048 bytes minimum)
# Extract fields using dd and od, never store binary in variables

# Check Android boot magic at offset 0
MAGIC=$(dd if="$EDK2_IMAGE" bs=1 skip=0 count=8 2>/dev/null | od -An -tx1 | tr -d ' \n')
if [ "$MAGIC" != "414e44524f494421" ]; then
    error "Invalid boot image magic: expected 414e44524f494421 (ANDROID!), got $MAGIC"
fi
info "Android boot image magic verified"

# Read page_size from header at offset 0x24 (36), 4 bytes LE
PAGE_SIZE=$(dd if="$EDK2_IMAGE" bs=1 skip=36 count=4 2>/dev/null | read_le32)
if [ "$PAGE_SIZE" -ne 2048 ] && [ "$PAGE_SIZE" -ne 4096 ]; then
    error "Unsupported page_size: $PAGE_SIZE (expected 2048 or 4096)"
fi
info "Page size from header: $PAGE_SIZE"

# Read kernel_size from header at offset 0x08 (8), 4 bytes LE
KERNEL_SIZE=$(dd if="$EDK2_IMAGE" bs=1 skip=8 count=4 2>/dev/null | read_le32)
info "Kernel size from header (offset 0x08): $KERNEL_SIZE bytes (0x$(printf '%x' $KERNEL_SIZE))"

if [ "$KERNEL_SIZE" -lt "$MIN_KERNEL_SIZE" ] || [ "$KERNEL_SIZE" -gt "$MAX_KERNEL_SIZE" ]; then
    error "Kernel size $KERNEL_SIZE outside expected range [$MIN_KERNEL_SIZE, $MAX_KERNEL_SIZE]"
fi
info "Kernel size within expected range"

# Calculate kernel start offset
KERNEL_START=$PAGE_SIZE

# Verify file is large enough
MIN_FILE_SIZE=$((KERNEL_START + KERNEL_SIZE))
if [ "$FILESIZE" -lt "$MIN_FILE_SIZE" ]; then
    error "File too small: $FILESIZE bytes, need at least $MIN_FILE_SIZE bytes for kernel"
fi

# Calculate SHA256 of kernel portion using pipeline (no variable storage of binary)
KERNEL_SHA256=$(dd if="$EDK2_IMAGE" bs=1 skip=$KERNEL_START count=$KERNEL_SIZE 2>/dev/null | sha256sum | cut -d' ' -f1)
if [ -z "$KERNEL_SHA256" ]; then
    error "Failed to compute kernel SHA256"
fi
info "Kernel SHA256: $KERNEL_SHA256"

# Check BootShim ARM64 magic at kernel offset 0x38
# Read 4 bytes at kernel_start + 56
BOOTSHIM_MAGIC=$(dd if="$EDK2_IMAGE" bs=1 skip=$((KERNEL_START + 56)) count=4 2>/dev/null | od -An -tx1 | tr -d ' \n')
if [ "$BOOTSHIM_MAGIC" = "41524d64" ]; then
    info "BootShim ARM64 magic found at kernel offset 0x38"
else
    # Also check at kernel offset 0
    BOOTSHIM_MAGIC_0=$(dd if="$EDK2_IMAGE" bs=1 skip=$KERNEL_START count=4 2>/dev/null | od -An -tx1 | tr -d ' \n')
    if [ "$BOOTSHIM_MAGIC_0" = "41524d64" ]; then
        info "BootShim ARM64 magic found at kernel offset 0"
    else
        error "BootShim ARM64 magic not found (expected 41524d64 at kernel+0x38, got $BOOTSHIM_MAGIC; at kernel+0x00: $BOOTSHIM_MAGIC_0)"
    fi
fi

# Search for UEFI FD signature (_FVH) in kernel region after header
# Search from kernel_start + 0x100 to kernel_start + kernel_size
UEFI_SEARCH_START=$((KERNEL_START + 256))
UEFI_SEARCH_SIZE=$((KERNEL_SIZE - 256))
if [ "$UEFI_SEARCH_SIZE" -le 0 ]; then
    error "Kernel too small for UEFI FD search"
fi

# Use dd + grep on binary stream to find _FVH
if dd if="$EDK2_IMAGE" bs=1 skip=$UEFI_SEARCH_START count=$UEFI_SEARCH_SIZE 2>/dev/null | grep -q "_FVH"; then
    info "UEFI Firmware Volume signature (_FVH) found"
else
    error "UEFI FD signature (_FVH) not found in kernel region"
fi

# All checks passed
info "EDK2 boot image validation PASSED"
echo "KERNEL_SIZE=$KERNEL_SIZE" > /tmp/edk2_verify_result
echo "KERNEL_SHA256=$KERNEL_SHA256" >> /tmp/edk2_verify_result
exit 0