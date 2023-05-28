#!/bin/bash
#
# Based on compiling script for QuicksilveR kernel.
# This script does not include any module functionality, as everything is inlined.
# Copyright (C) 2020-2021 Adithya R.
# Copyright (C) 2023-202x rk134.

SECONDS=0 # builtin bash timer
ZIPNAME="GatoKernel-topaz-$(date '+%Y%m%d-%H%M').zip"
#TC_DIR="/home/rk134/aospa/kernel/kernel/work/tc/clang"
GCC_64_DIR="/home/rahul/aospa/prebuilts/gcc/gcc64" # to modify
GCC_32_DIR="/home/rahul/aospa/prebuilts/gcc/gcc32" # to modify
export PATH="$GCC_64_DIR/bin:$GCC_32_DIR/bin:$PATH"
AK3_DIR="AnyKernel3"
DEFCONFIG="vendor/lahaina-qgki_defconfig" # to modify

# Make arguments & parameters for clang-18
#MAKE_PARAMS="O=out ARCH=arm64 \
#	LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip LLVM=1 LLVM_IAS=1 \
#    CROSS_COMPILE=aarch64-linux-gnu- \
#    CROSS_COMPILE_COMPAT=arm-linux-gnueabi- "

# Make arguments and parameters for EvaGCC
MAKE_PARAMS="O=out ARCH=arm64 GCC_LTO=1 GRAPHITE=1 CC=aarch64-elf-gcc AR=aarch64-elf-ar NM=aarch64-elf-nm OBJCOPY=aarch64-elf-objcopy OBJDUMP=aarch64-elf-objdump LD=aarch64-elf-ld AS=aarch64-elf-as \
       CROSS_COMPILE=$GCC_64_DIR/bin/aarch64-elf- \
       CROSS_COMPILE_COMPAT=$GCC_32_DIR/bin/arm-eabi-"

# Regenerating defconfigs
if [[ $2 = "-sdr" || $1 = "--savedef-regen" ]]; then
	make $MAKE_PARAMS $DEFCONFIG savedefconfig
	cp out/.config arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
	exit
fi

if [[ $2 = "-fr" || $1 = "--full-regen" ]]; then
        make $MAKE_PARAMS $DEFCONFIG
        cp out/.config arch/arm64/configs/$DEFCONFIG
        echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
        exit
fi

if [[ $2 = "-dfr" || $1 = "--defregen" ]]; then
        make $MAKE_PARAMS $DEFCONFIG savedefconfig
        cp out/defconfig arch/arm64/configs/$DEFCONFIG
        echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
        exit

fi

if [[ $2 = "-mc" || $1 = "--menu-conf" ]]; then
        make $MAKE_PARAMS $DEFCONFIG menuconfig
        cp out/.config arch/arm64/configs/$DEFCONFIG
        echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
        exit

fi

if [[ $2 = "-c" || $1 = "--clean-output" ]]; then
	echo -e "\nCleaning output folder..."
	rm -rf out
fi

mkdir -p out
make $MAKE_PARAMS CC="ccache aarch64-elf-gcc" $DEFCONFIG # when sudo mount --bind /home/rahul/.cache /mnt/ccache && export USE_CCACHE=1 && export CCACHE_EXEC=/usr/bin/ccache && export CCACHE_DIR=/mnt/ccache && sudo ccache -M 10G -F 0

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) $MAKE_PARAMS CC="ccache aarch64-elf-gcc" || exit $?

kernel="out/arch/arm64/boot/Image"

if [ -f "$kernel" ]; then
	echo -e "\nKernel compiled succesfully! Zipping up...\n"
	if [ -d "$AK3_DIR" ]; then
		cp -r $AK3_DIR AnyKernel3
	elif ! git clone -q https://github.com/bheatleyyy/AnyKernel3; then
		echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
		exit 1
	fi
        COMPILED_IMAGE=out/arch/arm64/boot/Image
        COMPILED_DTBO=out/arch/arm64/boot/dtbo.img
        mv -f ${COMPILED_IMAGE} ${COMPILED_DTBO} AnyKernel3
        find out/arch/arm64/boot/dts/vendor -name '*.dtb' -exec cat {} + > AnyKernel3/dtb
	cd AnyKernel3
	zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
	cd ..
	rm -rf AnyKernel3
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
else
	echo -e "\nCompilation failed!"
	exit 1
fi
