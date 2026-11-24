OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x80;
  .text : { *(.text) }
  .rodata : { *(.rodata*) }
  .data : { *(.data*) }
  .bss : { *(.bss*) }
}

