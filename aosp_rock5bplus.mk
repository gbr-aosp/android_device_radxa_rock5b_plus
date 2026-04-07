#
# Copyright (C) 2026 gbralisson
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit device configuration
$(call inherit-product, device/radxa/rock5bplus/device.mk)

PRODUCT_AAPT_CONFIG := normal mdpi hdpi
PRODUCT_AAPT_PREF_CONFIG := hdpi
PRODUCT_CHARACTERISTICS := tablet,nosdcard

$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call enforce-product-packages-exist,com.android.ranging)

# Overlays
PRODUCT_PACKAGES += \
    AndroidOpiOverlay \
    SettingsProviderOpiOverlay \
    BluetoothOpiOverlay \
    SettingsOpiOverlay \
    WifiOpiOverlay \
    SystemUIOpiOverlay 

# Freeform windows
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.software.freeform_window_management.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.freeform_window_management.xml

# Permissions
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/tablet_core_hardware.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/tablet_core_hardware.xml

# Device identifier. This must come after all inclusions.
PRODUCT_DEVICE := rock5bplus
PRODUCT_NAME := aosp_rock5bplus
PRODUCT_BRAND := Radxa
PRODUCT_MODEL := Rock 5B+
PRODUCT_MANUFACTURER := Radxa
