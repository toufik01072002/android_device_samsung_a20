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
	$(LOCAL_PATH)/prebuilt/edk2_uefi:recovery/root/system/bin/edk2_uefi

# EDK2 verification script
PRODUCT_COPY_FILES += \
	$(LOCAL_PATH)/prebuilt/edk2_verify.sh:recovery/root/system/bin/edk2_verify.sh
