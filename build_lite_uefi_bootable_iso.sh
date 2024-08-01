#!/bin/bash

set -e

UEFI_DISK_SIZE=$((2 * 1024 * 1024))  #this size should be larger than sum of kernel+initrd+rootdisk+customized-data
OUT_ISO_NAME="$(basename $(pwd)).iso"

SYSLINUX_SOURCE_URL='https://kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz'
SYSTEMD_BOOT_SOURCE_URL='https://github.com/ivandavidov/systemd-boot/releases/download/systemd-boot_26-May-2018/systemd-boot_26-May-2018.tar.xz'

PRJ_DIR=$(pwd)
DATA_DIR=$PRJ_DIR/data
BUILD_DIR=$PRJ_DIR/BUILD
BUILD_DATA_DIR=$PRJ_DIR/BUILD/data/
UEFI_BOOT_IMG_WORK_DIR=$BUILD_DIR/tmp_uefi_img/
UEFI_BOOT_IMG_FILE=$UEFI_BOOT_IMG_WORK_DIR/uefi.img
UEFI_BOOT_IMG_MOUNT_DIR=$UEFI_BOOT_IMG_WORK_DIR/mnt
ISOIMAGE_WORK_DIR=$BUILD_DIR/tmp_isoimage
SYSLINUX_SRC_DIR=$BUILD_DIR/syslinux
SYSTEMD_BOOT_SRC_DIR=$BUILD_DIR/systemd_boot
SYSTEMD_BOOT_BIN_ZIP=$PRJ_DIR/prebuilt_binary/systemd-boot_26-May-2018.tar.xz
SYSLINUX_BIN_ZIP=$PRJ_DIR/prebuilt_binary/syslinux-6.03.tar.xz

if [[ $1 == clean ]]; then
  echo "removed all build files"
  set +e
  umount $UEFI_BOOT_IMG_FILE 2>/dev/null
  umount $UEFI_BOOT_IMG_FILE 2>/dev/null
  rm -rf $BUILD_DIR
  #rm -rf $PRJ_DIR/isoimage/*
  #rm -f $UEFI_BOOT_IMG_FILE
  exit 0
fi

mkdir -p $BUILD_DIR
mkdir -p $BUILD_DATA_DIR
mkdir -p $ISOIMAGE_WORK_DIR/boot/syslinux
mkdir -p $UEFI_BOOT_IMG_WORK_DIR
mkdir -p $UEFI_BOOT_IMG_MOUNT_DIR

if [[ ! -f $SYSTEMD_BOOT_SRC_DIR/uefi_root/EFI/BOOT/BOOTx64.EFI ]]; then
  cd $BUILD_DIR
  if [[ -f $SYSTEMD_BOOT_BIN_ZIP ]]; then
    cp $SYSTEMD_BOOT_BIN_ZIP ./
  else
    wget $SYSTEMD_BOOT_SOURCE_URL
    exit 2
  fi

  set +e 
  unxz systemd*.xz
  tar xf systemd*.tar
  find -maxdepth 1 -type d -name "systemd*" -exec ln -sfn {} systemd_boot \;
  set -e
fi

if [[ ! -f $SYSLINUX_SRC_DIR/bios/core/isolinux.bin ]]; then
  cd $BUILD_DIR/
  if [[ -f $SYSLINUX_BIN_ZIP ]]; then
    cp $SYSLINUX_BIN_ZIP ./
  else
    wget $SYSLINUX_SOURCE_URL
    exit 2
  fi

  set +e 
  unxz syslinux*.xz
  tar xf syslinux*.tar
  find -maxdepth 1 -type d -name "syslinux*" -exec ln -sfn {} syslinux \;
  set -e 
fi

echo ">>[ARGV] BUILD_DIR:   $BUILD_DIR"

echo ">>[ARGV] UEFI_BOOT_IMG_WORK_DIR: $UEFI_BOOT_IMG_WORK_DIR"
echo ">>[ARGV] UEFI_BOOT_IMG_FILE: $UEFI_BOOT_IMG_FILE"
echo ">>[ARGV] UEFI_BOOT_IMG_MOUNT_DIR: $UEFI_BOOT_IMG_MOUNT_DIR"

echo ">>[ARGV] ISOIMAGE_WORK_DIR: $ISOIMAGE_WORK_DIR"
echo ">>[ARGV] SYSTEMD_BOOT_SRC_DIR:    $SYSTEMD_BOOT_SRC_DIR"
echo ">>[ARGV] SYSLINUX_SRC_DIR:        $SYSLINUX_SRC_DIR"
echo ">>[ARGV] OUT_ISO_NAME: $OUT_ISO_NAME"

cd $ISOIMAGE_WORK_DIR

echo ">>[GEN] uefi.img, $UEFI_BOOT_IMG_FILE"
set +e
umount $UEFI_BOOT_IMG_FILE 2>/dev/null
rm -f $UEFI_BOOT_IMG_FILE
mount | grep uefi && sleep 3
set -e

