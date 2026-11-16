LOCAL_PATH := device/samsung/a20

# Fastbootd
PRODUCT_PACKAGES += \
	fastbootd \
	android.hardware.fastboot@1.0-impl-mock \
	android.hardware.fastboot@1.0-impl-mock.recovery

PRODUCT_PRODUCT_PROPERTIES += \
	ro.fastbootd.available=true

# 7K-EDK2-BUNDLE and its manifests (read-only validation from recovery)
PRODUCT_COPY_FILES += \
	$(LOCAL_PATH)/prebuilt/etc/edk2/UEFI:recovery/root/system/etc/edk2/UEFI \
	$(LOCAL_PATH)/prebuilt/etc/edk2/UEFI.manifest.json:recovery/root/system/etc/edk2/UEFI.manifest.json \
	$(LOCAL_PATH)/prebuilt/etc/edk2/UEFI.sec-manifest.json:recovery/root/system/etc/edk2/UEFI.sec-manifest.json \
	$(LOCAL_PATH)/prebuilt/etc/edk2/SHA256SUMS:recovery/root/system/etc/edk2/SHA256SUMS

# EDK2 bundle verification script
PRODUCT_COPY_FILES += \
	$(LOCAL_PATH)/prebuilt/edk2_verify.sh:recovery/root/system/bin/edk2_verify.sh

# Read-only command test harness for EDK2 / Virtual Boot interfaces
PRODUCT_COPY_FILES += \
	$(LOCAL_PATH)/prebuilt/edk2_command_test.sh:recovery/root/system/bin/edk2_command_test.sh

# Virtual Boot staging entry point (load-only; execution remains disabled).
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/prebuilt/virtual_boot_prepare.sh:recovery/root/system/bin/virtual_boot_prepare.sh

# Virtual Boot diagnostic Linux bundle built by the reusable EDK2 workflow.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/prebuilt/etc/virtual-boot/Image:recovery/root/system/etc/virtual-boot/Image \
    $(LOCAL_PATH)/prebuilt/etc/virtual-boot/exynos7885-a205w-virtual.dtb:recovery/root/system/etc/virtual-boot/exynos7885-a205w-virtual.dtb \
    $(LOCAL_PATH)/prebuilt/etc/virtual-boot/initramfs.cpio.gz:recovery/root/system/etc/virtual-boot/initramfs.cpio.gz \
    $(LOCAL_PATH)/prebuilt/etc/virtual-boot/hardware-manifest.json:recovery/root/system/etc/virtual-boot/hardware-manifest.json \
    $(LOCAL_PATH)/prebuilt/etc/virtual-boot/handoff-producer-report.json:recovery/root/system/etc/virtual-boot/handoff-producer-report.json \
    $(LOCAL_PATH)/prebuilt/etc/virtual-boot/SHA256SUMS:recovery/root/system/etc/virtual-boot/SHA256SUMS

# Kexec ARM64 - Samsung Exynos 7885
# Keep the Virtual Boot kernel separate from the build #31 TWRP kernel.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/prebuilt/kexec/Image:recovery/root/system/etc/kexec/Image \
    $(LOCAL_PATH)/prebuilt/kexec/exynos7885.dtb:recovery/root/system/etc/kexec/exynos7885.dtb \
    $(LOCAL_PATH)/prebuilt/kexec/kexec:recovery/root/system/bin/kexec

# Zinitix A20 touchscreen firmware
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/prebuilt/firmware/tsp_zinitix/zt7548_a20.fw:recovery/root/lib/firmware/tsp_zinitix/zt7548_a20.fw
