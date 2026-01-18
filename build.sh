#!/bin/env bash

set -e
set -o pipefail

# فحص الأدوات الأساسية وتثبيتها إذا نقصت
check_dependencies() {
    for tool in git curl wget jq unzip tar lz4 gawk sed sha1sum md5sum; do
        if ! command -v "$tool" &> /dev/null; then
            echo "Installing missing tool: $tool"
            sudo apt-get install -y "$tool" || true
        fi
    done
}

check_dependencies

################################################ المتغيرات
SRC_DIR="$(pwd)"
OUT_DIR="$SRC_DIR/out"
TC_DIR="$HOME/toolchains"
AK3_DIR="$SRC_DIR/AnyKernel3"
JOBS=$(nproc)
export SRC_DIR OUT_DIR TC_DIR JOBS

################################################ أدوات البناء
CLANGVER="clang-r530567"
CLANG_PREBUILT_BIN="$TC_DIR/$CLANGVER/bin/"
export PATH="$CLANG_PREBUILT_BIN:$PATH"

fetch_tools() {
    mkdir -p "$TC_DIR"
    
    # تحميل Clang
    if [[ ! -d "$CLANG_PREBUILT_BIN" ]]; then
        echo "  -> Downloading Clang..."
        URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/$CLANGVER.tar.gz"
        mkdir -p "$TC_DIR/$CLANGVER"
        wget -q "$URL" -O "$TC_DIR/clang.tar.gz"
        tar -xf "$TC_DIR/clang.tar.gz" -C "$TC_DIR/$CLANGVER"
        rm "$TC_DIR/clang.tar.gz"
    fi

    # تحضير AnyKernel3
    if [[ ! -d "$AK3_DIR" ]]; then
        echo "  -> Cloning AnyKernel3..."
        git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "$AK3_DIR"
    fi
}

build_kernel() {
    local variant=$1
    export ARCH=arm64
    export LLVM=1
    export DEFCONF="rio_defconfig"
    export FRAG="${variant}.config"

    echo "--- Building Kernel for $variant ---"
    make -j$JOBS -C $SRC_DIR O=$OUT_DIR $DEFCONF $FRAG
    make -j$JOBS -C $SRC_DIR O=$OUT_DIR

    if [[ ! -f "$OUT_DIR/arch/arm64/boot/Image" ]]; then
        echo "Error: Kernel build failed!"
        exit 1
    fi
}

gen_zip() {
    local variant=$1
    echo "--- Creating AnyKernel3 Zip (Image + DTBO + DTB) for $variant ---"
    
    cd "$AK3_DIR"
    # تنظيف شامل قبل التجهيز
    rm -rf *.zip Image dtbo.img dtb modules/

    # 1. نسخ ملف الكيرنل الأساسي
    cp "$OUT_DIR/arch/arm64/boot/Image" .

    # 2. نسخ ملف dtbo.img (الذي طلبته)
    if [[ -f "$OUT_DIR/arch/arm64/boot/dtbo.img" ]]; then
        cp "$OUT_DIR/arch/arm64/boot/dtbo.img" .
    else
        echo "Warning: dtbo.img not found in build directory!"
    fi

    # 3. نسخ ملف dtb (الذي طلبته)
    if [[ -f "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/yupik.dtb" ]]; then
        cp "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/yupik.dtb" "./dtb"
    else
        echo "Warning: yupik.dtb not found!"
    fi

    # تعديل ملف anykernel.sh ليتناسب مع الملفات المضافة
    sed -i 's/do.devicecheck=1/do.devicecheck=0/g' anykernel.sh
    
    # ضغط الملف النهائي
    ZIP_NAME="AnyKernel3_RIO_${variant}_$(date +%Y%m%d).zip"
    zip -r9 "$ZIP_NAME" * -x .git/ .github/ LICENSE README.md
    
    mv "$ZIP_NAME" "$SRC_DIR/"
    echo "Successfully generated: $ZIP_NAME"
    cd "$SRC_DIR"
}

ENTRY() {
    VARIANT="${1:-}"
    [[ -z "$VARIANT" ]] && { echo "Usage: ./build.sh <a73xq|a52sxq|m52xq>"; exit 1; }

    fetch_tools
    
    # التبديل لفرع susfs-rio
    echo "--- Preparing branch: susfs-rio ---"
    git checkout susfs-rio || git switch susfs-rio

    build_kernel "$VARIANT"
    gen_zip "$VARIANT"

    echo "=== Build Finished for $VARIANT ==="
}

ENTRY "${1:-}"
