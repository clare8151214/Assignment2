# === 使用絕對路徑 ===
TOOLCHAIN_MK := $(HOME)/rv32emu/mk/toolchain.mk
BUILD_DIR := $(HOME)/rv32emu/build
RV32EMU_BIN := $(BUILD_DIR)/rv32emu
CONFIG_FILE := $(BUILD_DIR)/.config

include $(TOOLCHAIN_MK)

ARCH = -march=rv32izicsr
LINKER_SCRIPT = linker.ld

EMU ?= $(RV32EMU_BIN)

AFLAGS = -g $(ARCH)
CFLAGS = -g -march=rv32i_zicsr
LDFLAGS = -T $(LINKER_SCRIPT)
EXEC = test.elf

CC = $(CROSS_COMPILE)gcc
AS = $(CROSS_COMPILE)as
LD = $(CROSS_COMPILE)ld
OBJDUMP = $(CROSS_COMPILE)objdump

OBJS = start.o main.o perfcounter.o chacha20_asm.o q1utf8.o 

.PHONY: all run dump clean

all: $(EXEC)

$(EXEC): $(OBJS) $(LINKER_SCRIPT)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

%.o: %.S
	$(AS) $(AFLAGS) $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) $< -o $@ -c

run: $(EXEC)
	@test -f $(EMU) || (echo "Error: $(EMU) not found" && exit 1)
	@grep -q "ENABLE_ELF_LOADER=1" $(CONFIG_FILE) || (echo "Error: ENABLE_ELF_LOADER=1 not set" && exit 1)
	@grep -q "ENABLE_SYSTEM=1" $(CONFIG_FILE) || (echo "Error: ENABLE_SYSTEM=1 not set" && exit 1)
	$(EMU) $<

dump: $(EXEC)
	$(OBJDUMP) -Ds $< | less

clean:
	rm -f $(EXEC) $(OBJS)
