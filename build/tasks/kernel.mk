# Copyright (C) 2012 The CyanogenMod Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Android makefile to build kernel as a part of Android Build
#
# Configuration
# =============
#
# These config vars are usually set in BoardConfig.mk:
#
#   TARGET_KERNEL_CONFIG               = Kernel defconfig
#   TARGET_KERNEL_VARIANT_CONFIG       = Variant defconfig, optional
#   TARGET_KERNEL_SELINUX_CONFIG       = SELinux defconfig, optional
#   TARGET_KERNEL_ADDITIONAL_CONFIG    = Additional defconfig, optional
#   TARGET_KERNEL_CROSS_COMPILE_PREFIX = Compiler prefix (e.g. arm-eabi-)
#                                          defaults to arm-linux-androidkernel- for arm
#                                                      aarch64-linux-androidkernel- for arm64
#                                                      x86_64-linux-androidkernel- for x86
#
#   TARGET_KERNEL_CLANG_COMPILE        = Compile kernel with clang, defaults to false
#
#   TARGET_KERNEL_CLANG_VERSION        = Clang prebuilts version, optional, defaults to clang-stable
#
#   TARGET_KERNEL_CLANG_PATH           = Clang prebuilts path, optional
#
#   BOARD_KERNEL_IMAGE_NAME            = Built image name
#                                          for ARM use: zImage
#                                          for ARM64 use: Image.gz
#                                          for uncompressed use: Image
#                                          If using an appended DT, append '-dtb'
#                                          to the end of the image name.
#                                          For example, for ARM devices,
#                                          use zImage-dtb instead of zImage.
#
#   KERNEL_TOOLCHAIN_PREFIX            = Overrides TARGET_KERNEL_CROSS_COMPILE_PREFIX,
#                                          Set this var in shell to override
#                                          toolchain specified in BoardConfig.mk
#   KERNEL_TOOLCHAIN                   = Path to toolchain, if unset, assumes
#                                          TARGET_KERNEL_CROSS_COMPILE_PREFIX
#                                          is in PATH
#
#   KERNEL_CC                          = The C Compiler used. This is automatically set based
#                                          on whether the clang version is set, optional.
#
#   KERNEL_CLANG_TRIPLE                = Target triple for clang (e.g. aarch64-linux-gnu-)
#                                          defaults to arm-linux-gnu- for arm
#                                                      aarch64-linux-gnu- for arm64
#                                                      x86_64-linux-gnu- for x86
#
#   USE_CCACHE                         = Enable ccache (global Android flag)
#
#   NEED_KERNEL_MODULE_ROOT            = Optional, if true, install kernel
#                                          modules in root instead of vendor
#   NEED_KERNEL_MODULE_SYSTEM          = Optional, if true, install kernel
#                                          modules in system instead of vendor


ifneq ($(TARGET_NO_KERNEL),true)

## Externally influenced variables
KERNEL_SRC := $(TARGET_KERNEL_SOURCE)
# kernel configuration - mandatory
KERNEL_DEFCONFIG := $(TARGET_KERNEL_CONFIG)
VARIANT_DEFCONFIG := $(TARGET_KERNEL_VARIANT_CONFIG)
SELINUX_DEFCONFIG := $(TARGET_KERNEL_SELINUX_CONFIG)

## Internal variables
DTBS_OUT := $(PRODUCT_OUT)/dtbs
KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config

KERNEL_DEFCONFIG_SRC := $(KERNEL_SRC)/arch/$(KERNEL_ARCH)/configs/$(KERNEL_DEFCONFIG)

ifeq ($(KERNEL_ARCH),x86_64)
KERNEL_DEFCONFIG_ARCH := x86
else
KERNEL_DEFCONFIG_ARCH := $(KERNEL_ARCH)
endif
KERNEL_DEFCONFIG_SRC := $(KERNEL_SRC)/arch/$(KERNEL_DEFCONFIG_ARCH)/configs/$(KERNEL_DEFCONFIG)

