import os
import subprocess
import shutil
import sys
from datetime import datetime

# --- الإعدادات الأساسية ---
VARIANT = sys.argv[1] if len(sys.argv) > 1 else "a73xq"
SRC_DIR = os.getcwd()
OUT_DIR = os.path.join(SRC_DIR, "out")
TC_DIR = os.path.join(os.path.expanduser("~"), "toolchains")
AK3_DIR = os.path.join(SRC_DIR, "AnyKernel3")
CLANG_VER = "clang-r530567"
CLANG_PATH = os.path.join(TC_DIR, CLANG_VER, "bin")

def run_cmd(cmd, cwd=None):
    """تنفيذ أوامر النظام مع بيئة معمارية arm64"""
    full_cmd = f"ARCH=arm64 LLVM=1 LLVM_IAS=1 PATH={CLANG_PATH}:{os.environ['PATH']} {cmd}"
    subprocess.run(full_cmd, shell=True, check=True, executable='/bin/bash', cwd=cwd)

def prepare_env():
    print("🚀 [1/4] تجهيز المترجم والأدوات...")
    os.makedirs(TC_DIR, exist_ok=True)
    if not os.path.exists(CLANG_PATH):
        url = f"https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/{CLANG_VER}.tar.gz"
        subprocess.run(f"mkdir -p {TC_DIR}/{CLANG_VER} && wget -q {url} -O {TC_DIR}/clang.tar.gz", shell=True)
        subprocess.run(f"tar -xf {TC_DIR}/clang.tar.gz -C {TC_DIR}/{CLANG_VER}", shell=True)
    
    if not os.path.exists(AK3_DIR):
        subprocess.run(f"git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git {AK3_DIR}", shell=True)

def package_kernel(label):
    """تغليف الكيرنل باستخدام AnyKernel3 وتسميته"""
    print(f"📦 [التغليف] جاري إنشاء ملف ZIP لنسخة: {label}...")
    img = os.path.join(OUT_DIR, "arch/arm64/boot", "Image")
    dtbo = os.path.join(OUT_DIR, "arch/arm64/boot", "dtbo.img")
    
    if not os.path.exists(img):
        raise FileNotFoundError(f"لم يتم العثور على Image في {img}")

    # تنظيف مجلد AnyKernel
    for item in ["Image", "dtbo.img", "dtb"]:
        path = os.path.join(AK3_DIR, item)
        if os.path.exists(path):
            if os.path.isdir(path): shutil.rmtree(path)
            else: os.remove(path)
    
    # نسخ الملفات
    shutil.copy2(img, AK3_DIR)
    if os.path.exists(dtbo):
        shutil.copy2(dtbo, AK3_DIR)
    
    # جلب الـ DTB
    dtb_dir = os.path.join(AK3_DIR, "dtb")
    os.makedirs(dtb_dir, exist_ok=True)
    dtb_src = os.path.join(OUT_DIR, "arch/arm64/boot/dts/vendor/qcom")
    if os.path.exists(dtb_src):
        for f in os.listdir(dtb_src):
            if f.endswith(".dtb"):
                shutil.copy2(os.path.join(dtb_src, f), dtb_dir)

    # ضغط الملف
    os.chdir(AK3_DIR)
    # تعطيل فحص الجهاز
    subprocess.run("sed -i 's/do.devicecheck=1/do.devicecheck=0/g' anykernel.sh", shell=True)
    
    date_str = datetime.now().strftime('%Y%m%d')
    zip_name = f"RIO_{label}_{VARIANT}_{date_str}.zip"
    subprocess.run(f"zip -r9 {zip_name} * -x .git/ .github/ LICENSE README.md", shell=True)
    shutil.move(zip_name, SRC_DIR)
    os.chdir(SRC_DIR)
    print(f"✅ تم إنتاج: {zip_name}")

def build_stage(branch, label, setup_resukisu=False):
    """تنفيذ مرحلة بناء كاملة"""
    print(f"\n🌟 === بدء المرحلة: {label} (الفرع: {branch}) ===")
    
    # 1. التبديل للفرع
    subprocess.run("git reset --hard HEAD && git clean -fd", shell=True)
    subprocess.run(f"git checkout -f {branch}", shell=True)
    
    # 2. إذا كانت نسخة sukisu، نفذ أوامر التثبيت الخاصة بها
    if setup_resukisu:
        print("🛠️ جاري تثبيت ReSukiSU...")
        subprocess.run("rm -rf KernelSU drivers/kernelsu", shell=True)
        subprocess.run('curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash -s builtin', shell=True)

    # 3. البناء
    os.makedirs(OUT_DIR, exist_ok=True)
    run_cmd(f"make -C {SRC_DIR} O={OUT_DIR} clean")
    run_cmd(f"make -C {SRC_DIR} O={OUT_DIR} rio_defconfig {VARIANT}.config")
    
    jobs = os.cpu_count()
    make_cmd = (
        f"make -j{jobs} -C {SRC_DIR} O={OUT_DIR} "
        f"CROSS_COMPILE=aarch64-linux-gnu- "
        f"CROSS_COMPILE_ARM32=arm-linux-gnueabi- "
        f"CC=clang"
    )
    run_cmd(make_cmd)
    
    # 4. التغليف
    package_kernel(label)

if __name__ == "__main__":
    try:
        prepare_env()
        
        # المرحلة الأولى: فرع main (GKI)
        build_stage(branch="main", label="GKI")
        
        # المرحلة الثانية: فرع susfs-rio (SUKISU)
        build_stage(branch="susfs-rio", label="SUKISU", setup_resukisu=True)
        
        print("\n🎉 تم بناء النسختين بنجاح!")
    except Exception as e:
        print(f"\n❌ فشلت العملية: {e}")
        sys.exit(1)
