#!/bin/env bash
set -e
set -o pipefail

# --- 🎨 Palette (إعدادات الألوان) ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' 

# --- 🌐 Paths & Vars ---
AK3_REPO="https://github.com/omarsmehan1/AnyKernel3.git"
SRC_DIR="$(pwd)"
OUT_DIR="$SRC_DIR/out"
TC_DIR="$HOME/toolchains"
JOBS=$(nproc)

export PATH="$TC_DIR/clang-r530567/bin:$PATH"

# --- ✨ اللمسة الإبداعية: لوحة معلومات الجهاز ---
display_target_banner() {
    local device_full_name=""
    case "$1" in
        a73xq)  device_full_name="SAMSUNG GALAXY A73 5G";;
        a52sxq) device_full_name="SAMSUNG GALAXY A52s 5G";;
        m52xq)  device_full_name="SAMSUNG GALAXY M52 5G";;
        *) device_full_name="UNKNOWN DEVICE";;
    esac

    echo -e "${CYAN}__________________________________________________________${NC}"
    echo -e "${WHITE}  _______  _______  _______  _______  ___      _______  ${NC}"
    echo -e "${WHITE} |       ||   _   ||       ||       ||   |    |       | ${NC}"
    echo -e "${WHITE} |    ___||  |_|  ||    ___||    ___||   |    |    ___| ${NC}"
    echo -e "${WHITE} |   | __ |       ||   | __ |   | __ |   |    |   |___  ${NC}"
    echo -e "${WHITE} |   ||  ||       ||   ||  ||   ||  ||   |___ |    ___| ${NC}"
    echo -e "${WHITE} |   |_| ||   _   ||   |_| ||   |_| ||       ||   |___  ${NC}"
    echo -e "${WHITE} |_______||__| |__||_______||_______||_______||_______| ${NC}"
    echo -e "${CYAN}__________________________________________________________${NC}"
    echo -e ""
    echo -e "${YELLOW}  TARGET PHONE : ${NC}${GREEN}$device_full_name${NC}"
    echo -e "${YELLOW}  VARIANT      : ${NC}${CYAN}$1${NC}"
    echo -e "${YELLOW}  DATE         : ${NC}${WHITE}$(date)${NC}"
    echo -e "${CYAN}__________________________________________________________${NC}\n"
}

# --- 📦 1. تثبيت الاعتمادات ---
install_deps() {
    display_target_banner "$1"
    echo -e "${BLUE}===> Installing System Dependencies...${NC}"
    sudo apt update && sudo apt install -y git curl zip wget make gcc g++ bc libssl-dev aria2
}

# --- 🛠️ 2. تحميل الأدوات (Turbo Mode) ---
fetch_tools() {
    echo -e "${BLUE}===> Fetching Toolchain (using aria2c for speed)...${NC}"
    if [[ ! -d "$TC_DIR/clang-r530567" ]]; then
        mkdir -p "$TC_DIR/clang-r530567"
        # تحميل Clang بـ 16 اتصال متزامن
        aria2c -x16 -s16 -k1M "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r530567.tar.gz" \
               -d "$TC_DIR" -o "clang.tar.gz"
        tar xf "$TC_DIR/clang.tar.gz" -C "$TC_DIR/clang-r530567"
        rm "$TC_DIR/clang.tar.gz"
    fi
    rm -rf "$TC_DIR/AnyKernel3"
    echo -e "${YELLOW}-> Cloning AnyKernel3...${NC}"
    git clone "$AK3_REPO" "$TC_DIR/AnyKernel3"
}

# --- 🧬 3. إعداد KernelSU ---
setup_ksu() {
    echo -e "${BLUE}===> Integrating KernelSU & SUSFS...${NC}"
    git switch susfs-rio || git checkout susfs-rio
    rm -rf KernelSU drivers/kernelsu
    curl -LSs "https://raw.githubusercontent.com/rsuntk/KernelSU/main/kernel/setup.sh" | bash -s susfs-rksu-master
}

