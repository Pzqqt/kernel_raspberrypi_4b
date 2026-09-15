#!/usr/bin/bash

yellow='\033[0;33m'
white='\033[0m'
red='\033[0;31m'
gre='\e[0;32m'

cd ${0%/*}

DEFCONFIG=bcm2711_defconfig
OUTPUT_DIR=~/kr4b_release
TMP_MODULES=$(mktemp -d /tmp/kr4b_XXXXXX)
CLANG_PATH=~/build_toolchain/llvm-23.1.1-x86_64/bin

export KBUILD_BUILD_HOST="ubuntu"
export KBUILD_BUILD_USER="github"
export LOCALVERSION="-$(date +'%Y%m%d')"

export PATH=${CLANG_PATH}:${PATH}

make ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-O3 O=out mrproper
make ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-O3 O=out $DEFCONFIG

./scripts/config --file ./out/.config --set-str CONFIG_LOCALVERSION "-glow"

make ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-O3 O=out -j$(nproc --all)

if [ $? != 0 ]; then
	echo -e "$red << Failed to compile, fix the errors first >>$white"
	exit 1
fi

rm -rf ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}/overlays

cp ./out/arch/arm64/boot/Image.gz ${OUTPUT_DIR}/kernel8.img
cp ./out/arch/arm64/boot/dts/broadcom/*.dtb ${OUTPUT_DIR}/
cp ./out/arch/arm64/boot/dts/overlays/*.dtbo ${OUTPUT_DIR}/overlays/

# "Installation" module
sudo env PATH="$PATH" make -j$(nproc --all) \
    ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-O3 O=out \
    INSTALL_MOD_PATH="$TMP_MODULES" \
    modules_install

# The module was "installed" to the ${TMP_MODULES}/lib/modules/{kernel_version}
# Package and compress the {TMP_MODULES}/lib/modules/{kernel_version} directory into a tar.gz file
sudo tar -czf ${OUTPUT_DIR}/modules.tar.gz -C ${TMP_MODULES}/lib/modules . && sudo rm "$TMP_MODULES" -rf
