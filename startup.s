.global _Reset
_Reset:
 LDR sp, =stack_top // We initialize the stack pointer to the top of the stack we defined in map.ld
 BL init // We call the init function defined in src/init.zig
 B . // We loop forever to prevent the program from going bananas
