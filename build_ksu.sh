#!/bin/env bash
set -e
set -o pipefail

# --- 🎨 إعدادات الألوان والمظهر ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m' 

# --- 🌐 الثوابت والمسارات ---
AK3_REPO="https://github.com/omarsmehan1/AnyKernel3.git"
SRC_DIR="$(pwd)"
OUT_DIR="$SRC_DIR/out"
TC_DIR="$HOME/toolchains"
JOBS=$(nproc)

# --- 📢 وظائف الزينة والجمال ---
print_header() {
    echo -e "\n${PURPLE}==================================================${NC}"
    echo -e "${BLUE}  🚀 $1 ${NC}"
    echo -e "${PURPLE}==================================================${NC}\n"
}

# --- 📦 1. تثبيت الاعتمادات (إضافة aria2) ---
install_deps() {
    print_header "جاري تثبيت الأدوات والاعتمادات..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y git curl zip wget make gcc g++ bc libssl-dev aria2
}

# --- 🛠️ 2. جلب الأدوات (استخدام aria2c للسرعة القصوى) ---
fetch_tools() {
    print_header "جاري تجهيز بيئة البناء..."
    
    export PATH="$TC_DIR/clang-r530567/bin:$PATH"

    if [[ ! -d "$TC_DIR/clang-r530567" ]]; then
        mkdir -p "$TC_DIR/clang-r530567"
        echo -e "${YELLOW}-> تحميل Clang عبر 16 اتصال متزامن (aria2c)...${NC}"
        
        aria2c -x16 -s16 -k1M "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r530567.tar.gz" \
               -d "$TC_DIR" -o "clang.tar.gz"

        tar xf "$TC_DIR/clang.tar.gz" -C "$TC_DIR/clang-r530567"
        rm "$TC_DIR/clang.tar.gz"
    fi

    rm -rf "$TC_DIR/AnyKernel3"
    echo -e "${YELLOW}-> جاري جلب AnyKernel3...${NC}"
    git clone "$AK3_REPO" "$TC_DIR/AnyKernel3"
}

# --- 🏗️ 3. وظيفة البناء وترتيب GKI ---
build_kernel() {
    case "$1" in
        a73xq)  export VARIANT="a73xq";  export DEVICE="A73";;
        a52sxq) export VARIANT="a52sxq"; export DEVICE="A52S";;
        m52xq)  export VARIANT="m52xq";  export DEVICE="M52";;
        *) echo -e "${RED}❌ Unknown device: $1${NC}"; exit 1;;
    esac

    print_header "إعداد متغيرات GKI لـ $DEVICE..."

    # --- [A] أساسيات البناء ---
    export ARCH=arm64
    export BRANCH="android11"
    export LLVM=1
    export DEPMOD=depmod
    export KCFLAGS="${KCFLAGS} -D__ANDROID_COMMON_KERNEL__"

    # --- [B] إعدادات النواة (Core) ---
    export KMI_GENERATION=2
    export STOP_SHIP_TRACEPRINTK=1
    export IN_KERNEL_MODULES=1
    export DO_NOT_STRIP_MODULES=1

    # --- [C] واجهة الرموز (Symbols) ---
    export KMI_ENFORCED=0
    export TRIM_NONLISTED_KMI=0
    export KMI_SYMBOL_LIST_STRICT_MODE=0
    export KMI_SYMBOL_LIST_ADD_ONLY=1
    export ABI_DEFINITION=android/abi_gki_aarch64.xml
    export KMI_SYMBOL_LIST=android/abi_gki_aarch64

    # --- [D] القوائم الإضافية (منظمة) ---
    export ADDITIONAL_KMI_SYMBOL_LISTS=" \
        android/abi_gki_aarch64_cuttlefish \
        android/abi_gki_aarch64_db845c \
        android/abi_gki_aarch64_exynos \
        android/abi_gki_aarch64_exynosauto \
        android/abi_gki_aarch64_fcnt \
        android/abi_gki_aarch64_galaxy \
        android/abi_gki_aarch64_goldfish \
        android/abi_gki_aarch64_hikey960 \
        android/abi_gki_aarch64_imx \
        android/abi_gki_aarch64_oneplus \
        android/abi_gki_aarch64_microsoft \
        android/abi_gki_aarch64_oplus \
        android/abi_gki_aarch64_qcom \
        android/abi_gki_aarch64_sony \
        android/abi_gki_aarch64_sonywalkman \
        android/abi_gki_aarch64_sunxi \
        android/abi_gki_aarch64_trimble \
        android/abi_gki_aarch64_unisoc \
        android/abi_gki_aarch64_vivo \
        android/abi_gki_aarch64_xiaomi \
        android/abi_gki_aarch64_zebra"

    # --- [E] الملفات والنسخة ---
    export DEFCONF=rio_defconfig
    export FRAG="${VARIANT}.config"
    COMREV=$(git rev-parse --verify HEAD --short)
    export LOCALVERSION="-NovaKernel-KSU-$BRANCH-$KMI_GENERATION-$COMREV-$VARIANT"

    print_header "بدء بناء كيرنل $DEVICE..."
    echo -e "${YELLOW}Toolchain:${NC} $(clang --version | head -n 1)"
    
    START=$(date +%s)
    make -j$JOBS -C "$SRC_DIR" O="$OUT_DIR" $DEFCONF $FRAG
    make -j$JOBS -C "$SRC_DIR" O="$OUT_DIR"
    
    DIFF=$(( $(date +%s) - START ))
    echo -e "${GREEN}✔ تم البناء بنجاح في $((DIFF / 60)) دقيقة و $((DIFF % 60)) ثانية.${NC}"
}

# --- 📦 4. تجميع الملفات النهائي ---
gen_anykernel() {
    print_header "تجهيز حزمة AnyKernel3 النهائية..."
    AK3_DIR="$TC_DIR/RIO/work_ksu"
    rm -rf "$AK3_DIR"
    mkdir -p "$AK3_DIR"

    cp -af "$TC_DIR/AnyKernel3/"* "$AK3_DIR/"
    cp "$OUT_DIR/arch/arm64/boot/Image" "$AK3_DIR/"
    cp "$OUT_DIR/arch/arm64/boot/dtbo.img" "$AK3_DIR/"
    cp "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/yupik.dtb" "$AK3_DIR/dtb" 2>/dev/null || true

    echo -e "${GREEN}✔ الملفات جاهزة للرفع كـ Artifact.${NC}"
}

# --- 🚀 سير العمل الفعلي ---
git switch susfs-rio || git checkout susfs-rio
install_deps
fetch_tools

print_header "تثبيت KernelSU و SUSFS..."
rm -rf KernelSU drivers/kernelsu
curl -LSs "https://raw.githubusercontent.com/rsuntk/KernelSU/main/kernel/setup.sh" | bash -s susfs-rksu-master

build_kernel "$1"
gen_anykernel

print_header "🎉 انتهت العملية بنجاح!"
