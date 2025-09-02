BUILD_DATE=$(date "+%Y%m%d-%H%M")

#ccache
export CCACHE_DIR="$HOME/.cache/ccache_mikernel"
echo "CCACHE_DIR: [$CCACHE_DIR]"

MAKE_ARGS=(
    O=out
    "CC=ccache clang"
    "CXX=ccache clang++"
    AR=llvm-ar
    NM=llvm-nm
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
    LD=ld.lld
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    LLVM=1
    LLVM_IAS=1
)

local_version_str="-perf"
local_version_date_str="-z419-$(date +%Y%m%d)"

KSU_ZIP_STR=noksu
if [ "$2" == "ksu" ]; then
    KSU_E=1
    KSU_ZIP_STR=ksu
else
    KSU_E=0
fi

rm -rf out/
rm -rf AnyKernel3/

#setting up AK
git clone https://github.com/mtkpapa/AnyKernel3 -b rosemary-4.19

if [ $KSU_E -eq 1 ]; then
    echo "Downloading KernelSU-Next"
    curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -
else 
    echo "Building without KernelSU-Next"
fi

#----------------------build stuff here

echo "======= START OF BUILD ======="
make "${MAKE_ARGS[@]}" rosemary_defconfig

sed -i "s/${local_version_str}/${local_version_date_str}/g" out/.config

if [ $KSU_E -eq 1 ]; then
    scripts/config --file out/.config -e KSU
else
	scripts/config --file out/.config -d KSU
fi

make "${MAKE_ARGS[@]}" -j$(nproc --all)

curl -s "https://android.googlesource.com/platform/system/libufdt/+/refs/heads/master/utils/src/mkdtboimg.py?format=TEXT" | base64 --decode > mkdtboimg.py
python3 mkdtboimg.py create AnyKernel3/dtbnew out/arch/arm64/boot/dts/mediatek/mt6785.dtb

echo "======= END OF BUILD ======="

ZIP_NAME="OverHeat-Next-$(date "+%Y%m%d-%H%M").zip"

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
    echo "Image found. Build successful"
    cd AnyKernel3
	cp ../out/arch/arm64/boot/Image.gz-dtb Image.gz-dtb
	zip -r9 ../$ZIP_NAME -- *
	cd ..
	cp $ZIP_NAME ./
	rm -rf $ZIP_NAME
else
    echo "Image not found. Build failed!"
    exit 1
fi

echo "======= CLEANING UP ======="

rm -rf mkdtboimg.py && echo "  RM      mkdtboimg.py"
rm -rf KernelSU-Next/ && echo "  RM      KernelSU-Next"
rm -rf out/ && echo "  RM      out"
rm -rf AnyKernel3 && echo "  RM      AnyKernel3"
