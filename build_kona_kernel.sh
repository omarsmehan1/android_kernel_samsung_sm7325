#!/bin/bash
set -e


#Inizialize SUBMODULES

if [ -f .gitmodules ]; then
  UNINITIALIZED_SUBMODULES=$(git submodule status | grep '^-' || true)
  
  if [ -n "$UNINITIALIZED_SUBMODULES" ]; then
    echo "The following submodules are missing or uninitialized:"
    echo "$UNINITIALIZED_SUBMODULES"
    echo "Initializing and cloning submodules..."
    git submodule update --init --recursive
    if [ $? -eq 0 ]; then
      echo "Submodules initialized and cloned successfully."
    else
      echo "Failed to clone submodules. Please check your repository configuration."
      exit 1
    fi
  else
    echo "All submodules are already initialized."
  fi
else
  echo "No submodules found in this repository."
fi


echo "=============================================="
echo "Which project you want to build?."
echo "=============================================="
echo "bloomxq"
echo "c1q"
echo "c2q"
echo "f2q"
echo "gts7l"
echo "gts7lwifi"
echo "gts7xl"
echo "gts7xlwifi"
echo "r8q"
echo "win2q"
echo "x1q"
echo "y2q"
echo "z3q"
echo "=============================================="
read -p " - Enter your choice: " model_choice

model_choice=$(echo "$model_choice" | tr '[:upper:]' '[:lower:]')

echo "=============================================="
echo "Which region you want to build? (Leave empty if you want to use default config)"
echo "=============================================="
echo "eur"
echo "kor"
echo "chn"
echo "usa"
echo "=============================================="
read -p " - Enter your choice: " region_choice

region_choice=$(echo "$region_choice" | tr '[:upper:]' '[:lower:]')

if [[ ! "$model_choice" =~ ^(r8q|gts7l|gts7lwifi|gts7xl|gts7xlwifi|f2q|bloomxq)$ && "$region_choice" = "eur" ]]; then
    echo "=============================================="
    echo "This project doesn't support EUR region."
    echo "=============================================="
    exit -1;
fi

echo "=============================================="
echo "Is this a debug build?."
echo "=============================================="
echo "yes"
echo "no (default)"
echo "=============================================="
read -p " - Enter your choice: " debug_choice

echo "=============================================="
echo "Would you like to use Snapdragon LLVM (proprietary)?."
echo "=============================================="
echo "yes"
echo "no (default)"
echo "=============================================="
read -p " - Enter your choice: " sdllvm_choice

echo "=============================================="
echo "Would you like add SuperUser (KSU) support?."
echo "=============================================="
echo "yes"
echo "no (default)"
echo "=============================================="
read -p " - Enter your choice: " ksu_choice

echo "=============================================="
echo "Current production build requires SDCardFS?."
echo "=============================================="
echo "yes"
echo "no (default)"
echo "=============================================="
read -p " - Enter your choice: " sdfs_choice

case ${debug_choice:0:1} in
    y|Y|YES|yes )
        NO_DEBUG_FS=true
    ;;
    * )
        NO_DEBUG_FS=false
    ;;
esac

case ${sdllvm_choice:0:1} in
    y|Y|YES|yes )
        USE_SDCLANG=true
    ;;
    * )
        USE_SDCLANG=false
    ;;
esac

case ${ksu_choice:0:1} in
    y|Y|YES|yes )
        INCLUDE_KSU=true
    ;;
    * )
        INCLUDE_KSU=false
    ;;
esac

case ${sdfs_choice:0:1} in
    y|Y|YES|yes )
        INCLUDE_SDFS=true
    ;;
    * )
        INCLUDE_SDFS=false
    ;;
esac

# Build paths. Must be defined before anything else
PRODUCT_OUT=out
BUILD_KERNEL_DIR=$(pwd)
BUILD_ROOT_DIR=$BUILD_KERNEL_DIR/..
BUILD_KERNEL_OUT_DIR=$PRODUCT_OUT/obj/KERNEL_OBJ

KERNEL_IMG=$BUILD_KERNEL_OUT_DIR/arch/arm64/boot/Image
DTBO_IMG=$BUILD_KERNEL_OUT_DIR/arch/arm64/boot/dtbo.img

if ! [ -d $BUILD_KERNEL_OUT_DIR ]; then
	mkdir -p $BUILD_KERNEL_OUT_DIR
fi

# Target properties
MODEL=$model_choice
REGION=$region_choice

CHIPSET_NAME=kona
KERNEL_ARCH=arm64

# Kona platform now belongs to platform 11
export PROJECT_NAME=${MODEL}
[ -z ${PLATFORM_VERSION} ] && export PLATFORM_VERSION=11

# Target build parameters
KERNEL_DEFCONFIG=vendor/a73xq_eur_open_defconfig

if [ -n "${REGION}" ]; then
VARIANT_DEFCONFIG=vendor/samsung/${MODEL}_${REGION}.config
else
VARIANT_DEFCONFIG=vendor/samsung/${MODEL}.config
fi

if [ "$NO_DEBUG_FS" != true ]; then
	DEBUG_DEFCONFIG=vendor/debugfs.config
fi

if [ "$INCLUDE_KSU" = true ]; then
	KSU_DEFCONFIG=vendor/ksu.config
else
	KSU_DEFCONFIG=vendor/nonksu.config
fi

if [ "$INCLUDE_SDFS" = true ]; then
	SDFS_DEFCONFIG=vendor/sdcardfs.config
fi

if [ "$ENG_DEBUG" = true ]; then
	ENG_DEFCONFIG=vendor/kona-sec-eng.config
fi

if [ "$USER_DEBUG" = true ]; then
	USRDBG_DEFCONFIG=vendor/kona-sec-usrdbg.config
