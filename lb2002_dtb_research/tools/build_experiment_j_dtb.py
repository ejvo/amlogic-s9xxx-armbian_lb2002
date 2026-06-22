#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from pyfdt.pyfdt import (
    FdtBlobParse,
    FdtNode,
    FdtProperty,
    FdtPropertyStrings,
    FdtPropertyWords,
)


ROOT = Path(__file__).resolve().parents[1]
BOOT_DTB = ROOT / "armbian_files_lb2002_v2" / "boot" / "dtb" / "amlogic"
BASE_DTB_CANDIDATES = [
    BOOT_DTB / "meson-g12a-s905l3a-lb2002-experiment-h-v1.dtb",
    Path(r"E:\dtb\amlogic\meson-g12a-s905l3a-lb2002-experiment-h-v1.dtb"),
    BOOT_DTB / "meson-g12a-s905l3a-lb2002-experiment-g-v1.dtb",
    Path(r"E:\dtb\amlogic\meson-g12a-s905l3a-lb2002-experiment-g-v1.dtb"),
]
OUTPUT_DTB = BOOT_DTB / "meson-g12a-s905l3a-lb2002-experiment-j-v1.dtb"
OUTPUT_DTS = BOOT_DTB / "meson-g12a-s905l3a-lb2002-experiment-j-v1.full.dts"
OUTPUT_STUB_DTS = BOOT_DTB / "meson-g12a-s905l3a-lb2002-experiment-j-v1.dts"

GPIO_AO = 0x34
PWM_EF = 0x119
WIFI32K = 0x2001
SDIO_PWRSEQ = 0x2002


def parse_dtb(path: Path):
    return FdtBlobParse(path.open("rb")).to_fdt()


def walk(node: FdtNode, path: str = ""):
    cur = "/" if node.get_name() == "/" else path.rstrip("/") + "/" + node.get_name()
    yield cur, node
    for item in getattr(node, "subdata", []):
        if isinstance(item, FdtNode):
            yield from walk(item, cur)


def find_node(root: FdtNode, path: str) -> FdtNode:
    for node_path, node in walk(root):
        if node_path == path:
            return node
    raise KeyError(path)


def remove_property(node: FdtNode, name: str) -> None:
    node.subdata = [
        item
        for item in node.subdata
        if not (isinstance(item, FdtProperty) and item.get_name() == name)
    ]


def first_child_index(node: FdtNode) -> int:
    for idx, item in enumerate(node.subdata):
        if isinstance(item, FdtNode):
            return idx
    return len(node.subdata)


def set_property(node: FdtNode, prop: FdtProperty) -> None:
    remove_property(node, prop.get_name())
    node.subdata.insert(first_child_index(node), prop)


def remove_child(node: FdtNode, name: str) -> None:
    node.subdata = [
        item
        for item in node.subdata
        if not (isinstance(item, FdtNode) and item.get_name() == name)
    ]


def make_wifi32k() -> FdtNode:
    node = FdtNode("wifi32k")
    node.append(FdtPropertyStrings("compatible", ["pwm-clock"]))
    node.append(FdtPropertyWords("#clock-cells", [0]))
    node.append(FdtPropertyWords("clock-frequency", [0x8000]))
    node.append(FdtPropertyWords("pwms", [PWM_EF, 0, 0x7736, 0]))
    node.append(FdtPropertyWords("phandle", [WIFI32K]))
    return node


def make_sdio_pwrseq() -> FdtNode:
    node = FdtNode("sdio-pwrseq")
    node.append(FdtPropertyStrings("compatible", ["mmc-pwrseq-simple"]))
    node.append(FdtPropertyWords("reset-gpios", [GPIO_AO, 0x46, 1]))
    node.append(FdtPropertyWords("post-power-on-delay-ms", [1000]))
    node.append(FdtPropertyWords("power-off-delay-us", [10000]))
    node.append(FdtPropertyWords("clocks", [WIFI32K]))
    node.append(FdtPropertyStrings("clock-names", ["ext_clock"]))
    node.append(FdtPropertyWords("phandle", [SDIO_PWRSEQ]))
    return node


def ensure_wifi_child(host: FdtNode) -> FdtNode:
    remove_child(host, "wifi@1")
    wifi = FdtNode("wifi@1")
    wifi.append(FdtPropertyStrings("compatible", ["uwcnmodem,we5621ds"]))
    wifi.append(FdtPropertyWords("reg", [1]))
    wifi.append(FdtPropertyStrings("status", ["okay"]))
    host.append(wifi)
    return wifi


