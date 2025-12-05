    .option arch, rv32i_zicsr
    .text
    .globl  hanoi_generate_moves_asm
    .type   hanoi_generate_moves_asm, @function

# void hanoi_generate_moves_asm(hanoi_move_t *moves)

hanoi_generate_moves_asm:
    addi    sp, sp, -28
    sw      ra, 24(sp)
    sw      s0, 20(sp)
    sw      s1, 16(sp)
    sw      s2, 12(sp)
    sw      s3, 8(sp)
    sw      s4, 4(sp)
    sw      s5, 0(sp)

    mv      s0, a0          # move_ptr = moves
    li      s1, 0           # disk0_pos
    li      s2, 0           # disk1_pos
    li      s3, 0           # disk2_pos
    li      s4, 65          # base_char = 'A'
    li      s5, 3           # peg_count = 3

    li      t0, 1           # n = 1 (move index)
    li      t1, 8           # stop_n = 8

loop_generate_moves:
    beq     t0, t1, finish_generation

    #  Gray code: g(n) 
    mv      t2, t0
    srli    t3, t2, 1
    xor     t4, t2, t3      # t4 = gray(n)

    #  Gray code: g(n-1) 
    addi    t2, t0, -1
    srli    t3, t2, 1
    xor     t2, t2, t3      # t2 = gray(n-1)

    #  changed bits = g(n) ^ g(n-1) 
    xor     t5, t4, t2
    andi    t5, t5, 3       # only low 2 bits matter

    beqz    t5, select_disk2     # 00 -> disk2
    andi    t6, t5, 1
    bnez    t6, select_disk0     # 01 -> disk0
    j       select_disk1         # 10 or 11 -> disk1

#  disk 0 (smallest disk) 
select_disk0:
    mv      a6, s1               # from_peg = disk0_pos
    addi    a7, a6, 2            # a7 = from + 2
    blt     a7, s5, small_disk_target_ok
    addi    a7, a7, -3           # mod 3
small_disk_target_ok:
    mv      s1, a7               # disk0_pos = to_peg
    li      t6, 0                # disk_index = 0
    j       write_move_entry

#  disk 1 
select_disk1:
    mv      a6, s2               # from_peg = disk1_pos
    sub     a7, s5, a6           # a7 = 3 - from
    sub     a7, a7, s1           # a7 = 3 - from - disk0_pos
    mv      s2, a7               # disk1_pos = to_peg
    li      t6, 1                # disk_index = 1
    j       write_move_entry

#  disk 2 
select_disk2:
    mv      a6, s3               # from_peg = disk2_pos
    sub     a7, s5, a6           # a7 = 3 - from
    sub     a7, a7, s1           # a7 = 3 - from - disk0_pos
    mv      s3, a7               # disk2_pos = to_peg
    li      t6, 2                # disk_index = 2

#  write struct hanoi_move_t 
write_move_entry:
    add     t2, s4, a6           # from_char = 'A' + from_peg
    add     t3, s4, a7           # to_char   = 'A' + to_peg
    addi    t6, t6, 1            # disk_num = disk_index + 1

    sw      t6, 0(s0)            # moves[i].disk
    sb      t2, 4(s0)            # moves[i].from_peg
    sb      t3, 5(s0)            # moves[i].to_peg

    addi    s0, s0, 8            # move_ptr += sizeof(hanoi_move_t)
    addi    t0, t0, 1            # n++

    j       loop_generate_moves

finish_generation:
    lw      ra, 24(sp)
    lw      s0, 20(sp)
    lw      s1, 16(sp)
    lw      s2, 12(sp)
    lw      s3, 8(sp)
    lw      s4, 4(sp)
    lw      s5, 0(sp)
    addi    sp, sp, 28
    ret
