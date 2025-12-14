rsqrt_table:
    .word 65536, 46341, 32768, 23170, 16384  /* 0 - 4 */
    .word 11585, 8192,  5793,  4096,  2896   /* 5 - 9 */
    .word 2048,  1448,  1024,  724,   512    /* 10 - 14 */
    .word 362,   256,   181,   128,   90     /* 15 - 19 */
    .word 64,    45,    32,    23,    16     /* 20 - 24 */
    .word 11,    8,     6,     4,     3      /* 25 - 29 */
    .word 2,     1                           /* 30 - 31 */

    .option arch, rv32im_zicsr
    .text
    .globl  fast_rsqrt_asm
    .type   fast_rsqrt_asm, @function
    .globl  fast_distance_3d
    .type   fast_distance_3d, @function

clz32:
    beqz    a0, clz32_zero_input
    li      t0, 0

    srli    t1, a0, 16
    bnez    t1, clz32_check8
    addi    t0, t0, 16
    slli    a0, a0, 16

clz32_check8:
    srli    t1, a0, 24
    bnez    t1, clz32_check4
    addi    t0, t0, 8
    slli    a0, a0, 8

clz32_check4:
    srli    t1, a0, 28
    bnez    t1, clz32_check2
    addi    t0, t0, 4
    slli    a0, a0, 4

clz32_check2:
    srli    t1, a0, 30
    bnez    t1, clz32_check1
    addi    t0, t0, 2
    slli    a0, a0, 2

clz32_check1:
    srli    t1, a0, 31
    bnez    t1, clz32_done
    addi    t0, t0, 1

clz32_done:
    mv      a0, t0
    ret

clz32_zero_input:
    li      a0, 32
    ret

fast_rsqrt_asm:
    # Fast path for zero
    bnez    a0, rsqrt_normal
    ret
    
rsqrt_normal:
    addi    sp, sp, -24
    sw      ra, 20(sp)
    sw      s0, 16(sp)
    sw      s1, 12(sp)
    sw      s2, 8(sp)
    sw      s3, 4(sp)
    
    mv      s0, a0
    
    call    clz32
    li      t0, 31
    sub     s1, t0, a0
    
    # Load table values
    slli    t0, s1, 2
    la      t1, rsqrt_table
    add     t1, t1, t0
    lw      s2, 0(t1)
    
    bge     s1, t0, skip_ynext
    lw      s3, 4(t1)
    sub     s3, s2, s3      # Pre-compute delta
    j       do_interp
skip_ynext:
    li      s3, 0
    
do_interp:
    # Compute frac = (x - (1 << lz)) * 65536 >> lz
    li      t0, 1
    sll     t0, t0, s1
    sub     t1, s0, t0
    
    # Inline mul64: t1 * 65536
    li      t2, 65536
    mul     a0, t1, t2
    mulhu   a1, t1, t2
    
    # Right shift by lz
    mv      t0, s1
    beqz    t0, frac_done
    li      t1, 32
    bge     t0, t1, frac_large_shift
    
    srl     t2, a0, t0
    sub     t3, t1, t0
    sll     t4, a1, t3
    or      a0, t2, t4
    j       frac_done
    
frac_large_shift:
    addi    t0, t0, -32
    srl     a0, a1, t0
    
frac_done:
    # Interpolation: y = y0 - (delta * frac >> 16)
    # Inline mul64: s3 * a0
    mul     t0, s3, a0
    mulhu   t1, s3, a0
    srli    t0, t0, 16
    slli    t1, t1, 16
    or      t0, t0, t1
    sub     s2, s2, t0
    
    # Newton-Raphson: y * y (only need low 32 bits)
    mul     s3, s2, s2
    
    # x * (y*y) >> 16
    mul     a0, s0, s3
    mulhu   a1, s0, s3
    srli    a0, a0, 16
    slli    t1, a1, 16
    or      t0, a0, t1
    
    # 3.0 - x*y*y
    li      t1, 196608      # 3 << 16
    sub     t1, t1, t0
    
    # y * (3 - x*y*y) / 2
    mul     a0, s2, t1
    mulhu   a1, s2, t1
    srli    a0, a0, 17
    slli    t1, a1, 15
    or      a0, a0, t1
    
    lw      ra, 20(sp)
    lw      s0, 16(sp)
    lw      s1, 12(sp)
    lw      s2, 8(sp)
    lw      s3, 4(sp)
    addi    sp, sp, 24
    ret

fast_distance_3d:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    sw      s1, 4(sp)
    
    # x^2 + y^2 + z^2
    mul     t0, a0, a0
    mul     t1, a1, a1
    mul     t2, a2, a2
    add     t0, t0, t1
    add     s0, t0, t2
    
    # rsqrt
    mv      a0, s0
    call    fast_rsqrt_asm
    mv      s1, a0
    
    # distance = sum * rsqrt >> 16
    mul     a0, s0, s1
    mulhu   a1, s0, s1
    srli    a0, a0, 16
    slli    t0, a1, 16
    or      a0, a0, t0
    
    lw      ra, 12(sp)
    lw      s0, 8(sp)
    lw      s1, 4(sp)
    addi    sp, sp, 16
    ret