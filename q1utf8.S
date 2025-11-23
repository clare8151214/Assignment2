    .text
    .globl uf8_decode
    .globl uf8_encode

uf8_decode:
    mv   t5, a0               # t5 = fl
    andi t0, t5, 0x0f         # mantissa
    srli t1, t5, 4            # exponent
    li   t2, 0x7FFF
    li   t3, 15
    sub  t3, t3, t1           # 15 - exponent
    srl  t4, t2, t3           # 0x7FFF >> (15 - exponent)
    slli t4, t4, 4            # << 4
    sll  a0, t0, t1           # mantissa << exponent
    add  a0, a0, t4           # + offset
    ret

uf8_encode:
    mv   t0, a0                 # t0 = original value
    
    li   t6, 15
    bleu t0, t6, encode_exp_0_fast_path
    li   t6, 47
    bleu t0, t6, encode_exp_1_fast_path
    li   t6, 111
    bleu t0, t6, encode_exp_2_fast_path
    li   t6, 239
    bleu t0, t6, encode_exp_3_fast_path

    j    encode_generic_path

encode_exp_0_fast_path:         # value <= 15
    andi a0, t0, 0xFF
    ret

encode_exp_1_fast_path:         # 16–47
    addi t1, t0, -16
    srli t1, t1, 1
    ori  a0, t1, 0x10           # exponent = 1
    ret

encode_exp_2_fast_path:         # 48–111
    addi t1, t0, -48
    srli t1, t1, 2
    ori  a0, t1, 0x20           # exponent = 2
    ret

encode_exp_3_fast_path:         # 112–239
    addi t1, t0, -112
    srli t1, t1, 3
    ori  a0, t1, 0x30           # exponent = 3
    ret

encode_generic_path:
    # --- Inlined clz ---
    mv   a5, t0
    li   t1, 32
    li   t2, 16
clz_inline_loop:
    srl  t3, a5, t2
    beq  t3, x0, clz_inline_skip
    sub  t1, t1, t2
    mv   a5, t3
clz_inline_skip:
    srli t2, t2, 1
    bne  x0, t2, clz_inline_loop
    sub  t1, t1, a5             # t1 = lz

    li   t2, 31
    sub  t2, t2, t1
    li   t3, 0
    li   t4, 0
    li   t6, 5
    blt  t2, t6, exp_est_done
    li   t6, 4
    sub  t3, t2, t6
    li   t6, 15
    bgeu t3, t6, cap_to_15
    j    exp_est_loop_init
cap_to_15:
    li   t3, 15

exp_est_loop_init:
    beqz t3, exp_est_done
    li   t4, 0
    li   t5, 0
exp_make_ovl:
    bgeu t5, t3, exp_make_ovl_done
    slli t4, t4, 1
    addi t4, t4, 16
    addi t5, t5, 1
    j    exp_make_ovl
exp_make_ovl_done:
    li   t5, 0

exp_back_check:
    beqz t3, exp_est_done
    bltu t0, t4, exp_back_step
    j    exp_est_done
exp_back_step:
    addi t4, t4, -16
    srli t4, t4, 1
    addi t3, t3, -1
    j    exp_back_check

exp_est_done:
adj_up_loop:
    li   t6, 15
    beq  t3, t6, adj_done
    slli t5, t4, 1
    addi t5, t5, 16
    bltu t0, t5, adj_done
    mv   t4, t5
    addi t3, t3, 1
    j    adj_up_loop

adj_done:
    sub  t6, t0, t4
    srl  t6, t6, t3
    slli t3, t3, 4
    or   a0, t3, t6
    andi a0, a0, 0xFF
    ret