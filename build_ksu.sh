#!/bin/env bash

set -e
set -o pipefail

# رابط مستودع AnyKernel3
AK3_REPO="https://github.com/omarsmehan1/AnyKernel3.git"

install_deps() {
    echo "--- Installing Dependencies ---"
    sudo apt update && sudo apt install -y git aria2 device-tree-compiler lz4 xz-utils zlib1g-dev openjdk-17-jdk gcc g++ python3 python-is-python3 p7zip-full android-sdk-libsparse-utils erofs-utils \
            default-jdk gnupg flex bison gperf build-essential zip curl libc6-dev libncurses-dev libx11-dev libreadline-dev libgl1 libgl1-mesa-dev \
            make bc grep tofrodos python3-markdown libxml2-utils xsltproc libtinfo6 \
            repo cpio kmod openssl libelf-dev pahole libssl-dev libarchive-tools zstd rsync --fix-missing
    
    wget -q http://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2ubuntu0.1_amd64.deb
    sudo dpkg -i libtinfo5_6.3-2ubuntu0.1_amd64.deb || sudo apt-get install -f -y
    rm libtinfo5_6.3-2ubuntu0.1_amd64.deb
}

################################################ Vars
SRC_DIR="$(pwd)"
OUT_DIR="$SRC_DIR/out"
TC_DIR="$HOME/toolchains"
JOBS=$(nproc)
export PATH="$TC_DIR/clang-r530567/bin:$PATH"

fetch_tools() {
    if [[ ! -d "$TC_DIR/clang-r530567" ]]; then
        mkdir -p "$TC_DIR/clang-r530567"
        AOSPTC_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r530567.tar.gz"

        echo "  -> Downloading Clang using aria2..."
        aria2c -x 16 -s 16 -d "$TC_DIR" -o "clang.tar.gz" "$AOSPTC_URL"

        echo "  -> Extracting Clang..."
        tar xf "$TC_DIR/clang.tar.gz" -C "$TC_DIR/clang-r530567"
        rm "$TC_DIR/clang.tar.gz"
    fi

    if [[ ! -d "$TC_DIR/AnyKernel3" ]]; then
        echo "  -> Cloning AnyKernel3..."
        git clone "$AK3_REPO" "$TC_DIR/AnyKernel3"
    fi
}

build_kernel() {
    case "$1" in
        a73xq) export VARIANT="a73xq"; export DEVICE="A73";;
        a52sxq) export VARIANT="a52sxq"; export DEVICE="A52S";;
        m52xq)  export VARIANT="m52xq";  export DEVICE="M52";;
        *) echo "Unknown device: $1"; exit 1;;
    esac

    export ARCH=arm64
    export BRANCH="android11"
    export KMI_GENERATION=2
    export LLVM=1
    export DEPMOD=depmod
    export KCFLAGS="${KCFLAGS} -D__ANDROID_COMMON_KERNEL__"
    export STOP_SHIP_TRACEPRINTK=1
    export IN_KERNEL_MODULES=1
    export DO_NOT_STRIP_MODULES=1
    export ABI_DEFINITION=android/abi_gki_aarch64.xml
    export KMI_SYMBOL_LIST=android/abi_gki_aarch64
    export ADDITIONAL_KMI_SYMBOL_LISTS="
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
    export TRIM_NONLISTED_KMI=0
    export KMI_SYMBOL_LIST_ADD_ONLY=1
    export KMI_SYMBOL_LIST_STRICT_MODE=0
    export KMI_ENFORCED=0

    echo "--------------------------------"
    echo "Target: $VARIANT (KSU Build)"
    echo "Toolchain: $(clang --version | head -n 1)"
    echo "--------------------------------"

    START=$(date +%s)
    COMREV=$(git rev-parse --verify HEAD --short)
    export LOCALVERSION="-$BRANCH-$KMI_GENERATION-$COMREV-rio-$VARIANT"

    make -j$JOBS -C "$SRC_DIR" O="$OUT_DIR" rio_defconfig ${VARIANT}.config
    make -j$JOBS -C "$SRC_DIR" O="$OUT_DIR"

    echo "Kernel Build took: $(date -u -d @$(($(date +%s) - START)) +'%T')"
}

gen_anykernel() {
    echo "--- Generating AnyKernel3 Zip (KSU) ---"
    AK3_DIR="$TC_DIR/RIO/$DEVICE/AnyKernel3_KSU"
    mkdir -p "$AK3_DIR"

    cp -af "$TC_DIR/AnyKernel3/"* "$AK3_DIR/"
    cp "$OUT_DIR/arch/arm64/boot/Image" "$AK3_DIR/"
    cp "$OUT_DIR/arch/arm64/boot/dtbo.img" "$AK3_DIR/"
    cp "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/yupik.dtb" "$AK3_DIR/dtb"

    (
        cd "$AK3_DIR"
        ZIP_NAME="Nova_KSU_$(date +%Y%m%d)_${VARIANT}.zip"
        zip -r9 "$ZIP_NAME" * -x .git README.md
        mkdir -p "$TC_DIR/RIO/FINAL"
        mv "$ZIP_NAME" "$TC_DIR/RIO/FINAL/"
    )
}

git switch susfs-rio
echo Setup RKSU+SUSFS
rm -rf KernelSU
rm -rf drivers/kernelsu
curl -LSs "https://raw.githubusercontent.com/rsuntk/KernelSU/main/kernel/setup.sh" | bash -s susfs-rksu-master
install_deps
fetch_tools
build_kernel "$1"
gen_anykernel
