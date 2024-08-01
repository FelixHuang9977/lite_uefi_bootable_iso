help: build_help test_help

build_help:
	@echo "Usage:"
	@echo "  make all           #build iso and execute CI script"
	@echo "  make iso           #build iso"
	@echo "  make clean         #clear build foder"
	@echo "  make ci            #execute CI script"

iso:
	./build_lite_uefi_bootable_iso.sh

ci:
	@echo "[RUN] ci.sh"
	@PRJ_DIR=$(shell pwd) BUILD_DIR="$(shell pwd)/BUILD/" OUT_ISO_NAME="$(shell basename $(shell pwd)).iso" bash ./ci.sh

all: iso ci

clean:
	./build_lite_uefi_bootable_iso.sh clean

test_help:
	@echo "Test:"
	@echo "  make test_add_auto_reboot                 #auto reboot test in uefi shell"
	@echo "  make hello                                #sample uefi app"

test_add_auto_reboot:
	@mkdir -p $(shell pwd)/BUILD/data/
	make BUILD_DATA_DIR=$(shell pwd)/BUILD/data/ -C SRC/auto_reboot_test_in_uefi_shell/