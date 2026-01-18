#!/bin/env bash

set -e
set -o pipefail

# فحص وتثبيت الأدوات
check_dependencies() {
    for tool in git curl wget jq unzip tar lz4 gawk sed sha1sum md5sum bc; do
        if ! command -v "$tool" &> /dev/null; then
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

################################################ Clang
CLANGVER="clang-r530567"
CLANG_PREBUILT_BIN="$TC_DIR/$CLANGVER/bin/"
export PATH="$CLANG_PREBUILT_BIN:$PATH"

fetch_tools() {
    mkdir -p "$TC_DIR"
    if [[ ! -d "$CLANG_PREBUILT_BIN" ]]; then
        echo "  -> Downloading Clang..."
        URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/$CLANGVER.tar.gz"
        mkdir -p "$TC_DIR/$CLANGVER"
        wget -q "$URL" -O "$TC_DIR/clang.tar.gz"
        tar -xf "$TC_DIR/clang.tar.gz" -C "$TC_DIR/$CLANGVER"
    fi
    if [[ ! -d "$AK3_DIR" ]]; then
        echo "  -> Cloning AnyKernel3..."
        git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "$AK3_DIR"
    fi
}

fix_ksu_conflict() {
    echo "--- Patching Kconfig to remove KSU reference ---"
    # هذا الأمر يحذف سطر استدعاء KernelSU من ملف Kconfig الأساسي لمنع الخطأ الظاهر في الصورة
    sed -i '/drivers\/kernelsu\/Kconfig/d' "$SRC_DIR/drivers/Kconfig" || true
    # حذف أي إشارة في Makefile المجلد
    sed -i '/kernelsu/d' "$SRC_DIR/drivers/Makefile" || true
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
}

gen_zip() {
    local variant=$1
    echo "--- Creating AnyKernel3 Zip ---"
    cd "$AK3_DIR"
    rm -rf *.zip Image dtbo.img dtb modules/

    # جلب الملفات المطلوبة فقط
    cp "$OUT_DIR/arch/arm64/boot/Image" .
    [ -f "$OUT_DIR/arch/arm64/boot/dtbo.img" ] && cp "$OUT_DIR/arch/arm64/boot/dtbo.img" .
    # البحث عن ملف dtb الخاص بـ qcom yupik
    find "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom" -name "*.dtb" -exec cp {} ./dtb \; 2>/dev/null || echo "No DTB found"

    # تعديل anykernel.sh لتعطيل فحص الجهاز
    sed -i 's/do.devicecheck=1/do.devicecheck=0/g' anykernel.sh

    ZIP_NAME="AnyKernel3_RIO_${variant}_$(date +%Y%m%d).zip"
    zip -r9 "$ZIP_NAME" * -x .git/ .github/ LICENSE README.md
    mv "$ZIP_NAME" "$SRC_DIR/"
}

ENTRY() {
    VARIANT="${1:-}"
    [[ -z "$VARIANT" ]] && exit 1

    fetch_tools
    
    echo "--- Switching to branch: susfs-rio ---"
    git checkout susfs-rio || git switch susfs-rio

    fix_ksu_conflict
    build_kernel "$VARIANT"
    gen_zip "$VARIANT"

    echo "=== Finished for $VARIANT ==="
}
ENTRY "${1:-}"
    git checkout susfs-rio || git switch susfs-rio

    build_kernel "$VARIANT"
    gen_zip "$VARIANT"

    echo "=== Build Finished for $VARIANT ==="
}

ENTRY "${1:-}"
