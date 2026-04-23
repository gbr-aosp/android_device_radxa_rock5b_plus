#
# Copyright (C) 2026 gbralisson
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit everything from opi5_pro and override board-specific bits below.
include device/opi/opi5_pro/BoardConfig.mk

DEVICE_PATH := device/radxa/rock5bplus
KERNEL_PATH := device/radxa/rock5bplus-kernel

# Custom boot image assembly (rock5bplus DTBs + U-Boot)
BOARD_CUSTOM_BOOTIMG_MK := $(DEVICE_PATH)/mkbootimg.mk

# androidboot.hardware tag used by init and sepolicy
BOARD_KERNEL_CMDLINE := console=ttyS2,1500000 no_console_suspend root=/dev/ram0 rootwait androidboot.hardware=rock5bplus
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive

# VINTF manifests
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE := $(DEVICE_PATH)/framework_compatibility_matrix.xml
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml
PRODUCT_MANIFEST_FILES := $(DEVICE_PATH)/product_manifest.xml

# Partition sizes
BOARD_FLASH_BLOCK_SIZE := 4096
BOARD_USES_METADATA_PARTITION := true
BOARD_BOOTIMAGE_PARTITION_SIZE := 134217728 # 128M
BOARD_METADATAIMAGE_PARTITION_SIZE := 16777216 # 16M
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 3221225472 # 3072M
BOARD_USERDATAIMAGE_PARTITION_SIZE := 134217728 # 128M
BOARD_VENDORIMAGE_PARTITION_SIZE := 402653184 # 384M
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_USERIMAGES_SPARSE_EXT_DISABLED := true
TARGET_USERIMAGES_USE_EXT4 := true

# Sepolicy
BOARD_SEPOLICY_DIRS += device/radxa/rock5bplus/sepolicy

# Vendor properties — append so opi5_pro/vendor.prop base is preserved
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop
