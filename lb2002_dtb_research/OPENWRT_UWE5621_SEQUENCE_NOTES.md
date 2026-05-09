# OpenWrt UWE5621 Sequence Notes

Purpose:
- keep the strongest Linux-side reference for `UWE5621` bring-up next to the LB2002 DTS work
- document the sequence pieces that are likely missing on Armbian even when SDIO wiring is correct

Local source references used for this summary:
- `D:\приставка белая\lb2002_dtb_research\reports\OPENWRT_UWE5621_EXTRACTION_CHECKLIST.md`
- `D:\приставка белая\lb2002_dtb_research\reports\ANDROID_UWE5621_BSP_ANALYSIS.md`
- local OpenWrt repo cache: `D:\приставка белая\_tmp_openwrt_rk3566_leopad_10s`

## Strong candidate sequence

Most useful extracted sequence:
1. assert board-side power enable for the WCN block
2. release reset / allow the Marlin core to run
3. perform SDIO scan and card attach orchestration
4. enable SDIO func1
5. load WCN firmware blob
6. transition host/card timing upward after early attach
7. bring up the upper WLAN netdev driver
8. optionally bring up BT-over-SDIO userspace glue

Android-side evidence strongly suggests the lower BSP is not passive:
- `extern_wifi_set_enable`
- `sdiohal_scan_card`
- `sdiohal_probe`
- `enable func1 ok`
- `sdiohal_change_to_sdr104`
- `marlin_set_power`
- `sdio_reset_comm`

## OpenWrt tree pieces to mine

OpenWrt reference tree carries a unified `uwe5622` source tree with `UWE5621` enabled inside it:
- `drivers/net/wireless/uwe5622/unisocwcn/`
- `drivers/net/wireless/uwe5622/unisocwifi/`
- `drivers/net/wireless/uwe5622/tty-sdio/`

The strongest lower-layer SDIO candidates are:
- `unisocwcn/sdio/sdio_v3.c`
- `unisocwcn/sdio/sdiohal_main.c`
- `unisocwcn/sdio/sdiohal_common.c`
- `unisocwcn/sdio/sdiohal_ctl.c`
- `unisocwcn/platform/wcn_boot.c`

Most relevant function names already extracted from the reference material:
- `sdiohal_scan_card()`
- `sdiohal_register_scan_notify()`
- `sdiohal_probe()`
- `sdiohal_change_to_sdr104()`
- `sdiohal_host_irq_init()`
- `sdiohal_parse_dt()`
- `sdio_reset_comm()`
- `marlin_set_power()`

## Practical direction for LB2002

The corrected `-1` line hypothesis makes the LB2002 SDIO data path line up with G12A `GPIOX_0..5`.

That means the next attempt should focus on:
- conservative SDIO host timing first
- corrected `CHIP_EN`, `RST_N`, and `INT` GPIO assignments
- preserving high-verbosity MMC/SDIO logging during probe
- comparing Armbian attach logs with the Android/OpenWrt lower-layer sequence above

## Firmware / module hints

Useful OpenWrt-side firmware and module names to keep aligned with future porting work:
- `sprdwl_ng`
- `sprdbt_tty`
- `wcnmodem.bin`
- `unisoc_wifi_mac.txt`

OpenWrt reference also uses BT userspace glue after kernel attach:
- `rfkill unblock bluetooth`
- `hciattach -s 1500000 /dev/ttyBT0 sprd`
