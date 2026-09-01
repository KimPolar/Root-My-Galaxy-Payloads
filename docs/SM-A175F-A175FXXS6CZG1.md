# Samsung Galaxy A17 SM-A175F / A175FXXS6CZG1

## Target identity

This profile is for the exact CZG1 kernel release:

```text
model: SM-A175F
firmware: A175FXXS6CZG1
kernel: 6.12.38-android16-5-abA175FXXS6CZG1-4k
KMI: android16-6.12
```

The exploit offsets are selected by the complete `uname -r`; the shorter
`6.12.38` string is only suitable for the application support-feed match.

## Root My Galaxy payload

Build the app payload and its bootstrap helper with:

```sh
make TARGET=a17x-A175FXXS6CZG1 \
  ANDROID_NDK_HOME=/path/to/android-ndk
make TARGET=a17x-A175FXXS6CZG1 \
  ANDROID_NDK_HOME=/path/to/android-ndk release
```

The A17 constructor runs the device-specific chain in an isolated child. Its
forged workqueue item executes the app-provided `CVE43499_ROOT_HELPER` as:

```text
cve-2026-43499-root --umh <app-uid> <bootstrap-marker>
```

This replaces the standalone A17 repository's `g4d`/`g4sh` endpoint with the
root-daemon protocol already consumed by Root My Galaxy. A successful run emits
`done=1 root=1`, after which the app can request the normal guarded KernelSU
late-load operation.

The current release payload is:

```text
artifacts/a17-A175FXXS6CZG1/cve-2026-43499-app.so
size: 104128
SHA-256: 7e0f4fba838d2d8497e44c1f56e67c802398386e93dc0449e222e82c35cede67
```

This artifact is built by the clean `a17x-A175FXXS6CZG1` profile using the
shared payload sources and the exact CZG1 BTF layouts. The published payload
ID and artifact path remain `a17-A175FXXS6CZG1` for application compatibility.
The CZG1 app profile retains the proven four KernelSnitch collision candidates,
uses three in-session slide page setup attempts, and caps app-requested full
supervisor restarts at three. Its initial pipe reclaim preparation retains 16
slabs instead of 32, matching the earlier A17 mitigation for reboots caused by
roughly 800 simultaneously retained mm-backed process/file objects.

## KernelSU 6.12 status

Do not reuse an Android 6.6 or another device's 6.12 module. Samsung enables
KDP/RKP/DEFEX, so the module was built and audited against the exact CZG1
kernel ABI recovered from the supplied boot image, BTF, config, and kallsyms
name list.

The raw ARM64 Image was recovered from the v4 boot image, converted to a
symbolized ELF, and used to recover 18,120 exact export CRCs. The resulting
manual-relocation audit reports:

```text
undefined symbols: 214
module version entries: 0
missing from target symbol table: 0
symbols resolved from kallsyms rather than target exports: 53
target CRC mismatches: 0
```

The module uses the Samsung KDP/RKP/DEFEX adaptations and
`CONFIG_KSU_SAMSUNG_NO_PATCH_TEXT=y`. Its metadata contains the exact target
vermagic:

```text
6.12.38-android16-5-abA175FXXS6CZG1-4k SMP preempt mod_unload modversions aarch64
```

After recovering those three exact inputs, apply
`kernelsu/patches/KernelSU-v3.2.5-samsung-kdp-rkp-defex.patch` to KernelSU
v3.2.5 and run:

```sh
KERNEL_OUT=/path/to/czg1/out \
KSU_DIR=/path/to/KernelSU \
VMLINUX=/path/to/czg1/vmlinux \
MODULE_SYMVERS=/path/to/czg1/Module.symvers \
ANDROID_NDK_HOME=/path/to/android-ndk \
./kernelsu/build-a17-A175FXXS6CZG1.sh
```

The script fails closed on a mismatched `UTS_RELEASE`, enables the Samsung
KDP/RKP/DEFEX and no-live-text-patching paths, audits manual relocation, embeds
the exact module in the `android16-6.12` ksud asset slot, and produces:

```text
kernelsu/android16-6.12_kernelsu-A175FXXS6CZG1-kdp.ko
kernelsu/ksud-A175FXXS6CZG1-kdp
```

Published build artifacts:

| File | Size | SHA-256 |
| --- | ---: | --- |
| `kernelsu/android16-6.12_kernelsu-A175FXXS6CZG1-kdp.ko` | 399664 | `5dbe47bd325bc5191242ea861baace2883feda1fa16a71aac0ac814022f83ddf` |
| `kernelsu/ksud-A175FXXS6CZG1-kdp` | 4928048 | `01e5918704c17528476b5f8324f13254e31c49fd5159506bb44e957976834744` |

The profile is present in `targets-v3.json` as experimental. Offline gates are
complete; the full exploit → app root daemon → late-load sequence still needs
CZG1 hardware validation before the status can be promoted.
