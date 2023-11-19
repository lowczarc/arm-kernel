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

userspace/main.bin:
	@cd userspace && make main.bin

assets/font.bin: assets/font.txt
	@python scripts/compile_font.py assets/font.txt assets/font.bin

init.o: init.zig *.zig **/*.zig userspace/main.bin assets/font.bin
	@zig build-obj -fno-strip init.zig -target $(ZIG_TARGET) -mcpu=$(MCPU_ZIG) --name init

util.o: util.zig
	@zig build-obj -fno-strip util.zig -target $(ZIG_TARGET) -mcpu=$(MCPU_ZIG) --name util

init.elf: init.o startup.o util.o map.ld
	@$(LD) -T map.ld init.o util.o startup.o -o init.elf -nostdlib -z noexecstack -no-warn-rwx-segments

init.bin: init.elf
	@$(OBJCOPY) -O binary init.elf init.bin

.PHONY: clean qemu

clean:
	@rm -f *.o *.elf *.bin assets/font.bin
	@cd userspace && make clean

qemu:
	@$(QEMU) -M $(QEMU_MACHINE) -nographic -semihosting -kernel init.bin

qemu-screen:
	@$(QEMU) -M $(QEMU_MACHINE) -serial /dev/stdout -semihosting -kernel init.bin

qemu-dbg:
	@$(QEMU) -M $(QEMU_MACHINE) -nographic -semihosting -kernel init.bin -s -S
