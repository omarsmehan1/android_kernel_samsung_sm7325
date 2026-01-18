#!/bin/env bash

set -e
set -o pipefail

# فحص الأدوات المطلوبة قبل البدء
check_dependencies() {
    local missing=false
    for tool in git curl wget jq unzip tar lz4 awk sed sha1sum md5sum; do
        if ! command -v "$tool" &> /dev/null; then
            echo "Error: Required tool '$tool' is not installed."
            missing=true
        fi
    done
    if $missing; then
        echo "Exiting due to missing dependencies." >&2
        exit 1
    fi
}

check_dependencies

################################################ المتغيرات الأساسية
USR_NAME="$(whoami)" 
SRC_DIR="$(pwd)" 
OUT_DIR="$SRC_DIR/out" 
TC_DIR="$HOME/toolchains" 
JOBS=$(nproc)

export USR_NAME SRC_DIR OUT_DIR TC_DIR JOBS

################################################ أدوات البناء (Clang)
CLANGVER="clang-r530567" 
CLANG_PREBUILT_BIN="$TC_DIR/$CLANGVER/bin/"
export CLANGVER CLANG_PREBUILT_BIN
export PATH="$TC_DIR:$CLANG_PREBUILT_BIN:$PATH"

################################################ الوظائف المساعدة
fetch_tools() {
    # تحميل Clang
    if [[ ! -d "$CLANG_PREBUILT_BIN" ]]; then
        mkdir -p "$TC_DIR/$CLANGVER"
        AOSPTC_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/$CLANGVER.tar.gz"
        echo "  -> Downloading Clang toolchain ($CLANGVER)..."
        [ ! -f "$TC_DIR/$CLANGVER.tar.gz" ] && wget "$AOSPTC_URL" -P "$TC_DIR"
        tar xf "$TC_DIR/$CLANGVER.tar.gz" -C "$TC_DIR/$CLANGVER"
        rm "$TC_DIR/$CLANGVER.tar.gz"
    fi

    # تحميل Magiskboot لمعالجة الصور
    if [[ ! -f "$TC_DIR/magiskboot" ]]; then
        APK_URL="$(curl -s "https://api.github.com/repos/topjohnwu/Magisk/releases" | grep -oE 'https://[^\"]+\.apk' | grep 'Magisk[-.]v' | head -n 1)"
        echo "  -> Downloading Magisk..."
        [ ! -f "$TC_DIR/magisk.apk" ] && wget "$APK_URL" -P "$TC_DIR" -O "$TC_DIR/magisk.apk"
        unzip -p "$TC_DIR/magisk.apk" "lib/x86_64/libmagiskboot.so" > "$TC_DIR/magiskboot"
        chmod +x "$TC_DIR/magiskboot"
        mkdir -p "$TC_DIR/magisk"
        unzip -p "$TC_DIR/magisk.apk" "assets/stub.apk" > "$TC_DIR/magisk/stub.apk"
        unzip -p "$TC_DIR/magisk.apk" "lib/arm64-v8a/libinit-ld.so" > "$TC_DIR/magisk/init-ld"
        unzip -p "$TC_DIR/magisk.apk" "lib/arm64-v8a/libmagiskinit.so" > "$TC_DIR/magisk/magiskinit"
        unzip -p "$TC_DIR/magisk.apk" "lib/arm64-v8a/libmagisk.so" > "$TC_DIR/magisk/magisk"
    fi

    # تحميل avbtool و الصور الأصلية
    if [[ ! -f "$TC_DIR/avbtool" ]]; then
        AVBTOOL_URL="https://android.googlesource.com/platform/external/avb/+/refs/heads/main/avbtool.py?format=TEXT"
        curl -s "$AVBTOOL_URL" | base64 --decode > "$TC_DIR/avbtool"
        chmod +x "$TC_DIR/avbtool"
    fi

    if [[ ! -d "$TC_DIR/images" ]]; then
        mkdir -p "$TC_DIR/images"
        declare -A d
        d["A73"]="ngdplnk/proprietary_vendor_samsung_a73xq"
        d["A52S"]="RisenID/proprietary_vendor_samsung_a52sxq"
        d["M52"]="ngdplnk/proprietary_vendor_samsung_m52xq"
        for n in "${!d[@]}"; do
            mkdir -p "$TC_DIR/images/$n"
            wget -qO- "$(curl -s "https://api.github.com/repos/${d[$n]}/releases/latest" | jq -r '.assets[] | select(.name | test(".*_kernel.tar$")) | .browser_download_url')" | tar xf - -C "$TC_DIR/images/$n" && lz4 -dm --rm "$TC_DIR/images/$n/"*
        done
    fi
}

# (ملاحظة: وظائف build_kernel و build_modules و gki_repack و mag_repack و gen_pack تظل كما هي في السكربت الأصلي لديك)
# سأضع هنا وظيفة ENTRY المعدلة التي تربط كل شيء:

# ... (بقية الوظائف build_kernel, build_modules, إلخ) ...

ENTRY() {
    if [[ "$1" == "clean" ]]; then
        echo "--- Cleaning ---"
        rm -rf "$OUT_DIR" "$TC_DIR/RIO"
        exit 0
    fi

    DEBUG=false
    VARIANT="${1:-}"
    [[ -z "$VARIANT" ]] && { echo "Usage: $0 <a73xq|a52sxq|m52xq> | clean"; exit 1; }

    echo "=== Building for $VARIANT ==="
    fetch_tools
    
    # إدارة الفروع
    echo "--- Preparing source branches ---"
    git checkout main || echo "Main branch not found."
    echo "--- Switching to build branch: susfs-rio ---"
    git checkout susfs-rio || git switch susfs-rio

    echo "--- Building Kernel (GKI + SUSFS) ---"
    build_kernel "$VARIANT"
    build_modules gki
    
    gen_artifact
    gki_repack gki

    echo "--- Packaging Final Images ---"
    mag_repack
    gen_pack

    echo "=== Build complete for $VARIANT ==="
}
ENTRY "${1:-}"

