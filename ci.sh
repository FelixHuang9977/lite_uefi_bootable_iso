#!/bin/bash

echo "[CI] PRJ_DIR=       $PRJ_DIR"
echo "[CI] BUILD_DIR=     $BUILD_DIR"
echo "[CI] OUT_ISO_NAME=  $OUT_ISO_NAME"
echo "[CI] iso: $BUILD_DIR/$OUT_ISO_NAME"

[[ -z $OUT_ISO_NAME ]] && echo "OUT_ISO_NAME not found" && exit 2
mount | grep samba_121_22 
if [[ $? -ne 0 ]]; then
  echo "mount foder(/mnt/samba_121_22/) for CI is not ready"
  exit 2
fi

#mount -t cifs //192.168.121.22/000_bios_auto_test /mnt/samba_121_22/ -o username=felix
echo "[CI] copy $OUT_ISO_NAME to /mnt/samba_121_22/$OUT_ISO_NAME"
cp $BUILD_DIR/$OUT_ISO_NAME      /mnt/samba_121_22/$OUT_ISO_NAME
ls -l /mnt/samba_121_22/$OUT_ISO_NAME
