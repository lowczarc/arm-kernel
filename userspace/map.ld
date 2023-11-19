ENTRY(_Reset)
SECTIONS
{
 . = 0x40000000;
 .startup . : { startup.o(.text) }
 .text : { *(.text) }
 .data : { *(.data) }
 .bss : { *(.bss COMMON) }
 . = ALIGN(8);
}
