# Environment Variables
CURRENT_DIR := $(shell pwd)
BUILD_DIR := $(CURRENT_DIR)/build
CONFIG_DIR := $(CURRENT_DIR)/config
NPROC := $(shell nproc)
CROSS_COMPILE := riscv64-linux-gnu-

# Qemu Variables
qemu_srcdir := $(CURRENT_DIR)/qemu
qemu_builddir := $(BUILD_DIR)/qemu/build
qemu_target := $(qemu_builddir)/qemu-system-riscv64
qemu_config_args := --target-list=riscv64-softmmu
qemu_machine := -machine virt,aia=aplic
qemu_args := -m 4G \
    		 -smp 4

# OpenSBI Variables
opensbi_srcdir := $(CURRENT_DIR)/opensbi
opensbi_builddir := $(BUILD_DIR)/opensbi
opensbi_config := $(CONFIG_DIR)/opensbi/qemu_virt_optee_defconfig
opensbi_bindir := $(opensbi_builddir)/platform/generic/firmware
opensbi_payload_bin := $(opensbi_bindir)/fw_payload.bin
opensbi_payload_elf := $(opensbi_bindir)/fw_payload.elf
opensbi_jump_bin := $(opensbi_bindir)/fw_jump.bin
opensbi_jump_elf := $(opensbi_bindir)/fw_jump.elf

# OP-TEE Variables
optee_os_srcdir := $(CURRENT_DIR)/optee_os
optee_os_builddir := $(BUILD_DIR)/optee_os
optee_os_bin := $(optee_os_builddir)/core/tee.bin
optee_os_elf := $(optee_os_builddir)/core/tee.elf
optee_os_tddram_start := 0x8e000000
optee_os_tddram_size := 0x00f00000

# DTS Variables
dts_file := $(CONFIG_DIR)/qemu_virt_optee.dts
dtb_file := $(BUILD_DIR)/qemu_virt_optee.dtb

###########
# help
###########
.PHONY: all help
all: help

help:
	@echo "Here is a list of make targets supported"
	@echo ""
	@echo "- qemu : build qemu"
	@echo "- qemu-clean : remove qemu build"
	@echo "- opensbi : build opensbi"
	@echo "- opensbi-clean : clean opensbi build"
	@echo "- optee_os : build optee_os"
	@echo "- optee_os-clean : clean optee_os build"
	@echo "- dts : dump DTS file from Qemu"
	@echo "- dtb : dump DTB file from Qemu"
	@echo "- dts-clean : remove DTS and DTB file"

###########
# qemu
###########
.PHONY: qemu
qemu: $(qemu_builddir)/config-host.mak
	$(MAKE) -C $(qemu_builddir) -j $(NPROC)

$(qemu_builddir)/config-host.mak:
	mkdir -p $(qemu_builddir)
	cd $(qemu_builddir) && \
		$(qemu_srcdir)/configure $(qemu_config_args)

###########
# opensbi
###########
.PHONY: opensbi
opensbi:
	mkdir -p $(opensbi_builddir)
	cp $(opensbi_config) $(opensbi_srcdir)/platform/generic/configs/
	$(MAKE) -C $(opensbi_srcdir) O=$(opensbi_builddir) \
	CROSS_COMPILE=$(CROSS_COMPILE) \
	PLATFORM=generic \
	PLATFORM_DEFCONFIG=qemu_virt_optee_defconfig \
	FW_TEXT_START=0x80000000 \
	FW_JUMP_ADDR=$(optee_os_tddram_start) \
	-j $(NPROC) && \
	rm $(opensbi_srcdir)/platform/generic/configs/qemu_virt_optee_defconfig

###########
# OT-TEE
###########
.PHONY: optee_os
optee_os:
	mkdir -p $(optee_os_builddir)
	$(MAKE) -C $(optee_os_srcdir) O=$(optee_os_builddir) \
	ARCH=riscv PLATFORM=virt \
	CFG_TEE_CORE_NB_CORE=4 CFG_NUM_THREADS=4 \
	-j $(NPROC)

###########
# DTS
###########
.PHONY: dts
dts: dtb
	dtc -I dtb -O dts -o $(dts_file) $(dtb_file)

dtb:
	$(qemu_target) \
	$(qemu_machine),dumpdtb=$(dtb_file) \
	$(qemu_args)

##########
# run
##########
.PHONY: run
run:
	$(qemu_target) $(qemu_machine) $(qemu_args) \
	-d guest_errors -D guest_log.txt \
	-bios $(opensbi_jump_bin) \
	-kernel $(optee_os_bin) \
	-device loader,file=$(opensbi_jump_bin),addr=0x80000000 \
	-device loader,file=$(optee_os_bin),addr=$(optee_os_tddram_start) \
	-dtb $(dtb_file) \
	-nographic

##########
# debug
##########
.PHONY: debug
debug:
	$(qemu_target) $(qemu_machine) $(qemu_args) \
	-bios $(opensbi_jump_bin) \
	-kernel $(optee_os_bin) \
	-device loader,file=$(opensbi_jump_elf),addr=0x80000000 \
	-device loader,file=$(optee_os_elf),addr=$(optee_os_tddram_start) \
	-dtb $(dtb_file) \
	-nographic \
	-s -S

##########
# clean
##########
.PHONY: qemu-clean qemu-distclean opensbi-clean dts-clean optee_os-clean
qemu-clean:
	$(MAKE) -C $(qemu_builddir) clean

qemu-distclean:
	rm -rf $(qemu_builddir)

opensbi-clean:
	rm -rf $(opensbi_builddir)

dts-clean:
	rm -f $(dts_file) $(dtb_file)

optee_os-clean:
	rm -rf $(optee_os_builddir)