def build() -> None:
    base_dtb = next((path for path in BASE_DTB_CANDIDATES if path.exists()), None)
    if base_dtb is None:
        raise FileNotFoundError("No experiment-h/g base DTB found")

    fdt = parse_dtb(base_dtb)
    root = fdt.get_rootnode()

    set_property(root, FdtPropertyStrings("model", ["LB2002 White S905L3A EXPERIMENT J V1"]))
    set_property(
        root,
        FdtPropertyStrings(
            "compatible",
            [
                "lb2002-white-experiment-j-v1",
                "lb2002-white-experiment-h-v1",
                "lb2002-white-experiment-g-v1",
                "m401a",
                "amlogic,g12a",
            ],
        ),
    )
    set_property(root, FdtPropertyStrings("amlogic-dt-id", ["lb2002_m401a_experiment_j_v1_2g"]))

    aliases = find_node(root, "/aliases")
    set_property(aliases, FdtPropertyStrings("mmc0", ["/soc/sd@ffe03000"]))
    set_property(aliases, FdtPropertyStrings("mmc1", ["/soc/sd@ffe05000"]))
    set_property(aliases, FdtPropertyStrings("sd_emmc_a", ["/soc/sd@ffe03000"]))
    set_property(aliases, FdtPropertyStrings("sd_emmc_b", ["/soc/sd@ffe05000"]))

    remove_child(root, "wifi32k")
    remove_child(root, "sdio-pwrseq")
    root.append(make_wifi32k())
    root.append(make_sdio_pwrseq())

    wifi_host = find_node(root, "/soc/sd@ffe03000")
    old_host = find_node(root, "/soc/sd@ffe05000")

    set_property(wifi_host, FdtPropertyStrings("status", ["okay"]))
    set_property(wifi_host, FdtPropertyWords("bus-width", [4]))
    set_property(wifi_host, FdtPropertyWords("max-frequency", [25_000_000]))
    set_property(wifi_host, FdtPropertyWords("mmc-pwrseq", [SDIO_PWRSEQ]))
    set_property(wifi_host, FdtPropertyWords("vmmc-supply", [0x35]))
    set_property(wifi_host, FdtPropertyWords("vqmmc-supply", [0x12D]))
    set_property(wifi_host, FdtProperty("cap-sdio-irq"))
    set_property(wifi_host, FdtProperty("non-removable"))
    set_property(wifi_host, FdtProperty("keep-power-in-suspend"))
    ensure_wifi_child(wifi_host)

    remove_child(old_host, "wifi@1")
    remove_property(old_host, "mmc-pwrseq")
    set_property(old_host, FdtPropertyStrings("status", ["disabled"]))

    wifi_node = find_node(root, "/wifi")
    set_property(wifi_node, FdtPropertyStrings("compatible", ["amlogic,uwe5621-irq"]))
    set_property(wifi_node, FdtPropertyStrings("status", ["okay"]))
    set_property(wifi_node, FdtPropertyStrings("irq_trigger_type", ["GPIO_IRQ_HIGH"]))

    symbols = find_node(root, "/__symbols__")
    set_property(symbols, FdtPropertyStrings("wifi32k", ["/wifi32k"]))
    set_property(symbols, FdtPropertyStrings("sdio_pwrseq", ["/sdio-pwrseq"]))

    OUTPUT_DTB.write_bytes(fdt.to_dtb())
    OUTPUT_DTS.write_text(fdt.to_dts(), encoding="utf-8")
    OUTPUT_STUB_DTS.write_text(
        """/dts-v1/;
/include/ "meson-g12a-s905l3a-lb2002-experiment-g-v1.dts"

/ {
    model = "LB2002 White S905L3A EXPERIMENT J V1";
    compatible = "lb2002-white-experiment-j-v1", "lb2002-white-experiment-h-v1", "lb2002-white-experiment-g-v1", "m401a", "amlogic,g12a";
    amlogic-dt-id = "lb2002_m401a_experiment_j_v1_2g";

    aliases {
        mmc0 = "/soc/sd@ffe03000";
        mmc1 = "/soc/sd@ffe05000";
        sd_emmc_a = "/soc/sd@ffe03000";
        sd_emmc_b = "/soc/sd@ffe05000";
    };

    wifi32k: wifi32k {
        compatible = "pwm-clock";
        #clock-cells = <0>;
        clock-frequency = <0x00008000>;
        pwms = <&{/soc/bus@ffd00000/pwm@19000} 0x00000000 0x00007736 0x00000000>;
    };

    sdio_pwrseq: sdio-pwrseq {
        compatible = "mmc-pwrseq-simple";
        reset-gpios = <0x00000034 0x00000046 0x00000001>;
        post-power-on-delay-ms = <1000>;
        power-off-delay-us = <10000>;
        clocks = <&wifi32k>;
        clock-names = "ext_clock";
    };
};

&{/soc/sd@ffe03000} {
    status = "okay";
    bus-width = <4>;
    max-frequency = <25000000>;
    mmc-pwrseq = <&sdio_pwrseq>;
    vmmc-supply = <0x00000035>;
    vqmmc-supply = <0x0000012d>;
    cap-sdio-irq;
    non-removable;
    keep-power-in-suspend;

    wifi@1 {
        compatible = "uwcnmodem,we5621ds";
        reg = <0x00000001>;
        status = "okay";
    };
};

&{/soc/sd@ffe05000} {
    /delete-node/ wifi@1;
    /delete-property/ mmc-pwrseq;
    status = "disabled";
};

&{/wifi} {
    compatible = "amlogic,uwe5621-irq";
    status = "okay";
    irq_trigger_type = "GPIO_IRQ_HIGH";
};

/*
 * Experiment J:
 * - NullYing-style SDIO host test: move UWE5621DS from /soc/sd@ffe05000 to /soc/sd@ffe03000
 * - use wifi@1 compatible = "uwcnmodem,we5621ds"
 * - keep LB2002 current reset GPIO hypothesis 0x46
 * - add NullYing pwrseq delays: 1000 ms post-power-on, 10000 us power-off
 * - do not switch uEnv.txt automatically
 */
""",
        encoding="utf-8",
    )


if __name__ == "__main__":
    build()
