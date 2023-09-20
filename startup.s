.global _Reset
_Reset:
 LDR sp, =stack_top
 BL init
 B .