image_size=$((10*1024*1024))
image_size=$UEFI_DISK_SIZE
truncate -s $image_size $UEFI_BOOT_IMG_FILE
echo "[GEN] $UEFI_BOOT_IMG_FILE image_size=$image_size"
LOOP_DEVICE_HDD=$(losetup -f)
losetup $LOOP_DEVICE_HDD $UEFI_BOOT_IMG_FILE
mkfs.vfat $LOOP_DEVICE_HDD

rm -rf $UEFI_BOOT_IMG_MOUNT_DIR
mkdir -p $UEFI_BOOT_IMG_MOUNT_DIR
mount $UEFI_BOOT_IMG_FILE $UEFI_BOOT_IMG_MOUNT_DIR

mkdir -p $UEFI_BOOT_IMG_MOUNT_DIR/EFI/BOOT
cp $SYSTEMD_BOOT_SRC_DIR/uefi_root/EFI/BOOT/BOOTx64.EFI $UEFI_BOOT_IMG_MOUNT_DIR/EFI/BOOT
mkdir -p $UEFI_BOOT_IMG_MOUNT_DIR/loader/entries


echo ">>[GEN] generate systemd_boot loader.conf"
cat << EOF > $UEFI_BOOT_IMG_MOUNT_DIR/loader/loader.conf
default x86_64
timeout 30
editor 1
EOF

cat << EOF > $UEFI_BOOT_IMG_MOUNT_DIR/loader/entries/x86_64_ttyS4.conf
title x86_64 (ttyS4)
version x86_64
efi /minimal/vmlinuz
options initrd=/minimal/rootfs.xz console=tty0 console=ttyS4,115200n8
EOF

#echo "[GEN] vmlinuz, initrd"
#echo ">>>FELIX: loader config"
#cat /boot/vmlinuz    > $UEFI_BOOT_IMG_MOUNT_DIR/minimal/vmlinuz
#cp $BUILD_DIR/rootfs.cpio.xz $UEFI_BOOT_IMG_MOUNT_DIR/minimal/rootfs.xz
#cp $BUILD_DIR/minimal_boot/uefi/loader/loader.conf $UEFI_BOOT_IMG_MOUNT_DIR/loader

#cp $BUILD_DIR/minimal_boot/uefi/loader/loader.conf $UEFI_BOOT_IMG_MOUNT_DIR/loader
#cp $BUILD_DIR/minimal_boot/uefi/loader/entries/*.conf $UEFI_BOOT_IMG_MOUNT_DIR/loader/entries
#cat $UEFI_BOOT_IMG_MOUNT_DIR/loader/loader.conf
#ls -l $UEFI_BOOT_IMG_MOUNT_DIR/loader/entries


echo ">>[COPY] customized data ($UEFI_BOOT_IMG_MOUNT_DIR/data) to uefi.img"
set +e
rm -rf $UEFI_BOOT_IMG_MOUNT_DIR/data 2>/dev/null
mkdir -p $UEFI_BOOT_IMG_MOUNT_DIR/data
echo "  cp  $DATA_DIR/* to uefi.img"
[[ -d $DATA_DIR ]] && cp -rf $DATA_DIR/* $UEFI_BOOT_IMG_MOUNT_DIR/data/ 2>/dev/null
echo "  cp  $BUILD_DATA_DIR/* to uefi.img"
[[ -d $BUILD_DATA_DIR ]] && cp -rf $BUILD_DATA_DIR/* $UEFI_BOOT_IMG_MOUNT_DIR/data/ 2>/dev/null
set -e

df -h
find $UEFI_BOOT_IMG_MOUNT_DIR/
umount $UEFI_BOOT_IMG_FILE 
ls -lh $UEFI_BOOT_IMG_FILE
cp $UEFI_BOOT_IMG_FILE $ISOIMAGE_WORK_DIR/boot/uefi.img

cd $ISOIMAGE_WORK_DIR
echo ">>[GEN] cp isolinux"
mkdir -p $ISOIMAGE_WORK_DIR/boot/syslinux
cp $SYSLINUX_SRC_DIR/bios/core/isolinux.bin                 $ISOIMAGE_WORK_DIR/boot/syslinux
cp $SYSLINUX_SRC_DIR/bios/com32/elflink/ldlinux/ldlinux.c32 $ISOIMAGE_WORK_DIR/boot/syslinux

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
  -o $BUILD_DIR/$OUT_ISO_NAME \
  $ISOIMAGE_WORK_DIR

ls -lh $BUILD_DIR/$OUT_ISO_NAME

#CI
#if [[ -f $PRJ_DIR/ci.sh ]]; then 
#  export PRJ_DIR
#  export BUILD_DIR
#  export OUT_ISO_NAME
#  cd $PRJ_DIR
#  bash ci.sh
#fi
