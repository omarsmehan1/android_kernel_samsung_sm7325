#!/usr/bin/env python3

import os
import subprocess
import sys
from datetime import datetime

# ================== Helpers ==================

def run(cmd, cwd=None):
    print(f"[CMD] {cmd}")
    subprocess.run(
        cmd,
        shell=True,
        check=True,
        cwd=cwd,
        executable="/bin/bash",
        env=os.environ
    )

def die(msg):
    print(f"❌ {msg}")
    sys.exit(1)

# ================== Paths & Vars ==================

SRC_DIR = os.getcwd()
OUT_DIR = os.path.join(SRC_DIR, "out")
TC_DIR = os.path.join(os.path.expanduser("~"), "toolchains")
JOBS = os.cpu_count()

CLANG_VER = "clang-r530567"
CLANG_DIR = os.path.join(TC_DIR, CLANG_VER)
CLANG_BIN = os.path.join(CLANG_DIR, "bin")

KERNEL_NAME = os.environ.get("KERNEL_NAME", "RIO")

# ================== Checks ==================

def check_deps():
    tools = ["git", "curl", "wget", "tar", "awk", "sed"]
    missing = [t for t in tools if not shutil_which(t)]
    if missing:
        die(f"Missing tools: {' '.join(missing)}")

def shutil_which(cmd):
    return any(
        os.access(os.path.join(path, cmd), os.X_OK)
        for path in os.environ["PATH"].split(os.pathsep)
    )

# ================== Toolchain ==================

def fetch_clang():
    if os.path.isdir(CLANG_BIN):
        return

    os.makedirs(CLANG_DIR, exist_ok=True)
    url = (
        "https://android.googlesource.com/platform/prebuilts/"
        f"clang/host/linux-x86/+archive/refs/heads/main/{CLANG_VER}.tar.gz"
    )

    tarball = os.path.join(TC_DIR, f"{CLANG_VER}.tar.gz")
    print(f"⬇️  Downloading Clang {CLANG_VER}")
    run(f"wget -q {url} -O {tarball}")
    run(f"tar xf {tarball} -C {CLANG_DIR}")
    os.remove(tarball)

# ================== Kernel Build ==================

def build_kernel(variant):
    devices = {
        "a73xq": "A73",
        "a52sxq": "A52S",
        "m52xq": "M52",
    }

    if variant not in devices:
        die(f"Unknown device: {variant}")

    device = devices[variant]

    os.environ.update({
        "ARCH": "arm64",
        "LLVM": "1",
        "LLVM_IAS": "1",
        "BRANCH": "android11",
        "KMI_GENERATION": "2",
        "DEPMOD": "depmod",
        "KCFLAGS": os.environ.get("KCFLAGS", "") + " -D__ANDROID_COMMON_KERNEL__",
        "STOP_SHIP_TRACEPRINTK": "1",
        "IN_KERNEL_MODULES": "1",
        "DO_NOT_STRIP_MODULES": "1",
    })

    os.makedirs(OUT_DIR, exist_ok=True)

    comrev = subprocess.check_output(
        ["git", "rev-parse", "--short", "HEAD"],
        text=True
    ).strip()

    localversion = f"-{KERNEL_NAME}-android11-2-{comrev}-{variant}"
    os.environ["LOCALVERSION"] = localversion

    print("================================")
    print(f" Kernel Name : {KERNEL_NAME}")
    print(f" Device      : {device}")
    print(f" Variant     : {variant}")
    print(f" Toolchain   : {subprocess.getoutput('clang --version').splitlines()[0]}")
    print(f" LOCALVERSION: {localversion}")
    print("================================")

    run(f"make -j{JOBS} -C {SRC_DIR} O={OUT_DIR} rio_defconfig {variant}.config")
    run(f"make -j{JOBS} -C {SRC_DIR} O={OUT_DIR}")

# ================== Entry ==================

def main():
    if len(sys.argv) < 2:
        die("Usage: KERNEL_NAME=MyKernel build.py <a73xq|a52sxq|m52xq>")

    variant = sys.argv[1]

    os.environ["PATH"] = f"{CLANG_BIN}:{os.environ['PATH']}"

    check_deps()
    fetch_clang()

    run("git switch qcom_rio")
    build_kernel(variant)

    print("🎉 Build complete")

if __name__ == "__main__":
    main()
