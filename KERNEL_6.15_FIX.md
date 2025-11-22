# MT7601U AP Driver - Kernel 6.15+ Compatibility Fix

## Problem
The MT7601U AP driver crashes on kernel 6.15+ when the USB adapter is plugged in.
The crash occurs because `RESOURCE_PRE_ALLOC` causes DMA allocation to happen too early,
before the USB device structures are fully initialized.

## Solution
Disable `RESOURCE_PRE_ALLOC` and fix the resulting compile errors in the non-RESOURCE_PRE_ALLOC code paths.

## Changes Made

### 1. os/linux/config.mk
**Removed** `-DRESOURCE_PRE_ALLOC` from WFLAGS:
```makefile
# Before:
WFLAGS += -DSYSTEM_LOG_SUPPORT -DRT28xx_MODE=$(RT28xx_MODE) -DCHIPSET=$(MODULE) -DRESOURCE_PRE_ALLOC

# After:
WFLAGS += -DSYSTEM_LOG_SUPPORT -DRT28xx_MODE=$(RT28xx_MODE) -DCHIPSET=$(MODULE)
```

### 2. common/cmm_mac_usb.c
Fixed multiple bugs in the non-RESOURCE_PRE_ALLOC code paths:

#### a) Fixed invalid `break` statements (line ~1063, ~1071)
Changed `break;` to `goto done;` and added `done:` label

#### b) Fixed CMD_RSP_CONTEXT field name (line ~765, ~1131)
Changed `TransferBuffer` to `CmdRspBuffer` (correct field name for non-RESOURCE_PRE_ALLOC)

#### c) Fixed NullContext array access (line ~1112)
Changed `&pAd->NullContext` to `&pAd->NullContext[0]` (it's an array)

#### d) Added NULL check in RTMPAllocUsbBulkBufStruct (line ~30)
Added validation to prevent crashes if pUsb_Dev is invalid

### 3. os/linux/usb_main_dev.c  
Added debug logging to probe function

## How to Build

```bash
cd /home/nix/mt7601u-ap
make clean
make -j$(nproc)
sudo make install
sudo depmod -a
```

## How to Test

```bash
# Load module (adapter unplugged)
sudo modprobe mt7601Uap

# Check it loaded
lsmod | grep mt7601
dmesg | tail -20

# Plug in MT7601U adapter
# Check detection
dmesg | tail -20
ip link show
```

## Expected Behavior
- Module loads without errors
- Adapter is detected when plugged in
- Interface `ra0` is created
- No kernel panics or hangs

## Why This Works
By removing `RESOURCE_PRE_ALLOC`, TX/RX ring DMA allocation is deferred until later
in the initialization sequence (in `rt28xx_init` via `rtmp_init_inf.c`), when:
1. The adapter structure is fully allocated
2. The USB device is fully configured  
3. All pointers are valid and initialized
4. The OS_Cookie->pUsb_Dev pointer is safely accessible

This prevents the kernel panic that occurred when trying to access an uninitialized
USB device pointer during early DMA allocation.

## Status
✅ All changes applied
✅ Builds successfully
⏳ Pending: Test after reboot with adapter plugged in

---
Date: 2025-11-22
Kernel: 6.15.8-2-cachyos
