API ?= 35
TARGET ?= pa3q-S938NKSUACZF1
OUTDIR ?= build/$(TARGET)

APP_TARGET_CFLAGS :=
ifeq ($(TARGET),dm2q-S916BXXSAFZG1)
APP_TARGET_CFLAGS := -DSLIDE_STACK_WRITER=1
endif
ifeq ($(TARGET),dm3q-S918BXXSAFZF5)
APP_TARGET_CFLAGS := -DSLIDE_STACK_WRITER=1
endif
ifeq ($(TARGET),gts9u-X916BXXS6EZG3)
APP_TARGET_CFLAGS := -DSLIDE_STACK_WRITER=1
endif
ifeq ($(TARGET),dm1q-S911U1UES6DYI3)
APP_TARGET_CFLAGS := -DSLIDE_STACK_WRITER=1
endif
ifeq ($(TARGET),a53x-A536EXXSNGZG3)
API := 31
endif
ifeq ($(TARGET),a17-A175FXXS6CZG1)
API := 35
endif

TARGET_HEADER := src/targets/$(TARGET)/target.h
TARGET_INCLUDE := targets/$(TARGET)/target.h
TARGET_CC := $(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android$(API)-clang

ifeq ($(wildcard $(TARGET_CC)),)
$(error set ANDROID_NDK_HOME to an Android NDK containing $(TARGET_CC))
endif

PRELOAD := $(OUTDIR)/cve-2026-43499
APP_PRELOAD := $(OUTDIR)/cve-2026-43499-app.so
APP_RELEASE := $(OUTDIR)/cve-2026-43499-app.release.so
APP_STABLE := $(OUTDIR)/cve-2026-43499-app.stable.so
APP_RELEASE_SIZE := 104128
ROOT_HELPER := $(OUTDIR)/cve-2026-43499-root
TARGET_CFLAGS :=
APP_RELEASE_OPT := -Oz
APP_RELEASE_LINK_FLAGS := -Wl,--gc-sections -Wl,--icf=all -s

A17_DIR := src/targets/a17-A175FXXS6CZG1
A17_SRCS := \
  $(A17_DIR)/core/main.c \
  $(A17_DIR)/core/util.c \
  $(A17_DIR)/core/slide.c \
  $(A17_DIR)/core/fops.c \
  $(A17_DIR)/core/pipe_physrw.c \
  $(A17_DIR)/core/pipe_reclaim.c \
  $(A17_DIR)/core/rwforge_a17.c \
  $(A17_DIR)/core/root.c \
  $(A17_DIR)/core/miniadb.c \
  $(A17_DIR)/core/umh_root.c
A17_CFLAGS := -Wall -Wextra -Wno-unused-parameter -Wno-sign-compare \
  -Wno-unused-function -I$(A17_DIR)/core -I$(A17_DIR)/devices \
  -DTARGET_CONFIG_H='"target_czg1.h"'

PRELOAD_SRCS := \
  src/main.c \
  src/util.c \
  src/slide.c \
  src/fops.c \
  src/pipe.c \
  src/root.c \
  src/preload.c

APP_PRELOAD_SRCS := \
  src/main.c \
  src/util.c \
  src/slide_app.c \
  src/fops.c \
  src/pipe.c \
  src/root.c \
  src/preload.c

ifeq ($(TARGET),a53x-A536EXXSNGZG3)
APP_PRELOAD_SRCS := \
  src/targets/a53x-A536EXXSNGZG3/payload.c \
  src/targets/a53x-A536EXXSNGZG3/chain.c \
  src/targets/a53x-A536EXXSNGZG3/ghostlock.c \
  src/targets/a53x-A536EXXSNGZG3/page.c
PRELOAD_SRCS := $(APP_PRELOAD_SRCS)
APP_RELEASE_OPT := -O2
APP_RELEASE_LINK_FLAGS := -Wl,--gc-sections -Wl,--icf=all -s
endif

COMMON_CFLAGS := \
  -O2 -g0 -Wall -Wextra \
  -Wno-unused-parameter -Wno-sign-compare \
  -Isrc -DTARGET_HEADER='"$(TARGET_INCLUDE)"' \
  $(TARGET_CFLAGS)

ifeq ($(TARGET),a17-A175FXXS6CZG1)
TARGET_HEADER := $(A17_DIR)/core/target_czg1.h
PRELOAD_SRCS := $(A17_SRCS)
APP_PRELOAD_SRCS := $(A17_SRCS) $(A17_DIR)/app/payload.c
endif

.DEFAULT_GOAL := all

.PHONY: all clean info release stable

all: $(PRELOAD) $(APP_PRELOAD) $(ROOT_HELPER)

release: $(APP_RELEASE)

stable: $(APP_STABLE)

$(OUTDIR):
	mkdir -p $@

ifeq ($(TARGET),a17-A175FXXS6CZG1)
$(PRELOAD): $(PRELOAD_SRCS) $(TARGET_HEADER) $(A17_DIR)/core/*.h $(A17_DIR)/core/kernelsnitch/*.h $(A17_DIR)/devices/*.h $(A17_DIR)/devices/a17/*.h | $(OUTDIR)
	$(TARGET_CC) -O2 $(A17_CFLAGS) -fPIE -pie $(PRELOAD_SRCS) -pthread -o $@

$(APP_PRELOAD): $(APP_PRELOAD_SRCS) $(TARGET_HEADER) $(A17_DIR)/core/*.h $(A17_DIR)/core/kernelsnitch/*.h $(A17_DIR)/devices/*.h $(A17_DIR)/devices/a17/*.h | $(OUTDIR)
	$(TARGET_CC) -O2 $(A17_CFLAGS) -DG4_LIBENTRY=1 -fPIC \
	  $(APP_PRELOAD_SRCS) -shared -pthread -o $@

$(APP_RELEASE): $(APP_PRELOAD_SRCS) $(TARGET_HEADER) $(A17_DIR)/core/*.h $(A17_DIR)/core/kernelsnitch/*.h $(A17_DIR)/devices/*.h $(A17_DIR)/devices/a17/*.h | $(OUTDIR)
	$(TARGET_CC) -Oz -g0 -fvisibility=hidden \
	  -fno-unwind-tables -fno-asynchronous-unwind-tables \
	  -ffunction-sections -fdata-sections $(A17_CFLAGS) -DG4_LIBENTRY=1 -fPIC \
	  $(APP_PRELOAD_SRCS) -shared -pthread $(APP_RELEASE_LINK_FLAGS) -o $@

$(ROOT_HELPER): src/su_daemon.c | $(OUTDIR)
	$(TARGET_CC) -fPIE -pie -O2 -g0 -Wall -Wextra $< -ldl -o $@
else
$(PRELOAD): $(PRELOAD_SRCS) $(TARGET_HEADER) src/offset.h src/common.h src/kernelsnitch/*.h | $(OUTDIR)
	$(TARGET_CC) -fPIC $(COMMON_CFLAGS) $(PRELOAD_SRCS) \
	  -shared -pthread -o $@

$(ROOT_HELPER): src/su_daemon.c | $(OUTDIR)
	$(TARGET_CC) -fPIE -pie -O2 -g0 -Wall -Wextra $< -ldl -o $@

$(APP_PRELOAD): $(APP_PRELOAD_SRCS) $(TARGET_HEADER) src/offset.h src/common.h src/kernelsnitch/*.h | $(OUTDIR)
	$(TARGET_CC) -DAPP_PAYLOAD=1 $(APP_TARGET_CFLAGS) -fPIC $(COMMON_CFLAGS) $(APP_PRELOAD_SRCS) \
	  -shared -pthread -o $@

$(APP_RELEASE): $(APP_PRELOAD_SRCS) $(TARGET_HEADER) src/offset.h src/common.h src/kernelsnitch/*.h | $(OUTDIR)
	$(TARGET_CC) -DAPP_PAYLOAD=1 $(APP_TARGET_CFLAGS) -fPIC $(APP_RELEASE_OPT) -g0 \
	  -fno-unwind-tables -fno-asynchronous-unwind-tables \
	  -ffunction-sections -fdata-sections \
	  -Wall -Wextra -Wno-unused-parameter -Wno-sign-compare \
	  -Isrc -DTARGET_HEADER='"$(TARGET_INCLUDE)"' \
	  $(TARGET_CFLAGS) \
	  $(APP_PRELOAD_SRCS) -shared -pthread \
	  $(APP_RELEASE_LINK_FLAGS) -o $@
	@test $$(stat -c %s $@) -le $(APP_RELEASE_SIZE)
	truncate -s $(APP_RELEASE_SIZE) $@
endif

$(APP_STABLE): $(APP_PRELOAD_SRCS) $(TARGET_HEADER) src/offset.h src/common.h src/kernelsnitch/*.h | $(OUTDIR)
	$(TARGET_CC) -DAPP_PAYLOAD=1 -DAPP_S928_STABLE_RACE=1 \
	  -fPIC -Oz -g0 -fvisibility=hidden -fno-semantic-interposition \
	  -fstack-protector-strong \
	  -fno-unwind-tables -fno-asynchronous-unwind-tables \
	  -ffunction-sections -fdata-sections \
	  -Wall -Wextra -Wno-unused-parameter -Wno-sign-compare \
	  -Isrc -DTARGET_HEADER='"$(TARGET_INCLUDE)"' \
	  $(APP_PRELOAD_SRCS) -shared -pthread \
	  -Wl,--gc-sections -Wl,--icf=all -s -o $@
	@test $$(stat -c %s $@) -le $(APP_RELEASE_SIZE)
	truncate -s $(APP_RELEASE_SIZE) $@

info:
	@echo "TARGET=$(TARGET)"
	@echo "APP_TARGET_CFLAGS=$(APP_TARGET_CFLAGS)"
	@echo "TARGET_CC=$(TARGET_CC)"
	@echo "PRELOAD=$(PRELOAD)"
	@echo "APP_PRELOAD=$(APP_PRELOAD)"
	@echo "APP_RELEASE=$(APP_RELEASE)"
	@echo "APP_STABLE=$(APP_STABLE)"
	@echo "ROOT_HELPER=$(ROOT_HELPER)"

clean:
	rm -rf $(OUTDIR)