ifneq ($(TARGET_PREBUILT_KERNEL),)
    ifeq ($(BOARD_KERNEL_IMAGE_NAME),)
    $(error BOARD_KERNEL_IMAGE_NAME not defined.)
    endif
endif
ifneq ($(TARGET_USES_UNCOMPRESSED_KERNEL),)
$(error TARGET_USES_UNCOMPRESSED_KERNEL is deprecated.)
endif
ifneq ($(TARGET_KERNEL_APPEND_DTB),)
$(error TARGET_KERNEL_APPEND_DTB is deprecated.)
endif
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/$(BOARD_KERNEL_IMAGE_NAME)

# Clear this first to prevent accidental poisoning from env
MAKE_FLAGS :=

ifeq ($(KERNEL_ARCH),arm)
  # Avoid "Unknown symbol _GLOBAL_OFFSET_TABLE_" errors
  MAKE_FLAGS += CFLAGS_MODULE="-fno-pic"
endif

ifeq ($(KERNEL_ARCH),arm64)
  # Avoid "unsupported RELA relocation: 311" errors (R_AARCH64_ADR_GOT_PAGE)
  MAKE_FLAGS += CFLAGS_MODULE="-fno-pic"
endif

ifneq ($(TARGET_KERNEL_ADDITIONAL_CONFIG),)
KERNEL_ADDITIONAL_CONFIG := $(TARGET_KERNEL_ADDITIONAL_CONFIG)
KERNEL_ADDITIONAL_CONFIG_SRC := $(KERNEL_SRC)/arch/$(KERNEL_ARCH)/configs/$(KERNEL_ADDITIONAL_CONFIG)
    ifeq ("$(wildcard $(KERNEL_ADDITIONAL_CONFIG_SRC))","")
        $(warning TARGET_KERNEL_ADDITIONAL_CONFIG '$(TARGET_KERNEL_ADDITIONAL_CONFIG)' doesn't exist)
        KERNEL_ADDITIONAL_CONFIG_SRC := /dev/null
    endif
else
    KERNEL_ADDITIONAL_CONFIG_SRC := /dev/null
endif

ifeq "$(wildcard $(KERNEL_SRC) )" ""
    ifneq ($(TARGET_PREBUILT_KERNEL),)
        HAS_PREBUILT_KERNEL := true
        NEEDS_KERNEL_COPY := true
    else
        $(foreach cf,$(PRODUCT_COPY_FILES), \
            $(eval _src := $(call word-colon,1,$(cf))) \
            $(eval _dest := $(call word-colon,2,$(cf))) \
            $(ifeq kernel,$(_dest), \
                $(eval HAS_PREBUILT_KERNEL := true)))
    endif

    ifneq ($(HAS_PREBUILT_KERNEL),)
        $(warning ***************************************************************)
        $(warning * Using prebuilt kernel binary instead of source              *)
        $(warning * THIS IS DEPRECATED, AND WILL BE DISCONTINUED                *)
        $(warning * Please configure your device to download the kernel         *)
        $(warning * source repository to $(KERNEL_SRC))
        $(warning ***************************************************************)
        FULL_KERNEL_BUILD := false
        KERNEL_BIN := $(TARGET_PREBUILT_KERNEL)
    else
        $(warning ***************************************************************)
        $(warning *                                                             *)
        $(warning * No kernel source found, and no fallback prebuilt defined.   *)
        $(warning * Please make sure your device is properly configured to      *)
        $(warning * download the kernel repository to $(KERNEL_SRC))
        $(warning * and add the TARGET_KERNEL_CONFIG variable to BoardConfig.mk *)
        $(warning *                                                             *)
        $(warning * As an alternative, define the TARGET_PREBUILT_KERNEL        *)
        $(warning * variable with the path to the prebuilt binary kernel image  *)
        $(warning * in your BoardConfig.mk file                                 *)
        $(warning *                                                             *)
        $(warning ***************************************************************)
        $(error "NO KERNEL")
    endif
else
    NEEDS_KERNEL_COPY := true
    ifeq ($(TARGET_KERNEL_CONFIG),)
        $(warning **********************************************************)
        $(warning * Kernel source found, but no configuration was defined  *)
        $(warning * Please add the TARGET_KERNEL_CONFIG variable to your   *)
        $(warning * BoardConfig.mk file                                    *)
        $(warning **********************************************************)
        # $(error "NO KERNEL CONFIG")
    else
        #$(info Kernel source found, building it)
        FULL_KERNEL_BUILD := true
        KERNEL_BIN := $(TARGET_PREBUILT_INT_KERNEL)
    endif
endif

ifeq ($(FULL_KERNEL_BUILD),true)

ifeq ($(NEED_KERNEL_MODULE_ROOT),true)
KERNEL_MODULES_INSTALL := root
KERNEL_MODULES_OUT := $(TARGET_ROOT_OUT)/lib/modules
KERNEL_DEPMOD_STAGING_DIR := $(call intermediates-dir-for,PACKAGING,depmod_recovery)
KERNEL_MODULE_MOUNTPOINT :=
else ifeq ($(NEED_KERNEL_MODULE_SYSTEM),true)
KERNEL_MODULES_INSTALL := $(TARGET_COPY_OUT_SYSTEM)
KERNEL_MODULES_OUT := $(TARGET_OUT)/lib/modules
KERNEL_DEPMOD_STAGING_DIR := $(call intermediates-dir-for,PACKAGING,depmod_system)
KERNEL_MODULE_MOUNTPOINT := system
else
KERNEL_MODULES_INSTALL := $(TARGET_COPY_OUT_VENDOR)
KERNEL_MODULES_OUT := $(TARGET_OUT_VENDOR)/lib/modules
KERNEL_DEPMOD_STAGING_DIR := $(call intermediates-dir-for,PACKAGING,depmod_vendor)
KERNEL_MODULE_MOUNTPOINT := vendor
endif

TARGET_KERNEL_CROSS_COMPILE_PREFIX := $(strip $(TARGET_KERNEL_CROSS_COMPILE_PREFIX))
ifneq ($(TARGET_KERNEL_CROSS_COMPILE_PREFIX),)
KERNEL_TOOLCHAIN_PREFIX ?= $(TARGET_KERNEL_CROSS_COMPILE_PREFIX)
else ifeq ($(KERNEL_ARCH),arm64)
KERNEL_TOOLCHAIN_PREFIX ?= aarch64-linux-androidkernel-
else ifeq ($(KERNEL_ARCH),arm)
KERNEL_TOOLCHAIN_PREFIX ?= arm-linux-androidkernel-
else ifeq ($(KERNEL_ARCH),x86)
KERNEL_TOOLCHAIN_PREFIX ?= x86_64-linux-androidkernel-
endif

ifeq ($(KERNEL_TOOLCHAIN),)
KERNEL_TOOLCHAIN_PATH := $(KERNEL_TOOLCHAIN_PREFIX)
else
ifneq ($(KERNEL_TOOLCHAIN_PREFIX),)
KERNEL_TOOLCHAIN_PATH := $(KERNEL_TOOLCHAIN)/$(KERNEL_TOOLCHAIN_PREFIX)
endif
endif

BUILD_TOP := $(shell pwd)

ifeq ($(TARGET_KERNEL_CLANG_COMPILE),true)
    ifneq ($(TARGET_KERNEL_CLANG_VERSION),)
        # Find the clang-* directory containing the specified version
        KERNEL_CLANG_VERSION := $(shell find $(BUILD_TOP)/prebuilts/clang/host/$(HOST_OS)-x86/ -name AndroidVersion.txt -exec grep -l $(TARGET_KERNEL_CLANG_VERSION) "{}" \; | sed -e 's|/AndroidVersion.txt$$||g;s|^.*/||g')
    else
        # Use the default version of clang if TARGET_KERNEL_CLANG_VERSION hasn't been set by the device config
        KERNEL_CLANG_VERSION := $(LLVM_PREBUILTS_VERSION)
    endif
    TARGET_KERNEL_CLANG_PATH ?= $(BUILD_TOP)/prebuilts/clang/host/$(HOST_OS)-x86/$(KERNEL_CLANG_VERSION)/bin
    KBUILD_COMPILER_STRING := $(shell $(TARGET_KERNEL_CLANG_PATH)/clang --version | head -n 1 | sed -e 's/  */ /g')
    #export KBUILD_COMPILER_STRING
    ifeq ($(KERNEL_ARCH),arm64)
        KERNEL_CLANG_TRIPLE ?= CLANG_TRIPLE=aarch64-linux-gnu-
    else ifeq ($(KERNEL_ARCH),arm)
        KERNEL_CLANG_TRIPLE ?= CLANG_TRIPLE=arm-linux-gnu-
    else ifeq ($(KERNEL_ARCH),x86)
        KERNEL_CLANG_TRIPLE ?= CLANG_TRIPLE=x86_64-linux-gnu-
    endif
endif

# Initialize ccache as an empty argument.
ccache :=

# Fill the ccache argument if USE_CCACHE is not set to false.
ifneq ($(filter-out false,$(USE_CCACHE)),)
    # Detect if the system already has ccache installed.
    ccache := $(shell which ccache)

    # Print which ccache is going to be used to build the Kernel.
    $(info Using '$(ccache)' binary)
else
# Warn the developer if ccache is set to false.
$(info The usage of ccache is set to '$(USE_CCACHE)')
endif

ifeq ($(TARGET_KERNEL_CLANG_COMPILE),true)
    KERNEL_CROSS_COMPILE := CROSS_COMPILE="$(KERNEL_TOOLCHAIN_PATH)"
    PATH_OVERRIDE := PATH=$(TARGET_KERNEL_CLANG_PATH):$$PATH LD_LIBRARY_PATH=$(BUILD_TOP)/prebuilts/clang/host/$(HOST_OS)-x86/$(KERNEL_CLANG_VERSION)/lib64:$$LD_LIBRARY_PATH
    ifeq ($(KERNEL_CC),)
        ifneq ($(USE_CCACHE),)
            KERNEL_CC := CC="$(CCACHE_EXEC) clang"
        else
            KERNEL_CC := CC="clang"
        endif
    endif
else
    KERNEL_CROSS_COMPILE := CROSS_COMPILE="$(ccache) $(KERNEL_TOOLCHAIN_PATH)"
endif

# Needed for CONFIG_COMPAT_VDSO, safe to set for all arm64 builds
ifeq ($(KERNEL_ARCH),arm64)
   KERNEL_CROSS_COMPILE += CROSS_COMPILE_ARM32="arm-linux-androideabi-"
endif

ccache =

ifeq ($(HOST_OS),darwin)
  MAKE_FLAGS += C_INCLUDE_PATH=$(BUILD_TOP)/external/elfutils/0.153/libelf/
endif

ifeq ($(TARGET_KERNEL_MODULES),)
    TARGET_KERNEL_MODULES := INSTALLED_KERNEL_MODULES
endif

KERNEL_ADDITIONAL_CONFIG_OUT := $(KERNEL_OUT)/.additional_config

# Make a DTB targets
# $(1): The DTB target to build (eg. dtbs, defconfig)
define make-dtb-target
$(call internal-make-kernel-target,$(DTBS_OUT),$(1))
endef

$(KERNEL_ADDITIONAL_CONFIG_OUT):
	$(hide) cmp -s $(KERNEL_ADDITIONAL_CONFIG_SRC) $@ || cp $(KERNEL_ADDITIONAL_CONFIG_SRC) $@;

$(KERNEL_CONFIG): $(KERNEL_DEFCONFIG_SRC) $(KERNEL_ADDITIONAL_CONFIG_OUT)
	@echo -e ${CL_GRN}"Building Kernel Config"${CL_RST}
	$(hide) mkdir -p $(KERNEL_OUT)
	$(PATH_OVERRIDE) $(MAKE) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) VARIANT_DEFCONFIG=$(VARIANT_DEFCONFIG) SELINUX_DEFCONFIG=$(SELINUX_DEFCONFIG) $(KERNEL_DEFCONFIG)
	$(hide) if [ ! -z "$(KERNEL_CONFIG_OVERRIDE)" ]; then \
			echo "Overriding kernel config with '$(KERNEL_CONFIG_OVERRIDE)'"; \
			echo $(KERNEL_CONFIG_OVERRIDE) >> $(KERNEL_OUT)/.config; \
			$(PATH_OVERRIDE) $(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) oldconfig; fi
	# Create defconfig build artifact
	$(hide) $(PATH_OVERRIDE) $(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) savedefconfig
	$(hide) if [ ! -z "$(KERNEL_ADDITIONAL_CONFIG)" ]; then \
			echo "Using additional config '$(KERNEL_ADDITIONAL_CONFIG)'"; \
			$(KERNEL_SRC)/scripts/kconfig/merge_config.sh -m -O $(KERNEL_OUT) $(KERNEL_OUT)/.config $(KERNEL_SRC)/arch/$(KERNEL_ARCH)/configs/$(KERNEL_ADDITIONAL_CONFIG); \
			$(PATH_OVERRIDE) $(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) KCONFIG_ALLCONFIG=$(KERNEL_OUT)/.config alldefconfig; fi

