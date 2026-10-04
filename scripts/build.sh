#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$ROOT/sources.env"
if [[ $(uname -s) != Linux || $(uname -m) != aarch64 ]]; then
    printf '%s\n' 'Use an ARM64 Linux host or the GitHub Actions workflow.' >&2
    exit 1
fi
for tool in curl sha256sum tar xz zstd make gcc flex bison bc depmod python3; do
    command -v "$tool" >/dev/null || { printf 'Missing tool: %s\n' "$tool" >&2; exit 1; }
done
BUILD="$ROOT/build"
OUT="$BUILD/output"
STAGE="$BUILD/stage"
DIST="$ROOT/dist"
JOBS=${JOBS:-$(nproc)}
export SOURCE_DATE_EPOCH
export KBUILD_BUILD_TIMESTAMP="$(date -u -d "@$SOURCE_DATE_EPOCH" '+%Y-%m-%d %H:%M:%S UTC')"
export KBUILD_BUILD_USER=builder KBUILD_BUILD_HOST=homa-kernel KBUILD_BUILD_VERSION=1
mkdir -p "$BUILD/downloads" "$OUT" "$STAGE" "$DIST"

download() {
    local url=$1 path=$2 checksum=$3
    if [[ ! -f $path ]]; then
        curl --fail --location --retry 3 "$url" -o "$path.part"
        mv "$path.part" "$path"
    fi
    printf '%s  %s\n' "$checksum" "$path" | sha256sum --check --status
}

download "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$LINUX_VERSION.tar.xz" "$BUILD/downloads/linux.tar.xz" "$LINUX_SHA256"
download "https://github.com/PlatformLab/HomaModule/archive/$HOMA_REF.tar.gz" "$BUILD/downloads/homa.tar.gz" "$HOMA_SHA256"
LINUX="$BUILD/linux-$LINUX_VERSION"
HOMA="$BUILD/HomaModule-$HOMA_REF"
[[ -d $LINUX ]] || tar -xJf "$BUILD/downloads/linux.tar.xz" -C "$BUILD"
[[ -d $HOMA ]] || tar -xzf "$BUILD/downloads/homa.tar.gz" -C "$BUILD"
export ARCH=arm64
export KCONFIG_CONFIG="$OUT/.config"
"$LINUX/scripts/kconfig/merge_config.sh" -m -O "$OUT" "$ROOT/config/arm64.config" "$ROOT/config/homa.config"
"$LINUX/scripts/config" --file "$OUT/.config" --set-str LOCALVERSION "$KERNEL_LOCALVERSION"
make -C "$LINUX" O="$OUT" olddefconfig
python3 "$ROOT/scripts/check-config.py" "$OUT/.config"
make -C "$LINUX" O="$OUT" -j"$JOBS" Image modules
make -C "$HOMA" KDIR="$OUT" -j"$JOBS" all
RELEASE=$(make -s -C "$LINUX" O="$OUT" kernelrelease)
rm -rf "$STAGE/lib" "$DIST"
mkdir -p "$DIST"
make -C "$LINUX" O="$OUT" INSTALL_MOD_PATH="$STAGE" modules_install
make -C "$OUT" M="$HOMA" INSTALL_MOD_PATH="$STAGE" modules_install
depmod -b "$STAGE" "$RELEASE"
rm -f "$STAGE/lib/modules/$RELEASE/build" "$STAGE/lib/modules/$RELEASE/source"
cp "$OUT/arch/arm64/boot/Image" "$DIST/vmlinux"
cp "$OUT/.config" "$DIST/config"
cp "$HOMA/homa.ko" "$DIST/homa.ko"
cp "$HOMA/homa.h" "$DIST/homa.h"
cp "$ROOT/sources.env" "$DIST/sources.env"
printf '%s\n' "$RELEASE" > "$DIST/kernel-release"
tar --sort=name --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner -C "$STAGE" -cf - lib/modules | zstd -T"$JOBS" -19 -o "$DIST/modules.tar.zst"
{ gcc --version | head -n 1; ld --version | head -n 1; } > "$DIST/toolchain.txt"
cd "$DIST"
sha256sum config homa.ko homa.h kernel-release modules.tar.zst sources.env toolchain.txt vmlinux > SHA256SUMS
printf 'Build complete: %s\n' "$DIST"
