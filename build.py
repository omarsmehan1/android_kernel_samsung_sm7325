import os
import subprocess
import shutil
import sys
from datetime import datetime

# --- الإعدادات ---
VARIANT = sys.argv[1] if len(sys.argv) > 1 else "a73xq"
SRC_DIR = os.getcwd()
OUT_DIR = os.path.join(SRC_DIR, "out")
TC_DIR = os.path.join(os.path.expanduser("~"), "toolchains")
AK3_DIR = os.path.join(SRC_DIR, "AnyKernel3")
CLANG_VER = "clang-r530567"
CLANG_PATH = os.path.join(TC_DIR, CLANG_VER, "bin")

def run_cmd(cmd, shell=True):
    """دالة لتشغيل أوامر النظام مع فحص الأخطاء"""
    try:
        subprocess.run(cmd, shell=shell, check=True, executable='/bin/bash')
    except subprocess.CalledProcessError as e:
        print(f"❌ خطأ أثناء تنفيذ: {cmd}\n{e}")
        sys.exit(1)

def prepare_env():
    print("🚀 تجهيز البيئة والأدوات...")
    os.makedirs(TC_DIR, exist_ok=True)
    
    # تحميل Clang
    if not os.path.exists(CLANG_PATH):
        print("  -> تحميل مترجم Clang...")
        url = f"https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/{CLANG_VER}.tar.gz"
        run_cmd(f"mkdir -p {TC_DIR}/{CLANG_VER} && wget -q {url} -O {TC_DIR}/clang.tar.gz")
        run_cmd(f"tar -xf {TC_DIR}/clang.tar.gz -C {TC_DIR}/{CLANG_VER}")
    
    # تحميل AnyKernel3
    if not os.path.exists(AK3_DIR):
        print("  -> تحميل AnyKernel3...")
        run_cmd(f"git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git {AK3_DIR}")

def setup_source():
    print(f"🌿 التبديل إلى فرع susfs-rio وإصلاح التضاربات...")
    # إجبار Git على التبديل وتجاهل أي تغييرات محليه في build.sh أو غيره
    run_cmd("git stash push --all || true")
    run_cmd("git checkout -f susfs-rio")

    # إصلاح مشكلة KSU في ملفات Kconfig و Makefile بذكاء (Pythonic Way)
    kconfig_path = os.path.join(SRC_DIR, "drivers", "Kconfig")
    makefile_path = os.path.join(SRC_DIR, "drivers", "Makefile")

    if os.path.exists(kconfig_path):
        with open(kconfig_path, 'r') as f:
            lines = f.readlines()
        with open(kconfig_path, 'w') as f:
            for line in lines:
                if "kernelsu" not in line.lower():
                    f.write(line)
        print("  ✅ تم تنظيف Kconfig من إشارات KSU.")

    if os.path.exists(makefile_path):
        with open(makefile_path, 'r') as f:
            lines = f.readlines()
        with open(makefile_path, 'w') as f:
            for line in lines:
                if "kernelsu" not in line.lower():
                    f.write(line)
        print("  ✅ تم تنظيف Makefile من إشارات KSU.")

def build_kernel():
    print(f"🛠️ بدء بناء الكيرنل لـ {VARIANT}...")
    env = os.environ.copy()
    env["PATH"] = f"{CLANG_PATH}:" + env["PATH"]
    env["ARCH"] = "arm64"
    env["LLVM"] = "1"
    env["LLVM_IAS"] = "1"

    jobs = os.cpu_count()
    
    # تنظيف وبناء
    run_cmd(f"make -C {SRC_DIR} O={OUT_DIR} clean")
    run_cmd(f"make -C {SRC_DIR} O={OUT_DIR} rio_defconfig {VARIANT}.config")
    
    make_cmd = (
        f"make -j{jobs} -C {SRC_DIR} O={OUT_DIR} "
        f"CROSS_COMPILE=aarch64-linux-gnu- "
        f"CROSS_COMPILE_ARM32=arm-linux-gnueabi- "
        f"CC=clang"
    )
    run_cmd(make_cmd)

def package():
    print("📦 تجميع الملفات في AnyKernel3...")
    img = os.path.join(OUT_DIR, "arch/arm64/boot", "Image")
    dtbo = os.path.join(OUT_DIR, "arch/arm64/boot", "dtbo.img")
    
    if not os.path.exists(img):
        print("❌ فشل البناء: ملف Image غير موجود!")
        sys.exit(1)

    # تجهيز مجلد AnyKernel
    os.chdir(AK3_DIR)
    for f in ["Image", "dtbo.img", "dtb"]:
        if os.path.exists(f): 
            if os.path.isdir(f): shutil.rmtree(f)
            else: os.remove(f)
    
    shutil.copy2(img, AK3_DIR)
    if os.path.exists(dtbo):
        shutil.copy2(dtbo, AK3_DIR)
    
    # جلب الـ DTBs
    os.makedirs("dtb", exist_ok=True)
    dtb_src = os.path.join(OUT_DIR, "arch/arm64/boot/dts/vendor/qcom")
    for file in os.listdir(dtb_src):
        if file.endswith(".dtb"):
            shutil.copy2(os.path.join(dtb_src, file), "dtb/")

    # تعديل anykernel.sh
    with open("anykernel.sh", 'r') as f:
        content = f.read()
    content = content.replace("do.devicecheck=1", "do.devicecheck=0")
    with open("anykernel.sh", 'w') as f:
        f.write(content)

    # ضغط الملف
    zip_name = f"AnyKernel3_RIO_{VARIANT}_{datetime.now().strftime('%Y%m%d')}.zip"
    run_cmd(f"zip -r9 {zip_name} * -x .git/ .github/ LICENSE README.md")
    shutil.move(zip_name, SRC_DIR)
    print(f"✅ تم البناء بنجاح: {zip_name}")

if __name__ == "__main__":
    prepare_env()
    setup_source()
    build_kernel()
    package()
