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

# Kexec ARM64 - Samsung Exynos 7885
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/prebuilt/kexec/exynos7885.dtb:recovery/root/system/etc/kexec/exynos7885.dtb \
    $(LOCAL_PATH)/prebuilt/kexec/kexec:recovery/root/system/bin/kexec

# Zinitix A20 touchscreen firmware
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/prebuilt/firmware/tsp_zinitix/zt7548_a20.fw:recovery/root/lib/firmware/tsp_zinitix/zt7548_a20.fw
