#!/usr/bin/env python3
import os
import subprocess
import shutil
import sys
from datetime import datetime

# =========================
# التحقق من المتغيرات
# =========================
if len(sys.argv) < 2:
    print("❌ يجب تحديد الجهاز (مثال: a73xq)")
    sys.exit(1)

VARIANT = sys.argv[1]

# =========================
# المسارات
# =========================
SRC_DIR = os.getcwd()
OUT_DIR = os.path.join(SRC_DIR, "out")
TC_DIR = os.path.join(os.path.expanduser("~"), "toolchains")
AK3_DIR = os.path.join(SRC_DIR, "AnyKernel3")

CLANG_VER = "clang-r530567"
CLANG_PATH = os.path.join(TC_DIR, CLANG_VER, "bin")

DATE_STR = datetime.now().strftime("%Y%m%d")

# =========================
# البيئة (LLVM فقط)
# =========================
def get_env(localversion):
    env = os.environ.copy()

    env["PATH"] = f"{CLANG_PATH}:{env.get('PATH', '')}"

    env["ARCH"] = "arm64"
    env["LLVM"] = "1"
    env["LLVM_IAS"] = "1"

    # متغيرات GKI
    env["KMI_GENERATION"] = "2"
    env["DEPMOD"] = "depmod"
    env["STOP_SHIP_TRACEPRINTK"] = "1"
    env["IN_KERNEL_MODULES"] = "1"
    env["DO_NOT_STRIP_MODULES"] = "1"

    # تسمية النواة
    env["LOCALVERSION"] = localversion

    return env

def run_cmd(cmd, env, cwd=None):
    subprocess.run(
        cmd,
        shell=True,
        check=True,
        executable="/bin/bash",
        cwd=cwd,
        env=env
    )

# =========================
# تجهيز clang و AnyKernel3
# =========================
def prepare_env():
    print("🚀 تجهيز الأدوات...")

    os.makedirs(TC_DIR, exist_ok=True)

    if not os.path.exists(CLANG_PATH):
        print(f"⬇️ تنزيل {CLANG_VER} ...")
        url = (
            "https://android.googlesource.com/platform/prebuilts/"
            f"clang/host/linux-x86/+archive/refs/heads/main/{CLANG_VER}.tar.gz"
        )
        subprocess.run(
            f"mkdir -p {TC_DIR}/{CLANG_VER} && wget -q {url} -O {TC_DIR}/clang.tar.gz",
            shell=True,
            check=True
        )
        subprocess.run(
            f"tar -xf {TC_DIR}/clang.tar.gz -C {TC_DIR}/{CLANG_VER}",
            shell=True,
            check=True
        )

    if not os.path.exists(AK3_DIR):
        subprocess.run(
            f"git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git {AK3_DIR}",
            shell=True,
            check=True
        )

# =========================
# تنظيف AnyKernel3
# =========================
def clean_anykernel():
    for item in ["Image", "dtbo.img", "dtb"]:
        path = os.path.join(AK3_DIR, item)
        if os.path.exists(path):
            if os.path.isdir(path):
                shutil.rmtree(path)
            else:
                os.remove(path)

# =========================
# التغليف
# =========================
def package_kernel(label):
    print("📦 تغليف النواة...")

    img = os.path.join(OUT_DIR, "arch/arm64/boot/Image")
    dtbo = os.path.join(OUT_DIR, "arch/arm64/boot/dtbo.img")

    if not os.path.exists(img):
        raise FileNotFoundError("❌ ملف Image غير موجود")

    clean_anykernel()

    shutil.copy2(img, AK3_DIR)
    if os.path.exists(dtbo):
        shutil.copy2(dtbo, AK3_DIR)

    # DTB
    dtb_src = os.path.join(OUT_DIR, "arch/arm64/boot/dts/vendor/qcom")
    dtb_dst = os.path.join(AK3_DIR, "dtb")
    os.makedirs(dtb_dst, exist_ok=True)

    if os.path.exists(dtb_src):
        for f in os.listdir(dtb_src):
            if f.endswith(".dtb"):
                shutil.copy2(os.path.join(dtb_src, f), dtb_dst)

    os.chdir(AK3_DIR)
    subprocess.run(
        "sed -i 's/do.devicecheck=1/do.devicecheck=0/g' anykernel.sh",
        shell=True,
        check=True
    )

    zip_name = f"RIO_{label}_{VARIANT}_{DATE_STR}.zip"
    subprocess.run(
        f"zip -r9 {zip_name} * -x .git/ .github/ LICENSE README.md",
        shell=True,
        check=True
    )

    shutil.move(zip_name, SRC_DIR)
    os.chdir(SRC_DIR)

    print(f"✅ تم إنتاج: {zip_name}")

# =========================
# مرحلة البناء
# =========================
def build_stage(branch, label, setup_RKSU=False):
    print(f"\n🌟 بدء المرحلة: {label} ({branch})")

    subprocess.run("git reset --hard HEAD && git clean -fd", shell=True, check=True)
    subprocess.run(f"git checkout -f {branch}", shell=True, check=True)

    if setup_RKSU:
        print("🛠️ تثبيت RKSU...")
        subprocess.run("rm -rf KernelSU drivers/kernelsu", shell=True, check=True)
        subprocess.run(
            'curl -LSs "https://raw.githubusercontent.com/rsuntk/KernelSU/main/kernel/setup.sh" | bash -s susfs-rksu-master',
            shell=True,
            check=True
        )

    if os.path.exists(OUT_DIR):
        shutil.rmtree(OUT_DIR)
    os.makedirs(OUT_DIR, exist_ok=True)

    localversion = f"-RIO-{label}-{VARIANT}-{DATE_STR}"
    env = get_env(localversion)

    print("⚙️ إعداد config...")
    run_cmd(
        f"make -C {SRC_DIR} O={OUT_DIR} rio_defconfig {VARIANT}.config",
        env
    )

    jobs = os.cpu_count()
    print(f"🔨 بناء النواة ({jobs} threads, LLVM only)...")
    run_cmd(
        f"make -j{jobs} -C {SRC_DIR} O={OUT_DIR}",
        env
    )

    package_kernel(label)

# =========================
# التشغيل
# =========================
if __name__ == "__main__":
    try:
        prepare_env()

        build_stage(
            branch="main",
            label="GKI"
        )

        build_stage(
            branch="susfs-rio",
            label="RKSU",
            setup_RKSU=True
        )

        print("\n🎉 تم بناء جميع النسخ بنجاح")
    except Exception as e:
        print(f"\n❌ فشل البناء: {e}")
        sys.exit(1)
