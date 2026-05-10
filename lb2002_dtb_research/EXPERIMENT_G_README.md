# Experiment G

## Goal

`experiment_g` is the first clean LB2002 SDIO attempt after the GPIO map was physically confirmed.

It intentionally removes image-level diagnostic helpers and keeps only:

- the confirmed GPIO mapping in DT
- the kernel-side SDIO recovery experiment

## Clean-system rules

The staged rootfs for this experiment no longer includes:

- `lb2002-pinprobe-*.sh`
- `lb2002-sdio-*.sh`
- `lb2002-pinprobe-map.txt`

Reason:

- these files are useful during board discovery
- they are not needed for a clean SDIO bring-up image
- removing them avoids accidental influence on the experiment environment

## Kernel patch

Patch path used by `compile-kernel.yml`:

- `kernel/patch_lb2002_experiment_g/linux-6.12.y/0001-mmc-lb2002-experiment-g-aml-sdio-recovery.patch`

Marker expected in packaged kernel:

- `lb2002-expg`

## DTB

Default DTB for this experiment:

- `meson-g12a-s905l3a-lb2002-experiment-g-v1.dtb`

`uEnv.txt` points to this file.

## What changed relative to experiment_f

1. No raw IRQ GPIO sampling during attach.
2. No userspace diagnostic helpers staged into the image.
3. Attach flow now tries a more Amlogic-like recovery pattern:
   - module enable/reset sequencing
   - host power recycle
   - `sdio_reset()`
   - `mmc_go_idle()`
   - `mmc_send_if_cond()`
   - second `CMD5` attempt if the first returns timeout or `OCR=0`

## Intent

This still does not import the full vendor driver stack.

It only transfers the minimum lower-level behavior suggested by:

- `CoreELEC/uwe5631-aml`
- especially `wcn_boot.c` and `sdiohal_scan_card()`

The next step after this image is UART validation of:

- `lb2002-expg prepare begin`
- `lb2002-expg host power recycle begin`
- `lb2002-expg attach-sdio first-cmd5 ...`
- `lb2002-expg attach-sdio second-cmd5 ...`
