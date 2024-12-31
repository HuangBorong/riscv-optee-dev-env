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
			 -object memory-backend-ram,size=2G,id=m0 \
    		 -object memory-backend-ram,size=2G,id=m1 \
    		 -numa node,nodeid=0,memdev=m0 \
    		 -numa node,nodeid=1,memdev=m1 \
    		 -smp 8,cores=4,sockets=2

# OpenSBI Variables
opensbi_srcdir := $(CURRENT_DIR)/opensbi
opensbi_builddir := $(BUILD_DIR)/opensbi
opensbi_config := $(CONFIG_DIR)/opensbi/qemu_virt_optee_defconfig
opensbi_bindir := $(opensbi_builddir)/platform/generic/firmware
opensbi_payload := $(opensbi_bindir)/fw_payload.bin
opensbi_payload_debug := $(opensbi_bindir)/fw_payload.elf

# DTS Variables
dts_file := $(CONFIG_DIR)/qemu_virt_optee.dts
dtb_file := $(BUILD_DIR)/qemu_virt_optee.dtb

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
	-j $(NPROC) && \
	rm $(opensbi_srcdir)/platform/generic/configs/qemu_virt_optee_defconfig

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
	-bios $(opensbi_payload) \
	-device loader,file=$(opensbi_payload),addr=0x80000000 \
	-dtb $(dtb_file) \
	-nographic

##########
# debug
##########
.PHONY: debug
debug:
	$(qemu_target) $(qemu_machine) \
	-bios $(opensbi_payload) \
	-device loader,file=$(opensbi_payload_debug),addr=0x80000000 \
	-dtb $(dtb_file) \
	-nographic \
	-s -S

##########
# clean
##########
.PHONY: qemu-clean qemu-distclean opensbi-clean dts-clean
qemu-clean:
	$(MAKE) -C $(qemu_builddir) clean

qemu-distclean:
	rm -rf $(qemu_builddir)

opensbi-clean:
	rm -rf $(opensbi_builddir)

dts-clean:
	rm -f $(dts_file) $(dtb_file)