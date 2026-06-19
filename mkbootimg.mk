#
# Copyright (C) 2026 gbralisson
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/radxa/rock5bplus
KERNEL_PATH := device/radxa/rock5bplus-kernel

ROCK5BPLUS_BOOT_OUT := $(PRODUCT_OUT)/rock5bplusboot
# INSTALLED_KERNEL_TARGET is populated via PRODUCT_COPY_FILES in device.mk.
# Depend on it here so the kernel is present before the boot staging dir is built.
$(ROCK5BPLUS_BOOT_OUT): $(INSTALLED_RAMDISK_TARGET) $(INSTALLED_KERNEL_TARGET)
	mkdir -p $(ROCK5BPLUS_BOOT_OUT)
	cp $(KERNEL_PATH)/Image $(ROCK5BPLUS_BOOT_OUT)
	# Rock 5B+ uses RK3588 (not RK3588S) — place the correct DTB here once obtained.
	# Obtain from: https://github.com/radxa (see android_device_radxa_rock5bplus-kernel)
	# or build from kernel DTS: arch/arm64/boot/dts/rockchip/rk3588-rock-5b-plus.dts
	cp $(KERNEL_PATH)/rk3588-rock-5b-plus.dtb $(ROCK5BPLUS_BOOT_OUT)
	cp $(KERNEL_PATH)/android-sdcard.dtbo $(ROCK5BPLUS_BOOT_OUT)
	cp $(KERNEL_PATH)/boot.scr $(ROCK5BPLUS_BOOT_OUT)
	cp $(KERNEL_PATH)/uRamdisk $(ROCK5BPLUS_BOOT_OUT)
	cp $(KERNEL_PATH)/uRecovery $(ROCK5BPLUS_BOOT_OUT)
	cp $(PRODUCT_OUT)/ramdisk.img $(ROCK5BPLUS_BOOT_OUT)
	cp $(KERNEL_PATH)/config.txt $(ROCK5BPLUS_BOOT_OUT)

$(INSTALLED_BOOTIMAGE_TARGET): $(ROCK5BPLUS_BOOT_OUT)
	$(call pretty,"Target boot image: $@")

	BOOT_SIZE_BYTES=`du -s -k $(ROCK5BPLUS_BOOT_OUT) | awk '{ print $$1 * 1024 }'`; \
	PADDED_BYTES=`expr $$BOOT_SIZE_BYTES + 10485760`; \
	BLOCKS=`expr $$PADDED_BYTES / 512`; \
	echo "Creating boot image with $$BLOCKS blocks..."; \
	dd if=/dev/zero of=$@ bs=512 count=$$BLOCKS; \
	mkfs.fat -F 32 -n "boot" $@; \
	mcopy -s -i $@ $(ROCK5BPLUS_BOOT_OUT)/* ::