# --- 🏗️ 4. بناء النواة (GKI Organized) ---
build_kernel() {
    display_target_banner "$1"
    case "$1" in
        a73xq)  export VARIANT="a73xq";;
        a52sxq) export VARIANT="a52sxq";;
        m52xq)  export VARIANT="m52xq";;
    esac

    echo -e "${PURPLE}===> Configuring GKI & Starting Build...${NC}"

    # --- إعدادات GKI المرتبة ---
    export ARCH=arm64
    export BRANCH="android11"
    export LLVM=1
    export DEPMOD=depmod
    export KCFLAGS="${KCFLAGS} -D__ANDROID_COMMON_KERNEL__"
    export KMI_GENERATION=2
    export STOP_SHIP_TRACEPRINTK=1
    export IN_KERNEL_MODULES=1
    export DO_NOT_STRIP_MODULES=1
    export KMI_ENFORCED=0
    export TRIM_NONLISTED_KMI=0
    export KMI_SYMBOL_LIST_STRICT_MODE=0
    export KMI_SYMBOL_LIST_ADD_ONLY=1
    export ABI_DEFINITION=android/abi_gki_aarch64.xml
    export KMI_SYMBOL_LIST=android/abi_gki_aarch64
    export ADDITIONAL_KMI_SYMBOL_LISTS="android/abi_gki_aarch64_cuttlefish android/abi_gki_aarch64_db845c android/abi_gki_aarch64_exynos android/abi_gki_aarch64_exynosauto android/abi_gki_aarch64_fcnt android/abi_gki_aarch64_galaxy android/abi_gki_aarch64_goldfish android/abi_gki_aarch64_hikey960 android/abi_gki_aarch64_imx android/abi_gki_aarch64_oneplus android/abi_gki_aarch64_microsoft android/abi_gki_aarch64_oplus android/abi_gki_aarch64_qcom android/abi_gki_aarch64_sony android/abi_gki_aarch64_sonywalkman android/abi_gki_aarch64_sunxi android/abi_gki_aarch64_trimble android/abi_gki_aarch64_unisoc android/abi_gki_aarch64_vivo android/abi_gki_aarch64_xiaomi android/abi_gki_aarch64_zebra"

    export DEFCONF=rio_defconfig
    export FRAG="${VARIANT}.config"
    COMREV=$(git rev-parse --verify HEAD --short)
    export LOCALVERSION="-NovaKernel-KSU-$BRANCH-$KMI_GENERATION-$COMREV-$VARIANT"

    START=$(date +%s)
    make -j$JOBS -C "$SRC_DIR" O="$OUT_DIR" $DEFCONF $FRAG
    make -j$JOBS -C "$SRC_DIR" O="$OUT_DIR"
    
    echo -e "\n${GREEN}✔ Build Successful in $(($(date +%s) - START)) seconds.${NC}"
}

# --- 🎁 5. التجميع النهائي ---
gen_anykernel() {
    # هذا السطر يحل مشكلة الخطأ الأصفر في GitHub Actions
    echo -e "${BLUE}===> Cleaning up Git metadata...${NC}"
    rm -rf "$SRC_DIR/KernelSU/.git" || true

    echo -e "${BLUE}===> Packaging Kernel into AnyKernel3...${NC}"
    AK3_DIR="$TC_DIR/RIO/work_ksu"
    rm -rf "$AK3_DIR" && mkdir -p "$AK3_DIR"
    cp -af "$TC_DIR/AnyKernel3/"* "$AK3_DIR/"
    cp "$OUT_DIR/arch/arm64/boot/Image" "$AK3_DIR/"
    cp "$OUT_DIR/arch/arm64/boot/dtbo.img" "$AK3_DIR/"
    
    # التأكد من نسخ ملف الـ DTB إذا وجد
    if [ -f "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/yupik.dtb" ]; then
        cp "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom/yupik.dtb" "$AK3_DIR/dtb"
    fi
    
    echo -e "${GREEN}✔ Final Directory is Ready for Upload.${NC}"
}


# --- 🚀 Main Control Logic ---
case "$1" in
    deps) install_deps "$2" ;;
    tools) fetch_tools ;;
    ksu) setup_ksu ;;
    build) build_kernel "$2" ;;
    pack) gen_anykernel ;;
    *) echo "Usage: $0 {deps|tools|ksu|build|pack}" ;;
esac
