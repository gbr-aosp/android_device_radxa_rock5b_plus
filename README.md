# AOSP for Radxa Rock 5B+

This repository contains the AOSP build configuration and image creation tooling for the
**Radxa Rock 5B+** (RK3588 SoC). The script `rock5bplus-mkimg.sh` assembles a single
flashable GPT disk image from the AOSP build outputs plus pre-built U-Boot artifacts.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| AOSP build environment | Standard AOSP dependencies (Python 3, OpenJDK, etc.) |
| `lunch aosp_rock5bplus-...` already run | Sets `TARGET_PRODUCT` and `ANDROID_PRODUCT_OUT` |
| `make bootimage systemimage vendorimage` completed | Produces `boot.img`, `system.img`, `vendor.img` in `$ANDROID_PRODUCT_OUT` |
| Host packages | `kpartx`, `sfdisk`, `sgdisk`, `e2fsprogs` (`mkfs.ext4`, `e2label`), `mtools` (`mcopy`, `mkfs.fat`), `dosfstools`, `sudo` |
| U-Boot artifacts | Either `u-boot-rockchip.bin` (combined) **or** both `idbloader.img` + `u-boot.itb` in `device/radxa/rock5bplus-kernel/` |
| Free disk space | At least **20 GiB** in `$ANDROID_PRODUCT_OUT` |

---

## Disk layout

The output image is **19 456 MiB** (~19 GiB). This is the size of the final GPT image
written to an NVMe, eMMC, or SD card.

```
Offset (LBA)   Partition   Size     Type         Contents
─────────────────────────────────────────────────────────────────────
0 – 63         (raw)        32 KiB  —            GPT header (written by sfdisk)
64             (raw)        —       —            U-Boot idbloader (first-stage loader)
16384          (raw)        —       —            U-Boot ITB (split mode only)
32768 – 294911 boot (p1)   128 MiB  FAT32        Kernel Image, DTB, boot scripts, ramdisk
303104 – ...   system (p2)  3072 MiB EXT4        Android system partition
6596608 – ...  vendor (p3)  384 MiB  EXT4        Board-specific HALs and firmware
7385088 – ...  metadata (p4) 16 MiB  EXT4        Dynamic partition / A-B metadata (blank)
7417856 – end  userdata (p5) ~12 GiB EXT4        User data (formatted blank, grows to fill)
```

> The partition sizes match the values declared in `device/radxa/rock5bplus/BoardConfig.mk`
> (`BOARD_BOOTIMAGE_PARTITION_SIZE`, `BOARD_SYSTEMIMAGE_PARTITION_SIZE`, etc.).

---

## How `rock5bplus-mkimg.sh` works — step by step

### 1. Strict error handling

```bash
set -euo pipefail
IFS=$'\n\t'
```

- `set -e` aborts on any non-zero exit code.
- `set -u` treats unset variables as errors.
- `set -o pipefail` propagates failures through pipes.
- `IFS=$'\n\t'` prevents word-splitting on spaces (avoids bugs with paths containing spaces).

---

### 2. Cleanup trap

```bash
cleanup() {
  if [ -n "${LOOPDEV:-}" ]; then
    sudo kpartx -d "${IMAGE_PATH}" || true
  fi
}
trap cleanup EXIT
```

Registered with `trap ... EXIT` so it fires on both normal exit and errors. It
calls `kpartx -d` to unmap any loop/device-mapper entries that were created,
preventing stale mappings from being left on the host.

---

### 3. Environment variable checks

```bash
: "${TARGET_PRODUCT:?...}"
: "${ANDROID_PRODUCT_OUT:?...}"
```

The `:` (no-op) command combined with the `?` modifier causes an immediate exit
with a human-readable message if either variable is unset. Both are populated by
AOSP's `envsetup.sh` / `lunch`.

---

### 4. Verify required build outputs

```bash
for PART in boot system vendor; do
  if [ ! -f "${ANDROID_PRODUCT_OUT}/${PART}.img" ]; then
    exit_with_error "..."
  fi
done
```

Confirms that `boot.img`, `system.img`, and `vendor.img` exist before doing any
destructive work. `metadata.img` and `userdata.img` are **not** required here
because the script creates them from scratch (see step 11).

---

### 5. U-Boot artifact detection

The script supports two U-Boot packaging styles used by different Rockchip toolchains:

| Mode | File(s) | Description |
|---|---|---|
| **Combined** | `u-boot-rockchip.bin` | Pre-composed blob; written in one `dd` at LBA 64 |
| **Split** | `idbloader.img` + `u-boot.itb` | Two separate binaries; idbloader at LBA 64, ITB at LBA 16384 |

The combined mode is the legacy Rockchip SDK output. The split mode is what
modern U-Boot's `make rock5b-plus-rk3588_defconfig` produces.

---

### 6. Output image naming

```bash
IMGNAME=${VERSION}-${DATE}-${TARGET}_gpt.img
```

The file is named with the build date and product name, e.g.
`Radxa_Rock5BPlus_aosp-20260406-rock5bplus_gpt.img`, placed inside
`$ANDROID_PRODUCT_OUT`. The script refuses to overwrite an existing file.

---

### 7. Allocate the image file

```bash
sudo fallocate -l "${IMGSIZE}" "${IMAGE_PATH}"
```

`fallocate` pre-allocates exactly 19 456 MiB on disk without initialising the
bytes (faster than `dd if=/dev/zero`). The space is allocated but the data is
undefined until overwritten in subsequent steps.

---

### 8. Write U-Boot (before partitioning)

```bash
# Combined:
sudo dd if="${UBOOT_BIN}" of="${IMAGE_PATH}" seek=64 bs=512 conv=notrunc

# Split:
sudo dd if="${UBOOT_IDBLOADER}" of="${IMAGE_PATH}" seek=64  bs=512 conv=notrunc
sudo dd if="${UBOOT_ITB}"       of="${IMAGE_PATH}" seek=16384 bs=512 conv=notrunc
```

U-Boot is written **before** the GPT partition table. The RK3588 BootROM reads
the first-stage loader from LBA 64 unconditionally; this area sits before the
first GPT partition (`boot` starts at LBA 32768) so U-Boot and the GPT table
do not overlap.

`conv=notrunc` is required so that writing a small U-Boot blob does not truncate
the 19 GiB image file.

---

### 9. Create the GPT partition table

```bash
echo "${PART_TABLE}" | sudo sfdisk "${IMAGE_PATH}"
```

`sfdisk` reads a plain-text partition specification and writes a GUID Partition
Table (GPT) into the image. Key details:

- **`name="..."`** — the GPT partition name. Android's `ueventd` uses these
  names to create `/dev/block/by-name/<name>` symlinks, which are what `init`,
  `vold`, and all other Android services use to locate partitions.
- **`type=C12A7328-...`** — the FAT32/EFI System GUID for the `boot` partition.
- **`type=0FC63DAF-...`** — the Linux filesystem GUID for all other partitions.
- The `userdata` partition has no explicit `size=`, so `sfdisk` fills it to the
  end of the image (~12 GiB).

---

### 10. Map partitions with kpartx

```bash
KPARTX_OUT=$(sudo kpartx -av "${IMAGE_PATH}")
LOOPDEV=$(echo "${KPARTX_OUT}" | awk '/add map/ {dev=$3} END { sub(/p[0-9]+$/, "", dev); print dev }')
```

`kpartx` reads the GPT inside the image file, creates a loop device, and
exposes each partition as a device-mapper block device:

```
/dev/mapper/loop0p1  →  boot    (p1)
/dev/mapper/loop0p2  →  system  (p2)
/dev/mapper/loop0p3  →  vendor  (p3)
/dev/mapper/loop0p4  →  metadata(p4)
/dev/mapper/loop0p5  →  userdata(p5)
```

The `awk` command extracts the base device name (`loop0`) from the kpartx output
by stripping the trailing `pN` suffix from the last mapped device name.

The script then polls for up to ~2 seconds for `/dev/mapper/${LOOPDEV}p1` to
appear, since udev can take a moment to create the device nodes.

---

### 11. Write pre-built partition images

```bash
sudo dd if="${ANDROID_PRODUCT_OUT}/boot.img"   of="/dev/mapper/${LOOPDEV}p1" bs=1M conv=notrunc
sudo dd if="${ANDROID_PRODUCT_OUT}/system.img" of="/dev/mapper/${LOOPDEV}p2" bs=1M conv=notrunc
sudo dd if="${ANDROID_PRODUCT_OUT}/vendor.img" of="/dev/mapper/${LOOPDEV}p3" bs=1M conv=notrunc
```

