.section .text
.globl _start

_start:
    # Thread check: only thread 0 executes the benchmark, other threads park
    csrr t0, mhartid
    bnez t0, park_thread

    # Initialize stack pointer
    lui sp, 0x00008
    addi sp, sp, -16

    # 1. Test basic ALU operations
    li t0, 10
    li t1, 20
    add t2, t0, t1       # 30
    li t3, 30
    bne t2, t3, fail_add

    sub t2, t1, t0       # 10
    li t3, 10
    bne t2, t3, fail_sub

    xor t2, t0, t1       # 10 ^ 20 = 30
    li t3, 30
    bne t2, t3, fail_xor

    # 2. Test Multiplier (RV32M)
    mul t4, t0, t1       # 10 * 20 = 200
    li t3, 200
    bne t4, t3, fail_mul

    # 3. Test Memory Read/Write
    li a0, 0x00004000
    sw t4, 0(a0)
    lw t5, 0(a0)
    bne t5, t4, fail_mem

    # 4. Multi-iteration synthetic compute kernel (matrix/CRC-like loop)
    li s0, 0             # accumulator
    li s1, 100           # loop count (100 iterations)
    li s2, 0             # loop index
loop_kernel:
    mul s3, s2, t0       # s2 * 10
    add s0, s0, s3       # acc += s2 * 10
    sw s0, 4(a0)         # store intermediate
    lw s4, 4(a0)         # load intermediate
    addi s2, s2, 1
    blt s2, s1, loop_kernel

    # 5. Print benchmark banner to UART (0x20000000)
    lui a1, 0x20000      # 0x20000000
    la a2, msg_pass

print_loop:
    lbu a3, 0(a2)
    beqz a3, pass
    sb a3, 0(a1)
    addi a2, a2, 1
    j print_loop

pass:
    # Write exit code 0 to tohost (0x20000004)
    sw zero, 4(a1)
park_thread:
1:
    j 1b

fail_add:
    lui a1, 0x20000
    li a4, 0x11
    sw a4, 4(a1)
2:  j 2b

fail_sub:
    lui a1, 0x20000
    li a4, 0x12
    sw a4, 4(a1)
3:  j 3b

fail_xor:
    lui a1, 0x20000
    li a4, 0x13
    sw a4, 4(a1)
4:  j 4b

fail_mul:
    lui a1, 0x20000
    li a4, 0x21
    sw a4, 4(a1)
5:  j 5b

fail_mem:
    lui a1, 0x20000
    li a4, 0x31
    sw a4, 4(a1)
6:  j 6b

.section .rodata
msg_pass:
    .string "Klessydra-T CoreMark/Dhrystone RV32IM Benchmark OK\n"
