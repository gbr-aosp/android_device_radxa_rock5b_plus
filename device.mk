#
# Copyright (C) 2026 gbralisson
#
# SPDX-License-Identifier: Apache-2.0
#

ROCK5BPLUS_PATH := device/radxa/rock5bplus

# Kernel - add BEFORE inherit so this entry wins the PRODUCT_COPY_FILES dedup
# over the opi5_pro entry (inheriting product's direct entries come first).
PRODUCT_COPY_FILES += \
    device/radxa/rock5bplus-kernel/Image:kernel

# Inherit everything from opi5_pro
$(call inherit-product, device/opi/opi5_pro/device.mk)

# Remove inherited opi5_pro entries that rock5bplus overrides to avoid duplicate destinations
PRODUCT_COPY_FILES := $(filter-out device/opi/opi5_pro-kernel/%,$(PRODUCT_COPY_FILES))
PRODUCT_COPY_FILES := $(filter-out device/opi/opi5_pro/ramdisk/ueventd.opi5.rc:%,$(PRODUCT_COPY_FILES))

# Override product namespace so Soong resolves this device path too
PRODUCT_SOONG_NAMESPACES += device/radxa/rock5bplus

# Bring-up kernels may not map to framework kernel FCM tables.
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false

# Ramdisk - override opi5 entries with rock5bplus-specific files
PRODUCT_COPY_FILES += \
    $(ROCK5BPLUS_PATH)/ramdisk/fstab.rock5bplus:$(TARGET_COPY_OUT_RAMDISK)/fstab.rock5bplus \
    $(ROCK5BPLUS_PATH)/ramdisk/fstab.rock5bplus:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.rock5bplus \
    $(ROCK5BPLUS_PATH)/ramdisk/init.rock5bplus.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.rock5bplus.rc \
    $(ROCK5BPLUS_PATH)/ramdisk/init.rock5bplus.usb.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.rock5bplus.usb.rc \
    $(ROCK5BPLUS_PATH)/ramdisk/ueventd.rock5bplus.rc:$(TARGET_COPY_OUT_VENDOR)/etc/ueventd.rc