$(TARGET_PREBUILT_INT_KERNEL): $(KERNEL_CONFIG)
	@echo -e ${CL_GRN}"Building Kernel"${CL_RST}
	$(hide) rm -rf $(KERNEL_MODULES_OUT)
	$(hide) mkdir -p $(KERNEL_MODULES_OUT)
	$(hide) rm -rf $(KERNEL_DEPMOD_STAGING_DIR)
	$(PATH_OVERRIDE) $(MAKE) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) $(BOARD_KERNEL_IMAGE_NAME)
	$(hide) if grep -q '^CONFIG_OF=y' $(KERNEL_CONFIG); then \
			echo -e ${CL_GRN}"Building DTBs"${CL_RST}; \
			$(PATH_OVERRIDE) $(MAKE) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) dtbs; \
		fi
	$(hide) if grep -q '^CONFIG_MODULES=y' $(KERNEL_CONFIG); then \
			echo -e ${CL_GRN}"Building Kernel Modules"${CL_RST}; \
			$(PATH_OVERRIDE) $(MAKE) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) modules; \
		fi

.PHONY: INSTALLED_KERNEL_MODULES
INSTALLED_KERNEL_MODULES: depmod-host
	$(hide) if grep -q '^CONFIG_MODULES=y' $(KERNEL_CONFIG); then \
			echo -e ${CL_GRN}"Installing Kernel Modules"${CL_RST}; \
			$(PATH_OVERRIDE) $(MAKE) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) INSTALL_MOD_PATH=../../$(KERNEL_MODULES_INSTALL) modules_install && \
			mofile=$$(find $(KERNEL_MODULES_OUT) -type f -name modules.order) && \
			mpath=$$(dirname $$mofile) && \
			for f in $$(find $$mpath/kernel -type f -name '*.ko'); do \
				$(KERNEL_TOOLCHAIN_PATH)strip --strip-unneeded $$f; \
				mv $$f $(KERNEL_MODULES_OUT); \
			done && \
			rm -rf $$mpath && \
			mkdir -p $(KERNEL_DEPMOD_STAGING_DIR)/lib/modules/0.0/$(KERNEL_MODULE_MOUNTPOINT)/lib/modules && \
			find $(KERNEL_MODULES_OUT) -name *.ko -exec cp {} $(KERNEL_DEPMOD_STAGING_DIR)/lib/modules/0.0/$(KERNEL_MODULE_MOUNTPOINT)/lib/modules \; && \
			$(DEPMOD) -b $(KERNEL_DEPMOD_STAGING_DIR) 0.0 && \
			sed -e 's/\(.*modules.*\):/\/\1:/g' -e 's/ \([^ ]*modules[^ ]*\)/ \/\1/g' $(KERNEL_DEPMOD_STAGING_DIR)/lib/modules/0.0/modules.dep > $(KERNEL_MODULES_OUT)/modules.dep; \
		fi

