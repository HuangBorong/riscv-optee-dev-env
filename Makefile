# Environment Variables
CURRENT_DIR := $(shell pwd)
BUILD_DIR := $(CURRENT_DIR)/build
NPROC := $(shell nproc)

# Qemu Variables
qemu_srcdir := $(CURRENT_DIR)/qemu
qemu_builddir := $(BUILD_DIR)/qemu/build
qemu_target := $(qemu_builddir)/qemu-system-riscv64
qemu_config_args := --target-list=riscv64-softmmu
qemu_machine := -machine virt,aia=aplic \
				-smp 4 \
				-m 4096

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

##########
# run
##########
.PHONY: run
run:
	$(qemu_target) $(qemu_machine) \
	-nographic

##########
# debug
##########
.PHONY: debug
debug:
	$(qemu_target) $(qemu_machine) \
	-nographic \
	-s -S

##########
# clean
##########
.PHONY: qemu-clean qemu-distclean
qemu-clean:
	$(MAKE) -C $(qemu_builddir) clean

qemu-distclean:
	rm -rf $(qemu_builddir)