# ARM64 Homa kernel

This repository builds Linux 6.17.8 and Homa for an ARM64 Linux VM.
It contains configuration files and build scripts. It does not contain a Linux fork.

GitHub Actions uses an `ubuntu-24.04-arm` runner. Each push to `main`, pull request,
or manual run builds the kernel and saves the result as a workflow artifact.
A tag such as `v6.17.8-homa.1` also creates a GitHub Release.

## Source references

The exact versions and archive SHA256 values are in [sources.env](sources.env).

- [Linux 6.17.8](https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.17.8.tar.xz)
- [Linux archive checksums](https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc)
- [Apple ARM64 VM configuration](https://github.com/apple/containerization/blob/8be8e841e76960403ac2b126c737a7ac25bf090a/kernel/config-arm64)
- [Homa source](https://github.com/PlatformLab/HomaModule/tree/53f79638e00ac719b0b390e4c98cb547cce8134d)
- [Homa installation instructions](https://github.com/PlatformLab/HomaModule/blob/53f79638e00ac719b0b390e4c98cb547cce8134d/INSTALL.md)
- [Apple Container commands](https://github.com/apple/container/blob/main/docs/command-reference.md)
- [GitHub runner specifications](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

`config/arm64.config` comes from the pinned Apple configuration. It was made for
Linux 6.1.68. The build applies `config/homa.config`, then runs `olddefconfig` for
Linux 6.17.8. A check stops the build if required VM or module settings are missing.
Boot drivers are built into the kernel. Homa is a loadable module.

## Create a GitHub repository

From this directory, after the first commit:

```sh
gh repo create homa-kernel --public --source=. --remote=origin --push
gh workflow run build.yml
gh run list --workflow build.yml
```

After the build passes, create a release:

```sh
git tag v6.17.8-homa.1
git push origin v6.17.8-homa.1
```

Change `KERNEL_LOCALVERSION` when you change the kernel configuration or Homa
source. Use a matching release tag. This gives each module build its own kernel
release string. Update archive checksums when you change source versions.

## Build on ARM64 Linux

Use Ubuntu 24.04 on an ARM64 host:

```sh
sudo apt-get update
sudo apt-get install -y build-essential bc bison flex libssl-dev libelf-dev dwarves curl xz-utils zstd kmod python3
./scripts/build.sh
```

Use `JOBS=2 ./scripts/build.sh` to limit parallel compilation. The build downloads
source archives and checks their SHA256 values before extraction. GitHub Actions
versions are pinned to commit IDs. The runner packages can change. Thus, pinned
source versions do not guarantee identical binary files across future builds.
The release records compiler and linker versions in `toolchain.txt`.

## Build files

The `dist/` directory contains:

- `vmlinux` - the uncompressed ARM64 boot `Image`, named for Apple Container.
- `config` - the final Linux configuration.
- `homa.ko` - the Homa module. This version includes its queue code in this file.
- `homa.h` - the Homa user API header.
- `modules.tar.zst` - installed modules under `lib/modules/<kernel-release>`.
- `kernel-release` - the kernel release string.
- `sources.env` - pinned source references and archive checksums.
- `toolchain.txt` - compiler and linker versions.
- `SHA256SUMS` - checksums for these files.

`vmlinux` is a boot image, not the ELF file used by a debugger. Build files and
downloaded source stay out of Git. The module archive includes module dependency
files. It does not include build-directory links or kernel headers.

## Use with Apple Container

Download a completed release on your Mac. Replace `OWNER` with the GitHub owner:

```sh
mkdir -p homa-kernel-files
cd homa-kernel-files
gh release download v6.17.8-homa.1 --repo OWNER/homa-kernel
shasum -a 256 -c SHA256SUMS
container machine create --kernel "$PWD/vmlinux" --name homa-dev ubuntu:24.04
```

Check your installed command with `container machine create --help`. For a
container without a machine, current Apple Container also supports:

```sh
container run --rm -it --kernel "$PWD/vmlinux" --volume "$PWD:/kernel" ubuntu:24.04 bash
```

In that guest, as root:

```sh
apt-get update
apt-get install -y kmod zstd
cd /kernel
test "$(uname -r)" = "$(cat kernel-release)"
tar --zstd -xf modules.tar.zst -C /
depmod -a
modprobe homa
lsmod | grep homa
```

The module must run with the kernel from the same release. If you use a machine,
copy the release files into it before you install the modules. Loading a module
requires guest root and permission to load kernel modules. The module is not
loaded automatically at boot.

This is a development kernel pinned to the requested version. A successful
compile does not prove that it boots in your VM or that Homa traffic works on
your VM network. Check both before use. See the Homa installation instructions
for `homa_prio`, network setup, and performance settings.

## Source licenses

Linux uses GPL-2.0-only, with exceptions for some files. Homa contains its own
license notices. The Apple configuration comes from an Apache-2.0 repository.
Keep upstream license notices with source files. When you distribute binary
files, also make their exact source and this build recipe available under the
applicable license terms.
