################################################################################
# Paths to git projects and various binaries
################################################################################
CCACHE ?= $(shell which ccache) # Don't remove this comment (space is needed)

ROOT				?= $(PWD)
OUT_PATH			?= $(ROOT)/out

BUILD_PATH			?= $(ROOT)/build
FUN_SIM_PATH			?= $(ROOT)/fun_sim
GOOGLETEST_PATH			?= $(ROOT)/googletest
GOOGLETEST_OUT			?= $(GOOGLETEST_PATH)/build
GOOGLETEST_LIB_DIR		?= $(GOOGLETEST_OUT)/lib
GOOGLETEST_LIB			?= $(GOOGLETEST_LIB_DIR)/libgtest.a
GOOGLETEST_INCLUDE_DIR		?= $(GOOGLETEST_PATH)/googletest/include
NTL_PATH			?= $(ROOT)/ntl

DEBUG				?= n
CCACHE_DIR			?= $(HOME)/.ccache

# Configuration
CFG_ENABLE_NTL_TESTS		?= n
CFG_ENABLE_GTESTS		?= y

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
