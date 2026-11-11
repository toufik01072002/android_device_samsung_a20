LOCAL_PATH := device/samsung/a20

# Fastbootd
PRODUCT_PACKAGES += \
	fastbootd \
	android.hardware.fastboot@1.0-impl-mock \
	android.hardware.fastboot@1.0-impl-mock.recovery

PRODUCT_PRODUCT_PROPERTIES += \
	ro.fastbootd.available=true

# EDK2/UEFI boot image - copy to recovery ramdisk for validation
PRODUCT_COPY_FILES += \
	$(LOCAL_PATH)/prebuilt/etc/edk2/boot.img:recovery/root/system/etc/edk2/boot.img

# EDK2 verification script
PRODUCT_COPY_FILES += \
	$(LOCAL_PATH)/prebuilt/edk2_verify.sh:recovery/root/system/bin/edk2_verify.sh

# Kexec ARM64 - Samsung Exynos 7885
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/prebuilt/kexec/exynos7885.dtb:recovery/root/system/etc/kexec/exynos7885.dtb \
    $(LOCAL_PATH)/prebuilt/kexec/kexec:recovery/root/system/bin/kexec
