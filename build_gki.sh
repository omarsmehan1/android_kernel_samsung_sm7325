#!/bin/env bash

set -e
set -o pipefail

# رابط مستودع AnyKernel3
AK3_REPO="https://github.com/osm0sis/AnyKernel3.git"

install_deps() {
    echo "--- Installing Dependencies ---"
    sudo apt update && sudo apt install -y git device-tree-compiler lz4 xz-utils zlib1g-dev openjdk-17-jdk gcc g++ python3 python-is-python3 p7zip-full android-sdk-libsparse-utils erofs-utils \
            default-jdk git gnupg flex bison gperf build-essential zip curl libc6-dev libncurses-dev libx11-dev libreadline-dev libgl1 libgl1-mesa-dev \
            python3 make sudo gcc g++ bc grep tofrodos python3-markdown libxml2-utils xsltproc zlib1g-dev python-is-python3 libc6-dev libtinfo6 \
            make repo cpio kmod openssl libelf-dev pahole libssl-dev libarchive-tools zstd rsync --fix-missing
    
    wget http://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2ubuntu0.1_amd64.deb
    sudo dpkg -i libtinfo5_6.3-2ubuntu0.1_amd64.deb || sudo apt-get install -f -y
    rm libtinfo5_6.3-2ubuntu0.1_amd64.deb
}

################################################ Vars
SRC_DIR="$(pwd)" OUT_DIR="$SRC_DIR/out" TC_DIR="$HOME/toolchains" JOBS=$(nproc)
export PATH="$TC_DIR/clang-r530567/bin:$PATH"

fetch_tools() {
    if [[ ! -d "$TC_DIR/clang-r530567" ]]; then
        mkdir -p "$TC_DIR/clang-r530567"
        AOSPTC_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r530567.tar.gz"
        echo "  -> Downloading Clang..."
        wget "$AOSPTC_URL" -O "$TC_DIR/clang.tar.gz"
        tar xf "$TC_DIR/clang.tar.gz" -C "$TC_DIR/clang-r530567"
        rm "$TC_DIR/clang.tar.gz"
    fi
    if [[ ! -d "$TC_DIR/AnyKernel3" ]]; then
        git clone "$AK3_REPO" "$TC_DIR/AnyKernel3"
    fi
}

build_kernel() {
    case "$1" in
        a73xq) export VARIANT="a73xq"; export DEVICE="A73";;
        a52sxq) export VARIANT="a52sxq"; export DEVICE="A52S";;
        m52xq) export VARIANT="m52xq"; export DEVICE="M52";;
        *) echo "Unknown device: $1"; exit 1;;
    esac

    export ARCH=arm64
    export LLVM=1
    make -j$JOBS -C $SRC_DIR O=$OUT_DIR rio_defconfig ${VARIANT}.config
    make -j$JOBS -C $SRC_DIR O=$OUT_DIR
}

gen_anykernel() {
    echo "--- Generating AnyKernel3 Zip (GKI) ---"
    AK3_DIR="$TC_DIR/RIO/$DEVICE/AnyKernel3_GKI"
    mkdir -p "$AK3_DIR"
    cp -af "$TC_DIR/AnyKernel3/"* "$AK3_DIR/"
    cp "$OUT_DIR/arch/arm64/boot/Image" "$AK3_DIR/"
    cp "$OUT_DIR/arch/arm64/boot/dtbo.img" "$AK3_DIR/"
    cp "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/yupik.dtb" "$AK3_DIR/dtb"
    
    ( cd "$AK3_DIR"
        ZIP_NAME="RIO_GKI_$(date +%Y%m%d)_${VARIANT}.zip"
        zip -r9 "$ZIP_NAME" * -x .git README.md
        mkdir -p "$TC_DIR/RIO/FINAL"
        mv "$ZIP_NAME" "$TC_DIR/RIO/FINAL/"
    )
}

install_deps
fetch_tools
git switch main || git checkout main
build_kernel "$1"
gen_anykernel