Each AOSP image is `dd`'d directly into its raw partition. `bs=1M` uses 1 MiB
blocks for speed. `conv=notrunc` avoids shrinking the partition area.

**What is inside `boot.img`?**

`boot.img` is not a standard Android `mkbootimg` image. It is a FAT32 filesystem
created by [`device/radxa/rock5bplus/mkbootimg.mk`](device/radxa/rock5bplus/mkbootimg.mk)
containing:

| File | Purpose |
|---|---|
| `Image` | ARM64 kernel (uncompressed) |
| `rk3588-rock-5b-plus.dtb` | Device Tree Blob for Rock 5B+ (RK3588) |
| `android-sdcard.dtbo` | Device Tree Overlay for SD card support |
| `boot.scr` | U-Boot boot script (selects kernel, DTB, boot device) |
| `config.txt` | U-Boot environment overrides (boot device, `fdtfile`, recovery flag) |
| `uRamdisk` | U-Boot-wrapped AOSP ramdisk |
| `uRecovery` | U-Boot-wrapped recovery ramdisk |
| `ramdisk.img` | Raw AOSP ramdisk (also copied for reference) |

U-Boot reads `boot.scr` from this FAT32 partition and loads the kernel and DTB
from the same partition.

---

### 12. Set filesystem labels

```bash
sudo e2label "/dev/mapper/${LOOPDEV}p2" system
sudo e2label "/dev/mapper/${LOOPDEV}p3" vendor
```

The AOSP-generated `system.img` and `vendor.img` may already have internal ext4
labels, but these calls enforce them explicitly. Android's `vold` and `init` may
use filesystem labels as a secondary identification mechanism alongside GPT names.
Failures here are non-fatal (the script warns and continues).

---

### 13. Format metadata and userdata partitions

```bash
sudo mkfs.ext4 -F -L metadata "/dev/mapper/${LOOPDEV}p4"
sudo mkfs.ext4 -F -L userdata "/dev/mapper/${LOOPDEV}p5"
```

Unlike `system` and `vendor`, these two partitions are **not** produced by the
AOSP build:

- **`metadata`** — Used by Android's dynamic partition / Virtual A/B update
  bookkeeping. Must start as a clean, empty ext4 filesystem. Android initialises
  its internal structures on first boot.
- **`userdata`** — Holds all user-installed apps, account data, and encryption
  keys. Must be empty at flash time. Android formats it with the correct
  encryption parameters on first boot (or factory reset).

`-F` forces formatting without prompting. `-L <label>` sets the ext4 volume
label to match the GPT partition name so both lookup methods agree.

---

### 14. Unmap, fix ownership, and print summary

```bash
sudo kpartx -d "${IMAGE_PATH}"
sudo chown "${USER}:${USER}" "${IMAGE_PATH}"
sudo sgdisk -p "${IMAGE_PATH}"
```

- `kpartx -d` removes the device-mapper entries created in step 10.
- `chown` returns ownership of the image file to the calling user (it was
  created by `sudo fallocate`).
- `sgdisk -p` prints a human-readable summary of the final GPT table for
  verification.

The `trap cleanup EXIT` from step 2 also fires here and calls `kpartx -d` as a
safety net, but since the explicit `kpartx -d` above already unmapped everything,
the trap's call is a no-op.

---

## Flashing the image

Write the finished image to your target storage device (NVMe, eMMC, or SD card)
with a single `dd`:

```bash
sudo dd if="${ANDROID_PRODUCT_OUT}/Radxa_Rock5BPlus_aosp-<DATE>-rock5bplus_gpt.img" \
        of=/dev/sdX bs=4M status=progress conv=fsync
```

Replace `/dev/sdX` with your actual block device. The image includes U-Boot,
the GPT, and all required partitions — no separate U-Boot flashing step is
needed.

To select the boot device (NVMe, eMMC, SD card, USB) or enable recovery, edit
`config.txt` inside `device/radxa/rock5bplus-kernel/` before building, or
mount the `boot` partition after flashing and edit it there.

---

## Building from scratch

```bash
# 1. Set up the AOSP build environment
source build/envsetup.sh
lunch aosp_rock5bplus-ap3a-userdebug   # or -eng / -user

# 2. Build the required partition images
make bootimage systemimage vendorimage

# 3. Assemble the flashable GPT image
bash rock5bplus-mkimg.sh
```

The output image will be written to `$ANDROID_PRODUCT_OUT/`.
