
TOOLCHAIN_MK := $(HOME)/rv32emu/mk/toolchain.mk
BUILD_DIR := $(HOME)/rv32emu/build
RV32EMU_BIN := $(BUILD_DIR)/rv32emu
CONFIG_FILE := $(BUILD_DIR)/.config

include $(TOOLCHAIN_MK)

ARCH = -march=rv32i_zicsr
LINKER_SCRIPT = linker.ld

EMU ?= $(RV32EMU_BIN)

AFLAGS = -g $(ARCH)
CFLAGS = -g -march=rv32i_zicsr
LDFLAGS = -T $(LINKER_SCRIPT)

EXEC = test.elf
HANOI_C_EXEC = hanoi_c_test.elf
HANOI_ASM_EXEC = hanoi_asm_test.elf

RSQRT_C_OBJ = rsqrt_c.o
RSQRT_ASM_OBJ = rsqrt.o

CC = $(CROSS_COMPILE)gcc
AS = $(CROSS_COMPILE)as
LD = $(CROSS_COMPILE)ld
OBJDUMP = $(CROSS_COMPILE)objdump

OBJS = start.o main.o perfcounter.o chacha20_asm.o q1utf8.o hanoi.o
HANOI_C_OBJS = start.o mainC.o perfcounter.o hanoi.o $(RSQRT_C_OBJ)
HANOI_ASM_OBJS = start.o main_asm.o perfcounter.o hanoi_asm.o $(RSQRT_ASM_OBJ)

.PHONY: all run dump clean hanoi hanoi_c hanoi_asm run_c run_asm run_hanoi_both check-env


#  Build Rules

all: $(EXEC) run_hanoi_both

$(EXEC): $(OBJS) $(LINKER_SCRIPT)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

hanoi: $(HANOI_C_EXEC) $(HANOI_ASM_EXEC)

hanoi_c: $(HANOI_C_EXEC)

hanoi_asm: $(HANOI_ASM_EXEC)

$(HANOI_C_EXEC): $(HANOI_C_OBJS) $(LINKER_SCRIPT)
	$(CC) $(CFLAGS) -T $(LINKER_SCRIPT) -nostartfiles -o $@ $(HANOI_C_OBJS)

$(HANOI_ASM_EXEC): $(HANOI_ASM_OBJS) $(LINKER_SCRIPT)
	$(LD) $(LDFLAGS) -o $@ $(HANOI_ASM_OBJS)

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) $< -o $@ -c

$(RSQRT_C_OBJ): rsqrt.c
	$(CC) $(CFLAGS) $< -o $@ -c

$(RSQRT_ASM_OBJ): rsqrt.S
	$(CC) -g -march=rv32im_zicsr -c $< -o $@

hanoi.o: hanoi.c
	$(CC) $(CFLAGS) $< -o $@ -c

hanoi_asm.o: hanoi.S
	$(CC) $(CFLAGS) -c $< -o $@



#  Environment Check

check-env:
	@test -f $(EMU) || (echo "Error: $(EMU) not found" && exit 1)
	@grep -q "ENABLE_ELF_LOADER=1" $(CONFIG_FILE) || (echo "Error: ENABLE_ELF_LOADER=1 not set" && exit 1)
	@grep -q "ENABLE_SYSTEM=1" $(CONFIG_FILE) || (echo "Error: ENABLE_SYSTEM=1 not set" && exit 1)



#  Run Targets

run: check-env $(EXEC)
	$(EMU) $(EXEC)

run_c: check-env hanoi_c
	$(EMU) $(HANOI_C_EXEC)

run_asm: check-env hanoi_asm
	$(EMU) $(HANOI_ASM_EXEC)




#  Dump Assembly

dump: 
	$(OBJDUMP) -Ds $(HANOI_ASM_EXEC)



#  Clean

clean:
	rm -f $(EXEC) $(OBJS) \
	      $(HANOI_C_EXEC) $(HANOI_ASM_EXEC) \
	      $(HANOI_C_OBJS) $(HANOI_ASM_OBJS)
