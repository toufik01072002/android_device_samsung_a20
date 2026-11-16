#!/system/bin/sh
# Read-only command test harness for the SM-A205W TWRP / EDK2 integration.
# It validates the existing GUI back-end and Virtual Boot bundle only.
# It NEVER invokes kexec -l, kexec -e, reboot, or writes a partition.
set -u

MODE="${1:-full}"
LOG="/tmp/edk2_command_test.log"
EDK2_VERIFY="/system/bin/edk2_verify.sh"
VB_PREPARE="/system/bin/virtual_boot_prepare.sh"
RESULT="/tmp/edk2_verify_result"
VB_LOG="/tmp/virtual_boot_prepare.log"

exec >"$LOG" 2>&1

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; exit 1; }

require_file() {
    [ -s "$1" ] || fail "Missing or empty file: $1"
}

check_entrypoints() {
    require_file "$EDK2_VERIFY"
    require_file "$VB_PREPARE"
    sh -n "$EDK2_VERIFY" || fail "EDK2 verifier syntax error"
    sh -n "$VB_PREPARE" || fail "Virtual Boot preparation syntax error"
    pass "TWRP command entry points and shell syntax"
}

run_edk2_preflight() {
    rm -f "$RESULT"
    sh "$EDK2_VERIFY" || fail "EDK2 / Virtual Boot preflight failed"
    require_file "$RESULT"
    grep -qx 'VIRTUAL_BOOT_PREFLIGHT=PASS' "$RESULT" ||
        fail "Virtual Boot preflight result missing"
    grep -q '^KERNEL_SHA256=' "$RESULT" ||
        fail "EDK2 bundle SHA256 result missing"
    grep -q '^VIRTUAL_BOOT_KERNEL_SHA256=' "$RESULT" ||
        fail "Virtual Boot kernel SHA256 result missing"
    grep -q '^VIRTUAL_BOOT_DTB_SHA256=' "$RESULT" ||
        fail "Virtual Boot DTB SHA256 result missing"
    pass "EDK2 bundle, BootShim metadata, and Virtual Boot preflight"
}

run_virtual_boot_staging() {
    sh "$VB_PREPARE" || fail "Virtual Boot read-only staging validation failed"
    require_file "$VB_LOG"
    grep -qx 'VIRTUAL_BOOT_READY=1' "$VB_LOG" ||
        fail "Virtual Boot READY marker missing"
    grep -qx 'VIRTUAL_BOOT_KEXEC_LOAD=BLOCKED' "$VB_LOG" ||
        fail "KEXEC load gate is not confirmed BLOCKED"
    grep -qx 'VIRTUAL_BOOT_HANDOFF=DISABLED' "$VB_LOG" ||
        fail "UEFI handoff gate is not confirmed DISABLED"
    pass "Virtual Boot bundle staging validation (no kernel load or handoff)"
}

echo "===== SM-A205W EDK2 COMMAND TEST ====="
echo "MODE=$MODE"
echo "DATE=$(date 2>/dev/null || echo unknown)"
echo "SAFETY=READ_ONLY_NO_PARTITION_WRITES"

case "$MODE" in
    interfaces)
        check_entrypoints
        run_edk2_preflight
        echo "GUI_TOUCH_TEST=MANUAL_REQUIRED"
        echo "NOTE=This mode validates the GUI command back-end, not screen rendering or touch input."
        ;;
    virtualboot)
        check_entrypoints
        run_edk2_preflight
        run_virtual_boot_staging
        ;;
    bootshim)
        check_entrypoints
        run_edk2_preflight
        echo "BOOTSHIM_CHECK=STATIC_METADATA_ONLY"
        echo "BOOTSHIM_EXECUTION=NOT_ATTEMPTED"
        ;;
    full)
        check_entrypoints
        run_edk2_preflight
        run_virtual_boot_staging
        echo "GUI_TOUCH_TEST=MANUAL_REQUIRED"
        echo "BOOTSHIM_EXECUTION=NOT_ATTEMPTED"
        ;;
    *)
        echo "Usage: sh /system/bin/edk2_command_test.sh [interfaces|virtualboot|bootshim|full]"
        fail "Unknown test mode: $MODE"
        ;;
esac

echo "RESULT=PASS"
echo "LOG=$LOG"
exit 0
