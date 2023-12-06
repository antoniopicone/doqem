#!/bin/bash

# Building kernel from source
wget -q https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.12.10.tar.xz
tar -xf linux-5.12.10.tar.xz
cd linux-5.12.10/
cp ../small_config .config
make olddefconfig
make -j$(nproc)
cp arch/x86/boot/bzImage ../kernel512b
cd ..
rm -f linux-5.12.10.tar.xz
rm -rf linux-5.12.10