#
# Copyright (C) 2026 gbralisson
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit everything from opi5_pro
$(call inherit-product, device/opi/opi5_pro/device.mk)

# Override product namespace so Soong resolves this device path too
PRODUCT_SOONG_NAMESPACES += device/radxa/rock5bplus

# Bring-up kernels may not map to framework kernel FCM tables.
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false
