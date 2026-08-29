#!/bin/sh
set -eu

TARGET_RELEASE=6.12.38-android16-5-abA175FXXS6CZG1-4k
KMI=android16-6.12

: "${KERNEL_OUT:?set KERNEL_OUT to the prepared CZG1 kernel output directory}"
: "${KSU_DIR:?set KSU_DIR to a clean KernelSU v3.2.5 source tree}"
: "${VMLINUX:?set VMLINUX to the recovered CZG1 vmlinux ELF}"
: "${MODULE_SYMVERS:?set MODULE_SYMVERS to the CZG1 Module.symvers file}"
: "${ANDROID_NDK_HOME:?set ANDROID_NDK_HOME to Android NDK r28 or newer}"

test -f "$KERNEL_OUT/Makefile"
test -f "$VMLINUX"
test -f "$MODULE_SYMVERS"
test -f "$KSU_DIR/kernel/Makefile"
test -f "$KSU_DIR/userspace/ksud/Cargo.toml"

release=$(sed -n 's/^#define UTS_RELEASE "\(.*\)"/\1/p' \
  "$KERNEL_OUT/include/generated/utsrelease.h")
if [ "$release" != "$TARGET_RELEASE" ]; then
  echo "wrong kernel release: expected $TARGET_RELEASE, got $release" >&2
  exit 1
fi

make -C "$KERNEL_OUT" M="$KSU_DIR/kernel" src="$KSU_DIR/kernel" \
  ARCH=arm64 LLVM=1 LLVM_IAS=1 \
  CONFIG_KSU=m \
  CONFIG_KSU_SAMSUNG_KDP=y \
  CONFIG_KSU_SAMSUNG_RKP=y \
  CONFIG_KSU_SAMSUNG_DEFEX=y \
  CONFIG_KSU_SAMSUNG_NO_PATCH_TEXT=y \
  KBUILD_MODPOST_WARN=1 modules

python3 "$(dirname "$0")/tools/audit_module_against_target.py" \
  "$KSU_DIR/kernel/kernelsu.ko" "$VMLINUX" "$MODULE_SYMVERS" \
  --manual-relocation

ndk_bin="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
"$ndk_bin/llvm-strip" -d "$KSU_DIR/kernel/kernelsu.ko"
asset="$KSU_DIR/userspace/ksud/bin/aarch64/${KMI}_kernelsu.ko"
install -D -m 0644 "$KSU_DIR/kernel/kernelsu.ko" "$asset"

export PATH="$ndk_bin:$PATH"
export LIBCLANG_PATH="$ndk_bin"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$ndk_bin/aarch64-linux-android35-clang"
export CC_aarch64_linux_android="$CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER"
export AR_aarch64_linux_android="$ndk_bin/llvm-ar"

cargo build --manifest-path "$KSU_DIR/Cargo.toml" --release \
  --target aarch64-linux-android -p ksud

out_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
install -m 0644 "$KSU_DIR/kernel/kernelsu.ko" \
  "$out_dir/android16-6.12_kernelsu-A175FXXS6CZG1-kdp.ko"
install -m 0755 \
  "$KSU_DIR/target/aarch64-linux-android/release/ksud" \
  "$out_dir/ksud-A175FXXS6CZG1-kdp"