$(TARGET_KERNEL_MODULES): $(TARGET_PREBUILT_INT_KERNEL)

.PHONY: kerneltags
kerneltags: $(KERNEL_CONFIG)
	$(hide) mkdir -p $(KERNEL_OUT)
	$(PATH_OVERRIDE) $(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) tags

.PHONY: kernelconfig kernelxconfig kernelsavedefconfig alldefconfig

kernelconfig:  KERNELCONFIG_MODE := menuconfig
kernelxconfig: KERNELCONFIG_MODE := xconfig
kernelxconfig kernelconfig:
	$(hide) mkdir -p $(KERNEL_OUT)
	$(PATH_OVERRIDE) $(MAKE) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) $(KERNEL_DEFCONFIG)
	env KCONFIG_NOTIMESTAMP=true \
		 $(PATH_OVERRIDE) $(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) $(KERNELCONFIG_MODE)
	env KCONFIG_NOTIMESTAMP=true \
		 $(PATH_OVERRIDE) $(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) savedefconfig
	cp $(KERNEL_OUT)/defconfig $(KERNEL_DEFCONFIG_SRC)

kernelsavedefconfig:
	$(hide) mkdir -p $(KERNEL_OUT)
	$(PATH_OVERRIDE) $(MAKE) $(MAKE_FLAGS) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) $(KERNEL_DEFCONFIG)
	env KCONFIG_NOTIMESTAMP=true \
		 $(PATH_OVERRIDE) $(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) savedefconfig
	cp $(KERNEL_OUT)/defconfig $(KERNEL_DEFCONFIG_SRC)

