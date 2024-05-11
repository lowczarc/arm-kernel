.global _Reset
_Reset:
 LDR sp, =stack_top // We initialize the stack pointer to the top of the stack we defined in map.ld

// Initialize system mode stack pointer

// We set the mode bits to system mode
 MRS r3, cpsr
 MOV r4, r3

 // We set the mode bits to abort mode
 BIC r3, r3, #0x1F
 ORR r3, r3, #0x17
 MSR cpsr, r3

 LDR sp, =abort_stack_top

 // We come back to supervisor mode
 MSR cpsr, r4

 BL init // We call the init function defined in src/init.zig
 B . // We loop forever to prevent the program from going bananas
