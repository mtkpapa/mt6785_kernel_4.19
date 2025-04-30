TARGET_DEVICE=$1
BUILD_DATE=$(date "+%Y%m%d-%H%M")

#ccache
export CCACHE_DIR="$HOME/.cache/ccache_mikernel"
export CC="ccache gcc"
export CXX="ccache g++"
export PATH="/usr/lib/ccache:$PATH"
echo "CCACHE_DIR: [$CCACHE_DIR]"

MAKE_ARGS="O=out \
CC=clang \
AR=llvm-ar \
NM=llvm-nm \
OBJDUMP=llvm-objdump \
STRIP=llvm-strip \
HOSTCC=clang \
HOSTCXX=clang++ \
LD=ld.lld \
CROSS_COMPILE=aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
LLVM=1 \
LLVM_IAS=1"

if [ ! -f "arch/arm64/configs/${TARGET_DEVICE}_defconfig" ]; then
    echo "No [${TARGET_DEVICE}] defconfig found."
    echo "Avaliable defconfigs:"
    ls arch/arm64/configs/*_defconfig
    exit 1
fi

KSU_ZIP_STR=noksu
if [ "$2" == "ksu" ]; then
    KSU_E=1
    KSU_ZIP_STR=ksu
else
    KSU_E=0
fi

#setting up AK
git clone https://github.com/mtkpapa/AnyKernel3 -b rosemary-4.19

if [ $KSU_E -eq 1 ]; then
    echo "dloading ksu & applying patches"
    curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next-susfs/kernel/setup.sh" | bash -s next-susfs
#    wget https://gist.githubusercontent.com/zainarbani/2b482e9e9c415a644953397b6ba5571f/raw/b66cf8d0683b5397fc1f7cc6b33ff12cc9bf9292/ksu.patch
#    git apply ksu.patch
else 
    echo "no ksu build"
fi

rm -rf out/

echo "-ChoynikAmogusSon" > localversion

#----------------------build shit here

echo "======= START OF BUILD ======="
make $MAKE_ARGS ${TARGET_DEVICE}_defconfig

if [ $KSU_E -eq 1 ]; then
    scripts/config --file out/.config -e KSU \
    -e KSU_SUSFS_HAS_MAGIC_MOUNT \
    -e KSU_SUSFS_SUS_PATH \
    -e KSU_SUSFS_SUS_MOUNT \
    -e KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT \
    -e KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT \
    -e KSU_SUSFS_SUS_KSTAT \
    -e KSU_SUSFS_SUS_OVERLAYFS \
    -e KSU_SUSFS_TRY_UMOUNT \
    -e KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT \
    -e KSU_SUSFS_SPOOF_UNAME \
    -e KSU_SUSFS_ENABLE_LOG \
    -e KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
    -e KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
    -e KSU_SUSFS_OPEN_REDIRECT \
    -e KSU_SUSFS_SUS_SU
else
	scripts/config --file out/.config -d KSU \
    -d KSU_SUSFS_HAS_MAGIC_MOUNT \
    -d KSU_SUSFS_SUS_PATH \
    -d KSU_SUSFS_SUS_MOUNT \
    -d KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT \
    -d KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT \
    -d KSU_SUSFS_SUS_KSTAT \
    -d KSU_SUSFS_SUS_OVERLAYFS \
    -d KSU_SUSFS_TRY_UMOUNT \
    -d KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT \
    -d KSU_SUSFS_SPOOF_UNAME \
    -d KSU_SUSFS_ENABLE_LOG \
    -d KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
    -d KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
    -d KSU_SUSFS_OPEN_REDIRECT \
    -d KSU_SUSFS_SUS_SU
fi

make $MAKE_ARGS -j$(nproc --all)

echo "======= BUILDING DTBO ======="
curl -s "https://android.googlesource.com/platform/system/libufdt/+/refs/heads/master/utils/src/mkdtboimg.py?format=TEXT" | base64 --decode > mkdtboimg.py
python3 mkdtboimg.py create AnyKernel3/dtbnew out/arch/arm64/boot/dts/mediatek/mt6785.dtb

echo "======= END OF BUILD ======="

KOUT_PATH="/mnt/d/users/juan/kernels/${TARGET_DEVICE}/"
ZIP_NAME="Choynik-$(date "+%Y%m%d-%H%M").zip"


if [ -f "out/arch/arm64/boot/Image.gz" ]; then
    echo "Image found. Build successful"
    cd AnyKernel3
	cp ../out/arch/arm64/boot/Image.gz Image.gz
	zip -r9 ../$ZIP_NAME -- *
	cd ..
	cp $ZIP_NAME $KOUT_PATH
	rm -rf $ZIP_NAME
else
    echo "Image not found. Pizdec blyat"
    exit 1
fi

echo "======= CLEANING UP ======="

rm -rf mkdtboimg.py
rm -rf KernelSU-Next/
rm -rf out/
rm -rf localversion
rm -rf AnyKernel3
