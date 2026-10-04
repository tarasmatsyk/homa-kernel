#!/usr/bin/env python3
import sys
from pathlib import Path

config = set(Path(sys.argv[1]).read_text().splitlines())
required = (
    "ARM64", "ARM64_4K_PAGES", "MODULES", "MODULE_UNLOAD", "MODVERSIONS",
    "KALLSYMS", "KALLSYMS_ALL", "INET", "IPV6", "NET_SCHED", "NET_SCH_PRIO",
    "BLK_DEV_INITRD", "DEVTMPFS", "DEVTMPFS_MOUNT", "VIRTIO", "VIRTIO_MMIO",
    "VIRTIO_PCI", "VIRTIO_NET", "VIRTIO_BLK", "VIRTIO_CONSOLE",
    "VIRTIO_VSOCKETS", "EXT4_FS", "OVERLAY_FS", "PROC_FS", "SYSFS",
    "TTY", "SERIAL_AMBA_PL011", "SERIAL_AMBA_PL011_CONSOLE", "NAMESPACES",
    "NET_NS", "CGROUPS",
)
missing = [name for name in required if f"CONFIG_{name}=y" not in config]
if missing:
    sys.exit("Required kernel settings are missing: " + ", ".join(missing))
print("Kernel configuration check passed.")
