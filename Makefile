################################################################################
# Paths to git projects and various binaries
################################################################################
CCACHE ?= $(shell which ccache) # Don't remove this comment (space is needed)

ROOT				?= $(PWD)
OUT_PATH			?= $(ROOT)/out

BINARIES_PATH			?= $(ROOT)/out/bin
BUILD_PATH			?= $(ROOT)/build
FUN_SIM_PATH			?= $(ROOT)/fun_sim
GOOGLETEST_PATH			?= $(ROOT)/googletest
GOOGLETEST_OUT			?= $(GOOGLETEST_PATH)/build
GOOGLETEST_LIB_DIR		?= $(GOOGLETEST_OUT)/lib
GOOGLETEST_LIB			?= $(GOOGLETEST_LIB_DIR)/libgtest.a
GOOGLETEST_INCLUDE_DIR		?= $(GOOGLETEST_PATH)/googletest/include
LINUX_PATH			?= $(ROOT)/linux
MODULE_OUTPUT			?= $(OUT_PATH)/kernel_modules
NTL_PATH			?= $(ROOT)/ntl

DEBUG				?= n
CCACHE_DIR			?= $(HOME)/.ccache

# Configuration
CFG_ENABLE_NTL_TESTS		?= n
CFG_ENABLE_GTESTS		?= y

# Use x86 gcc by default
CROSS_COMPILE_PREFIX		?=
ifeq ($(ARCH),arm64)
	CROSS_COMPILE_PREFIX		:= aarch64-linux-gnu-
endif

# Binaries and general files
LIBNTL_A			?= $(OUT_PATH)/ntl/lib/libntl.a

################################################################################
# Sanity checks
################################################################################
# This project and Makefile is based around running it from the root folder. So
# to avoid people making mistakes running it from the "build" folder itself add
# a sanity check that we're indeed are running it from the root.
ifeq ($(wildcard ./.repo), )
$(error Make should be run from the root of the project!)
endif

################################################################################
# Targets
################################################################################
TARGET_DEPS := build fun-sim ntl

ifeq ($(CFG_ENABLE_GTESTS),y)
TARGET_DEPS += googletest
endif

.PHONY: all
all: $(TARGET_DEPS)

# build each sub project sequencially but still enable parallel builds in the 
# subprojects.
.NOTPARALLEL:

################################################################################
# NTL
################################################################################
ntl-configure:
	if [ ! -f $(NTL_PATH)/include/NTL/config.h ]; then \
		cd $(NTL_PATH)/src && ./configure PREFIX=$(OUT_PATH)/ntl; \
	fi

ntl-tests: ntl-compile
ifeq ($(CFG_ENABLE_NTL_TESTS),y)
	$(MAKE) -C $(NTL_PATH)/src check
endif

ntl-install: ntl-compile
	$(MAKE) -C $(NTL_PATH)/src install

ntl-compile: ntl-configure
	$(MAKE) -C $(NTL_PATH)/src CXX="$(CCACHE)g++"

ntl: ntl-configure ntl-tests ntl-install ntl-compile

ntl-clean:
	rm -rf $(OUT_PATH)/ntl
	cd $(NTL_PATH) && git clean -xdf

################################################################################
# Googletest
################################################################################
$(GOOGLETEST_LIB): googletest/CMakeLists.txt
	@echo "\nBuilding Googletest\n"
	$(VB)mkdir -p $(GOOGLETEST_OUT);
	$(VB)cd $(GOOGLETEST_OUT); \
		cmake -DCMAKE_C_COMPILER="gcc" \
		-DCMAKE_CXX_COMPILER="g++" .. && \
		$(MAKE)

googletest: $(GOOGLETEST_LIB)

googletest-clean:
	rm -rf $(GOOGLETEST_OUT)

################################################################################
# fun_sim
################################################################################
fun-sim: ntl
	cd $(FUN_SIM_PATH) && scons -j8

fun-sim-clean:
	cd $(FUN_SIM_PATH) && git clean -xdf

################################################################################
# Linux kernel
################################################################################
ifeq ($(ARCH),arm64)
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
	$(LINUX_PATH)/arch/arm64/configs/defconfig
else
LINUX_DEFCONFIG_COMMON_ARCH := x86
LINUX_DEFCONFIG_COMMON_FILES := \
	$(LINUX_PATH)/arch/x86/configs/x86_64_defconfig
endif

LINUX_COMMON_FLAGS ?= LOCALVERSION=
LINUX_CLEAN_COMMON_FLAGS += ARCH=$(LINUX_DEFCONFIG_COMMON_ARCH)

linux: linux-common
	mkdir -p $(BINARIES_PATH)
	#ln -sf $(LINUX_PATH)/arch/arm64/boot/Image $(BINARIES_PATH)

.PHONY: linux-common
linux-common: linux-defconfig
	$(MAKE) -C $(LINUX_PATH) CROSS_COMPILE="$(CCACHE)$(CROSS_COMPILE_PREFIX)" $(LINUX_COMMON_FLAGS)

$(LINUX_PATH)/.config: $(LINUX_DEFCONFIG_COMMON_FILES)
	cd $(LINUX_PATH) && \
		ARCH=$(LINUX_DEFCONFIG_COMMON_ARCH) \
		CROSS_COMPILE="$(CCACHE)$(CROSS_COMPILE_PREFIX)" \
		scripts/kconfig/merge_config.sh $(LINUX_DEFCONFIG_COMMON_FILES)

linux-defconfig: $(LINUX_PATH)/.config

linux-modules: linux
	$(MAKE) -C $(LINUX_PATH) CROSS_COMPILE="$(CCACHE)$(CROSS_COMPILE_PREFIX)" $(LINUX_COMMON_FLAGS) modules
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(MODULE_OUTPUT) modules_install

linux-defconfig-clean: linux-defconfig-clean-common

.PHONY: linux-defconfig-clean-common
linux-defconfig-clean-common:
	rm -f $(LINUX_PATH)/.config

.PHONY: linux-clean-common
linux-clean-common: linux-defconfig-clean
	$(MAKE) -C $(LINUX_PATH) $(LINUX_CLEAN_COMMON_FLAGS) clean

.PHONY: linux-cleaner-common
linux-cleaner-common: linux-defconfig-clean
	$(MAKE) -C $(LINUX_PATH) $(LINUX_CLEANER_COMMON_FLAGS) distclean

#################################################################################
# Helper targets
#################################################################################
$(OUT_PATH):
	mkdir -p $@


#################################################################################
# Run targets
#################################################################################
.PHONY: ctxtAdd
ctxtAdd: fun-sim
	cd $(FUN_SIM_PATH) && ./build/examples/ctxtAdd

#.PHONY: run-netboot
#run-netboot:
#	if [ ! -r $(OUT_PATH)/uEnv.txt ]; then \
#		cp $(BUILD_PATH)/uEnv-example.txt $(OUT_PATH)/uEnv.txt; \
#	fi
#	cd $(OUT_PATH) && \
#	$(QEMU_BIN) \
#		$(QEMU_ARGS) \
#		$(QEMU_BIOS) \
#		$(QEMU_EXTRA_ARGS)
#


################################################################################
# Clean
################################################################################
.PHONY: clean
clean: build-clean fun_sim-clean googletest-clean

.PHONY: distclean
distclean: clean
	rm -rf $(OUT_PATH)
