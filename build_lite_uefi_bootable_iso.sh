#!/bin/bash

set -e

OUT_ISO_NAME="$(basename $(pwd)).iso"

SYSLINUX_SOURCE_URL='https://kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz'
SYSTEMD_BOOT_SOURCE_URL='https://github.com/ivandavidov/systemd-boot/releases/download/systemd-boot_26-May-2018/systemd-boot_26-May-2018.tar.xz'

PRJ_DIR=$(pwd)
DATA_DIR=$PRJ_DIR/data
SRC_DIR=$PRJ_DIR/src
WORK_DIR=$PRJ_DIR/work
ISOIMAGE=$PRJ_DIR/isoimage
SYSLINUX_SRC_DIR=$SRC_DIR/syslinux
SYSTEMD_BOOT_SRC_DIR=$SRC_DIR/systemd_boot

[[ $1 == clean ]] && rm -rf $PRJ_DIR/src/*

mkdir -p $SRC_DIR/
mkdir -p $WORK_DIR/
mkdir -p $ISOIMAGE/boot/syslinux

if [[ ! -f $SYSTEMD_BOOT_SRC_DIR/uefi_root/EFI/BOOT/BOOTx64.EFI ]]; then
  cd $SRC_DIR
  wget $SYSTEMD_BOOT_SOURCE_URL
  set +e 
  unxz systemd*.xz
  tar xvf systemd*.tar
  find -maxdepth 1 -type d -name "systemd*" -exec ln -sfn {} systemd_boot \;
  set -e
fi

if [[ ! -f $SYSLINUX_SRC_DIR/bios/core/isolinux.bin ]]; then
  cd $SRC_DIR/
  wget $SYSLINUX_SOURCE_URL
  set +e 
  unxz syslinux*.xz
  tar xvf syslinux*.tar
  find -maxdepth 1 -type d -name "syslinux*" -exec ln -sfn {} syslinux \;
  set -e 
fi

echo ">>[ARGV] SRC_DIR:   $SRC_DIR"
echo ">>[ARGV] WORK_DIR:  $WORK_DIR"
echo ">>[ARGV] ISIOIMAGE: $ISOIMAGE"
echo ">>[ARGV] SYSTEMD_BOOT_SRC_DIR:    $SYSTEMD_BOOT_SRC_DIR"
echo ">>[ARGV] SYSLINUX_SRC_DIR:        $SYSLINUX_SRC_DIR"
echo ">>[ARGV] OUT_ISO_NAME: $OUT_ISO_NAME"

cd $ISOIMAGE

echo ">>[GEN] uefi.img, $WORK_DIR/uefi.img"
set +e
umount $WORK_DIR/uefi.img 2>/dev/null
rm -f $WORK_DIR/uefi.img
mount | grep uefi && sleep 3
set -e

image_size=$((10*1024*1024))
truncate -s $image_size $WORK_DIR/uefi.img
echo "[GEN] $WORK_DIR/uefi.img image_size=$image_size"
LOOP_DEVICE_HDD=$(losetup -f)
losetup $LOOP_DEVICE_HDD $WORK_DIR/uefi.img
mkfs.vfat $LOOP_DEVICE_HDD

rm -rf $WORK_DIR/uefi
mkdir -p $WORK_DIR/uefi
mount $WORK_DIR/uefi.img $WORK_DIR/uefi

mkdir -p $WORK_DIR/uefi/EFI/BOOT
cp $SYSTEMD_BOOT_SRC_DIR/uefi_root/EFI/BOOT/BOOTx64.EFI $WORK_DIR/uefi/EFI/BOOT
mkdir -p $WORK_DIR/uefi/loader/entries


echo ">>[GEN] generate systemd_boot loader.conf"
cat << EOF > $WORK_DIR/uefi/loader/loader.conf
default x86_64
timeout 30
editor 1
EOF

cat << EOF > $WORK_DIR/uefi/loader/entries/x86_64_ttyS4.conf
title x86_64 (ttyS4)
version x86_64
efi /minimal/vmlinuz
options initrd=/minimal/rootfs.xz console=tty0 console=ttyS4,115200n8
EOF

#echo "[GEN] vmlinuz, initrd"
#echo ">>>FELIX: loader config"
#cat /boot/vmlinuz    > $WORK_DIR/uefi/minimal/vmlinuz
#cp $WORK_DIR/rootfs.cpio.xz $WORK_DIR/uefi/minimal/rootfs.xz
#cp $SRC_DIR/minimal_boot/uefi/loader/loader.conf $WORK_DIR/uefi/loader

#cp $SRC_DIR/minimal_boot/uefi/loader/loader.conf $WORK_DIR/uefi/loader
#cp $SRC_DIR/minimal_boot/uefi/loader/entries/*.conf $WORK_DIR/uefi/loader/entries
#cat $WORK_DIR/uefi/loader/loader.conf
#ls -l $WORK_DIR/uefi/loader/entries


echo ">>[COPY] customized data to uefi.img"
rm -rf $WORK_DIR/uefi/data
mkdir -p $WORK_DIR/uefi/data
[[ -d $DATA_DIR ]] && cp -rf $DATA_DIR/* $WORK_DIR/uefi/data


df -h
find $WORK_DIR/uefi/
umount $WORK_DIR/uefi.img 
ls -lh $WORK_DIR/uefi.img
cp $WORK_DIR/uefi.img $ISOIMAGE/boot/uefi.img

cd $ISOIMAGE
echo ">>[ENV] PWD: $(pwd)"
echo ">>[GEN] syslinux"
mkdir -p $ISOIMAGE/boot/syslinux
cp $SYSLINUX_SRC_DIR/bios/core/isolinux.bin                 $ISOIMAGE/boot/syslinux
cp $SYSLINUX_SRC_DIR/bios/com32/elflink/ldlinux/ldlinux.c32 $ISOIMAGE/boot/syslinux

xorriso -as mkisofs \
  -isohybrid-mbr $SYSLINUX_SRC_DIR/bios/mbr/isohdpfx.bin \
  -c boot/syslinux/boot.cat \
  -b boot/syslinux/isolinux.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
  -eltorito-alt-boot \
  -e boot/uefi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
  -o $SRC_DIR/$OUT_ISO_NAME \
  $ISOIMAGE

ls -lh $SRC_DIR/$OUT_ISO_NAME

#CI
cp $SRC_DIR/$OUT_ISO_NAME      /mnt/samba_121_22/$OUT_ISO_NAME
