#!/bin/env bash
set -e
set -o pipefail

AK3_REPO="https://github.com/omarsmehan1/AnyKernel3.git"

install_deps() {
    echo "--- Installing Dependencies ---"
    sudo apt update && sudo apt upgrade -y && sudo apt install -y git curl zip wget make gcc g++ bc
}

SRC_DIR="$(pwd)"
OUT_DIR="$SRC_DIR/out"
TC_DIR="$HOME/toolchains"
JOBS=$(nproc)

export PATH="$TC_DIR/clang-r530567/bin:$PATH"

fetch_tools() {
    if [[ ! -d "$TC_DIR/clang-r530567" ]]; then
        mkdir -p "$TC_DIR/clang-r530567"
        wget -q "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r530567.tar.gz" \
            -O "$TC_DIR/clang.tar.gz"  # <- q (quiet) يخفي اللوج
        tar xf "$TC_DIR/clang.tar.gz" -C "$TC_DIR/clang-r530567"
        rm "$TC_DIR/clang.tar.gz"
    fi

    rm -rf "$TC_DIR/AnyKernel3"
    git clone "$AK3_REPO" "$TC_DIR/AnyKernel3"
}

build_kernel() {
    case "$1" in
        a73xq) export VARIANT="a73xq"; export DEVICE="A73";;
        a52sxq) export VARIANT="a52sxq"; export DEVICE="A52S";;
        m52xq)  export VARIANT="m52xq";  export DEVICE="M52";;
        *) echo "Unknown device: $1"; exit 1;;
    esac

    # متغيرات KSU/GKI كاملة
    export ARCH=arm64
    export BRANCH="android11"
    export KMI_GENERATION=2
    export LLVM=1
    export DEPMOD=depmod
    export KCFLAGS="${KCFLAGS} -D__ANDROID_COMMON_KERNEL__"
    export STOP_SHIP_TRACEPRINTK=1
    export IN_KERNEL_MODULES=1
    export DO_NOT_STRIP_MODULES=1
    export TRIM_NONLISTED_KMI=0
    export KMI_SYMBOL_LIST_ADD_ONLY=1
    export KMI_SYMBOL_LIST_STRICT_MODE=0
    export KMI_ENFORCED=0
    export ABI_DEFINITION=android/abi_gki_aarch64.xml
    export KMI_SYMBOL_LIST=android/abi_gki_aarch64
    export ADDITIONAL_KMI_SYMBOL_LISTS="\
android/abi_gki_aarch64_cuttlefish
android/abi_gki_aarch64_db845c
android/abi_gki_aarch64_exynos
android/abi_gki_aarch64_exynosauto
android/abi_gki_aarch64_fcnt
android/abi_gki_aarch64_galaxy
android/abi_gki_aarch64_goldfish
android/abi_gki_aarch64_hikey960
android/abi_gki_aarch64_imx
android/abi_gki_aarch64_oneplus
android/abi_gki_aarch64_microsoft
android/abi_gki_aarch64_oplus
android/abi_gki_aarch64_qcom
android/abi_gki_aarch64_sony
android/abi_gki_aarch64_sonywalkman
android/abi_gki_aarch64_sunxi
android/abi_gki_aarch64_trimble
android/abi_gki_aarch64_unisoc
android/abi_gki_aarch64_vivo
android/abi_gki_aarch64_xiaomi
android/abi_gki_aarch64_zebra"

    # إعداد الـ defconfig و fragment حسب الجهاز
    export DEFCONF=rio_defconfig
    export FRAG="${VARIANT}.config"

    COMREV=$(git rev-parse --verify HEAD --short)
    export LOCALVERSION="-NovaKernel-KSU-$BRANCH-$KMI_GENERATION-$COMREV-$VARIANT"

    echo "--------------------------------"
    echo "Target: $VARIANT (GKI Build)"
    echo "Toolchain: $(clang --version | head -n 1)"
    echo "--------------------------------"

    echo "--- Kernel Build Starting ---"
    START=$(date +%s)
    echo "Kernel Version: 5.4.x$LOCALVERSION"

    make -j$JOBS -C "$SRC_DIR" O="$OUT_DIR" $DEFCONF $FRAG
    make -j$JOBS -C "$SRC_DIR" O="$OUT_DIR"
    echo "Kernel Build took: $(($(date +%s) - START)) seconds."
}

gen_anykernel() {
    AK3_DIR="$TC_DIR/RIO/work_ksu"
    rm -rf "$AK3_DIR"
    mkdir -p "$AK3_DIR"

    cp -af "$TC_DIR/AnyKernel3/"* "$AK3_DIR/"
    cp "$OUT_DIR/arch/arm64/boot/Image" "$AK3_DIR/"
    cp "$OUT_DIR/arch/arm64/boot/dtbo.img" "$AK3_DIR/"
    cp "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/yupik.dtb" "$AK3_DIR/dtb"

    cd "$AK3_DIR"
    zip -r9 "NovaKernel_$(date +%Y%m%d)_${VARIANT}.zip" ./* -x .git* README.md
    mkdir -p "$TC_DIR/RIO/FINAL"
    mv *.zip "$TC_DIR/RIO/FINAL/"
    cd "$SRC_DIR"
}

git switch susfs-rio || git checkout susfs-rio
install_deps
fetch_tools
rm -rf KernelSU drivers/kernelsu
curl -LSs "https://raw.githubusercontent.com/rsuntk/KernelSU/main/kernel/setup.sh" | bash -s susfs-rksu-master
build_kernel "$1"
gen_anykernel
