    .option arch, rv32i_zicsr
    .text
    .globl  hanoi_generate_moves_asm
    .type   hanoi_generate_moves_asm, @function

# void hanoi_generate_moves_asm(hanoi_move_t *moves)

hanoi_generate_moves_asm:
    # a0: pointer to moves[0]

    mv      a1, x0          # disk0_pos = 0
    mv      a2, x0          # disk1_pos = 0
    mv      a3, x0          # disk2_pos = 0
    li      a4, 65          # base_char = 'A'
    li      a5, 3           # peg_count = 3

    li      t0, 1           # n = 1 (move index)
    li      t1, 8           # stop_n = 8 (loop until n == 8)
    li      t4, 0           # prev_gray = g(0) = 0

loop_generate_moves:
    beq     t0, t1, finish_generation

    # compute Gray code g(n)
    mv      t2, t0
    srli    t3, t2, 1
    xor     t2, t2, t3      # t2 = curr_gray = g(n)

    # changed bits = g(n) ^ prev_gray
    xor     t5, t2, t4
    mv      t4, t2          # prev_gray = curr_gray
    andi    t5, t5, 3       # only low 2 bits matter

    # select which disk moves
    beqz    t5, select_disk2     # 00 -> disk 2
    andi    t6, t5, 1
    bnez    t6, select_disk0     # 01 -> disk 0
    j       select_disk1         # 10 or 11 -> disk 1

# disk 0 (smallest disk)
select_disk0:
    mv      a6, a1          # from_peg = disk0_pos
    addi    a7, a6, 2       # to_peg = from_peg + 2
    blt     a7, a5, 1f
    addi    a7, a7, -3      # to_peg = (to_peg + 3) % 3
1:
    mv      a1, a7          # disk0_pos = to_peg
    li      t6, 0           # disk_index = 0
    j       write_move_entry

# disk 1
select_disk1:
    mv      a6, a2          # from_peg = disk1_pos
    sub     a7, a5, a6      # a7 = 3 - from_peg
    sub     a7, a7, a1      # a7 = 3 - from_peg - disk0_pos
    mv      a2, a7          # disk1_pos = to_peg
    li      t6, 1           # disk_index = 1
    j       write_move_entry

# disk 2
select_disk2:
    mv      a6, a3          # from_peg = disk2_pos
    sub     a7, a5, a6      # a7 = 3 - from_peg
    sub     a7, a7, a1      # a7 = 3 - from_peg - disk0_pos
    mv      a3, a7          # disk2_pos = to_peg
    li      t6, 2           # disk_index = 2

# write one hanoi_move_t entry
# a6 = from_peg index (0..2)
# a7 = to_peg   index (0..2)
write_move_entry:
    add     t2, a4, a6      # from_char = 'A' + from_peg
    add     t3, a4, a7      # to_char   = 'A' + to_peg
    addi    t6, t6, 1       # disk_num = disk_index + 1

    sw      t6, 0(a0)       # moves[i].disk
    sb      t2, 4(a0)       # moves[i].from
    sb      t3, 5(a0)       # moves[i].to

    addi    a0, a0, 8       # move_ptr += sizeof(hanoi_move_t)
    addi    t0, t0, 1       # n++

    j       loop_generate_moves

finish_generation:
    ret
