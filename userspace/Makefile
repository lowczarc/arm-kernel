AS = arm-none-eabi-as
LD = arm-none-eabi-ld
OBJCOPY = arm-none-eabi-objcopy
ZIG_TARGET = arm-freestanding-eabihf
MCPU = cortex-a7

all: main.bin

startup.o: startup.s
	@$(AS) -mcpu=$(MCPU) -g startup.s -o startup.o

MCPU_ZIG = $(subst -,_,$(MCPU))

main.o: main.zig ./*.zig
	@zig build-obj -fno-strip main.zig -target $(ZIG_TARGET) -mcpu=$(MCPU_ZIG) --name main

main.elf: main.o startup.o map.ld
	@$(LD) -T map.ld main.o startup.o -o main.elf -nostdlib -z noexecstack -no-warn-rwx-segments

main.bin: main.elf
	@$(OBJCOPY) -O binary main.elf main.bin

.PHONY: clean qemu

clean:
	@rm -f *.o *.elf *.bin
