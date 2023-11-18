AS = arm-none-eabi-as
LD = arm-none-eabi-ld
OBJCOPY = arm-none-eabi-objcopy
ZIG_TARGET = arm-freestanding-eabihf
MCPU = cortex-a7
QEMU=qemu-system-arm
QEMU_MACHINE=raspi2b

all: init.bin

startup.o: startup.s
	@$(AS) -mcpu=$(MCPU) -g startup.s -o startup.o

MCPU_ZIG = $(subst -,_,$(MCPU))

init.o: src/init.zig src/*.zig src/**/*.zig
	@zig build-obj -fno-strip src/init.zig -target $(ZIG_TARGET) -mcpu=$(MCPU_ZIG) --name init

util.o: src/util.zig
	@zig build-obj -fno-strip src/util.zig -target $(ZIG_TARGET) -mcpu=$(MCPU_ZIG) --name util

init.elf: init.o startup.o util.o map.ld
	@$(LD) -T map.ld init.o util.o startup.o -o init.elf -nostdlib -z noexecstack -no-warn-rwx-segments

init.bin: init.elf
	@$(OBJCOPY) -O binary init.elf init.bin

.PHONY: clean qemu

clean:
	@rm -f *.o *.elf *.bin

qemu:
	@$(QEMU) -M $(QEMU_MACHINE) -nographic -semihosting -kernel init.bin

qemu-screen:
	@$(QEMU) -M $(QEMU_MACHINE) -serial /dev/stdout -semihosting -kernel init.bin

qemu-dbg:
	@$(QEMU) -M $(QEMU_MACHINE) -nographic -semihosting -kernel init.bin -s -S