alldefconfig:
	$(hide) mkdir -p $(KERNEL_OUT)
	env KCONFIG_NOTIMESTAMP=true \
		 $(PATH_OVERRIDE) $(MAKE) -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(KERNEL_CLANG_TRIPLE) $(KERNEL_CC) alldefconfig

ifeq ($(TARGET_NEEDS_DTBOIMAGE),true)
$(BOARD_PREBUILT_DTBOIMAGE):
	echo -e ${CL_GRN}"Building DTBO.img"${CL_RST}
	$(call make-dtbo-target,$(KERNEL_DEFCONFIG))
	$(call make-dtbo-target,dtbo.img)
endif # TARGET_NEEDS_DTBOIMAGE

endif # FULL_KERNEL_BUILD

## Install it

ifeq ($(NEEDS_KERNEL_COPY),true)
file := $(INSTALLED_KERNEL_TARGET)
ALL_PREBUILT += $(file)
$(file) : $(KERNEL_BIN) | $(ACP)
	$(transform-prebuilt-to-target)

ALL_PREBUILT += $(INSTALLED_KERNEL_TARGET)
endif

INSTALLED_DTBOIMAGE_TARGET := $(PRODUCT_OUT)/dtbo.img
ALL_PREBUILT += $(INSTALLED_DTBOIMAGE_TARGET)

ifeq ($(BOARD_INCLUDE_DTB_IN_BOOTIMG),true)
$(INSTALLED_DTBIMAGE_TARGET):
	echo -e ${CL_GRN}"Building DTB Image"${CL_RST}
	$(call make-dtb-target,$(KERNEL_DEFCONFIG))
	$(call make-dtb-target,dtbs)
	cat $(shell find $(DTBS_OUT)/arch/$(KERNEL_ARCH)/boot/dts/** -type f -name "*.dtb" | sort) > $@
.PHONY: dtbimage
dtbimage: $(INSTALLED_DTBIMAGE_TARGET)
endif # BOARD_INCLUDE_DTB_IN_BOOTIMG

.PHONY: kernel
kernel: $(INSTALLED_KERNEL_TARGET) $(TARGET_KERNEL_MODULES)

.PHONY: dtboimage
dtboimage: $(INSTALLED_DTBOIMAGE_TARGET)

endif # TARGET_NO_KERNEL