fi

if [ "$USE_SDCLANG" = true ]; then
KERNEL_MAKE_ENV="CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm STRIP=llvm-strip OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump OBJSIZE=llvm-size READELF=llvm-readelf HOSTCXX=clang++ HOSTAR=llvm-ar HOSTLD=ld.lld DTC_OVERLAY_TEST_EXT=$BUILD_KERNEL_DIR/tools/ufdt_apply_overlay"
else
KERNEL_MAKE_ENV="LLVM=1 LLVM_IAS=1"
fi

BUILD_JOB_NUMBER=`grep processor /proc/cpuinfo|wc -l`

# Toolchain properties

# AOSP LLVM supports full LLVM=1 features while SD LLVM doesn't support HOSTCC=clang feature
if [ "$USE_SDCLANG" = true ]; then
    echo " - Using Snapdragon LLVM"
    PATH="/opt/qcom/Qualcomm_Snapdragon_LLVM_ARM_Toolchain_OEM/19.0.0.0/bin:${PATH}"
    KERNEL_LLVM_BIN=/opt/qcom/Qualcomm_Snapdragon_LLVM_ARM_Toolchain_OEM/19.0.0.0/bin/clang
    BUILD_CROSS_COMPILE=aarch64-linux-gnu-
    CLANG_TRIPLE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-
else
    echo " - Using AOSP LLVM"
    PATH="/opt/aosp/clang/clang-r530567/bin:${PATH}"
    KERNEL_LLVM_BIN=/opt/aosp/clang/clang-r530567/bin/clang
fi

FUNC_BUILD_KERNEL()
{
	local __dts_dir=${BUILD_KERNEL_OUT_DIR}/arch/${KERNEL_ARCH}/boot/dts

	echo ""
	echo "=============================================="
	echo "START : FUNC_BUILD_KERNEL"
	echo "=============================================="
	echo ""
	echo "build project="$PROJECT_NAME""
	echo "build common config="$KERNEL_DEFCONFIG ""
	echo "build variant config="$VARIANT_DEFCONFIG ""
	echo "build out directory="$PRODUCT_OUT ""
	echo "build extra fragments="$KSU_DEFCONFIG $SDFS_DEFCONFIG ""
	echo ""

# To-Do: Rework SDCLANG properties
if [ "$USE_SDCLANG" = true ]; then
	make -C $BUILD_KERNEL_DIR O=$BUILD_KERNEL_OUT_DIR  $KERNEL_MAKE_ENV ARCH=${KERNEL_ARCH} \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE \
			CC=$KERNEL_LLVM_BIN \
			CLANG_TRIPLE=$CLANG_TRIPLE \
			CROSS_COMPILE_ARM32=$CROSS_COMPILE_ARM32 \
			$KERNEL_DEFCONFIG \
			$DEBUG_DEFCONFIG \
			$VARIANT_DEFCONFIG \
			$KSU_DEFCONFIG \
			$SDFS_DEFCONFIG

	make -C $BUILD_KERNEL_DIR O=$BUILD_KERNEL_OUT_DIR -j$BUILD_JOB_NUMBER $KERNEL_MAKE_ENV ARCH=${KERNEL_ARCH} \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE \
			CC=$KERNEL_LLVM_BIN \
			CLANG_TRIPLE=$CLANG_TRIPLE \
			CROSS_COMPILE_ARM32=$CROSS_COMPILE_ARM32
else
	make -C $BUILD_KERNEL_DIR O=$BUILD_KERNEL_OUT_DIR  $KERNEL_MAKE_ENV ARCH=${KERNEL_ARCH} \
			$KERNEL_DEFCONFIG

	make -C $BUILD_KERNEL_DIR O=$BUILD_KERNEL_OUT_DIR -j$BUILD_JOB_NUMBER $KERNEL_MAKE_ENV ARCH=${KERNEL_ARCH}
fi

	cat ${__dts_dir}/vendor/qcom/*.dtb > $PRODUCT_OUT/dtb.img

    cp $DTBO_IMG $PRODUCT_OUT

    rsync -cv $KERNEL_IMG $PRODUCT_OUT/Image
    
    ls -al $PRODUCT_OUT/Image
    
	echo ""
	echo "================================="
	echo "END   : FUNC_BUILD_KERNEL"
	echo "================================="
	echo ""
}

FUNC_BUILD_BOOTIMG()
{
	BUILD_ENV=$BUILD_KERNEL_DIR/build_env/WORK_DIR
	TARGET=$BUILD_KERNEL_DIR/build_env/$MODEL

	BOOT_IMG_REPO="https://github.com/ata-kaner/r8q_archive/releases/download/stock_kernel/boot_r8q.img"

if ! [ -d $TARGET ]; then
	mkdir $TARGET
fi

if ! [ -f $BUILD_ENV/boot.img ]; then
  	echo "Downloading stock boot image"
	curl -L -s -o $BUILD_ENV/boot.img $BOOT_IMG_REPO
fi

	cd $BUILD_ENV

	./magiskboot-x86 unpack boot.img

    cp $BUILD_KERNEL_DIR/$PRODUCT_OUT/dtb.img ./dtb

    rsync -cv $BUILD_KERNEL_DIR/$PRODUCT_OUT/Image ./kernel	

	./magiskboot-x86 repack boot.img queen_$MODEL.img

if [ "$INCLUDE_KSU" != true ]; then
	rsync -cv ./queen_$MODEL.img $TARGET/boot.img
else
	rsync -cv ./queen_$MODEL.img $TARGET/boot_ksu.img
fi

	./magiskboot-x86 cleanup

	rm ./queen_$MODEL.img
}

(
	FUNC_BUILD_KERNEL
    FUNC_BUILD_BOOTIMG
)
