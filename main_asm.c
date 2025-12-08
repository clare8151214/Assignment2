#include <stdbool.h>
#include <stdint.h>

#define printstr(ptr, length)                   \
    do {                                        \
        asm volatile(                           \
            "add a7, x0, 0x40;"                 \
            "add a0, x0, 0x1;" /* stdout */     \
            "add a1, x0, %0;"                   \
            "mv a2, %1;" /* length character */ \
            "ecall;"                            \
            :                                   \
            : "r"(ptr), "r"(length)             \
            : "a0", "a1", "a2", "a7");          \
    } while (0)

#define TEST_OUTPUT(msg, length) printstr(msg, length)

#define TEST_LOGGER(msg)                     \
    {                                        \
        char _msg[] = msg;                   \
        TEST_OUTPUT(_msg, sizeof(_msg) - 1); \
    }

typedef struct hanoi_move {
    uint32_t disk;
    char from;
    char to;
} hanoi_move_t;

static inline uint64_t get_ticks(void)
{
    uint64_t result;
    uint32_t l, h, h2;

    asm volatile(
        "rdcycleh %0\n"
        "rdcycle %1\n"
        "rdcycleh %2\n"
        "sub %0, %0, %2\n"
        "seqz %0, %0\n"
        "sub %0, zero, %0\n"
        "and %1, %1, %0\n"
        : "=r"(h), "=r"(l), "=r"(h2));

    result = (((uint64_t) h) << 32) | ((uint64_t) l);
    return result;
}

extern uint64_t get_cycles(void);
extern uint64_t get_instret(void);
extern void hanoi_generate_moves_asm(hanoi_move_t moves[static 7]);
extern uint32_t fast_rsqrt_asm(uint32_t x);
extern uint32_t fast_distance_3d(int32_t dx, int32_t dy, int32_t dz);

typedef void (*hanoi_generator_t)(hanoi_move_t moves[static 7]);

static unsigned long udiv(unsigned long dividend, unsigned long divisor)
{
    if (divisor == 0)
        return 0;

    unsigned long quotient = 0;
    unsigned long remainder = 0;

    for (int i = 31; i >= 0; i--) {
        remainder <<= 1;
        remainder |= (dividend >> i) & 1;

        if (remainder >= divisor) {
            remainder -= divisor;
            quotient |= (1UL << i);
        }
    }

    return quotient;
}

static unsigned long umod(unsigned long dividend, unsigned long divisor)
{
    if (divisor == 0)
        return 0;

    unsigned long remainder = 0;

    for (int i = 31; i >= 0; i--) {
        remainder <<= 1;
        remainder |= (dividend >> i) & 1;

        if (remainder >= divisor) {
            remainder -= divisor;
        }
    }

    return remainder;
}

static void print_dec(unsigned long val)
{
    char buf[20];
    char *p = buf + sizeof(buf) - 1;
    *p = '\n';
    p--;

    if (val == 0) {
        *p = '0';
        p--;
    } else {
        while (val > 0) {
            *p = '0' + umod(val, 10);
            p--;
            val = udiv(val, 10);
        }
    }

    p++;
    printstr(p, (buf + sizeof(buf) - p));
}

static bool run_hanoi_test(hanoi_generator_t generator)
{
    static const hanoi_move_t expected[] = {
        {1, 'A', 'C'},
        {2, 'A', 'B'},
        {1, 'C', 'B'},
        {3, 'A', 'C'},
        {1, 'B', 'A'},
        {2, 'B', 'C'},
        {1, 'A', 'C'},
    };

    hanoi_move_t actual[7];
    generator(actual);

    bool passed = true;

    for (uint32_t i = 0; i < 7; i++) {
        const hanoi_move_t *exp = &expected[i];
        const hanoi_move_t *obs = &actual[i];

        if (exp->disk != obs->disk || exp->from != obs->from ||
            exp->to != obs->to) {
            passed = false;

            TEST_LOGGER("  FAILED at move ");
            print_dec((unsigned long) (i + 1));

            TEST_LOGGER("    Expected disk: ");
            print_dec((unsigned long) exp->disk);
            TEST_LOGGER("    Observed disk: ");
            print_dec((unsigned long) obs->disk);

            TEST_LOGGER("    Expected from: ");
            char exp_from[] = {exp->from, '\n'};
            printstr(exp_from, sizeof(exp_from));
            TEST_LOGGER("    Observed from: ");
            char obs_from[] = {obs->from, '\n'};
            printstr(obs_from, sizeof(obs_from));

            TEST_LOGGER("    Expected to: ");
            char exp_to[] = {exp->to, '\n'};
            printstr(exp_to, sizeof(exp_to));
            TEST_LOGGER("    Observed to: ");
            char obs_to[] = {obs->to, '\n'};
            printstr(obs_to, sizeof(obs_to));

            break;
        }
    }

    if (passed)
        TEST_LOGGER("  Tower of Hanoi Gray-code solver: PASSED\n");

    return passed;
}

static bool run_rsqrt_test(void)
{
    static const struct {
        uint32_t input;
        uint32_t expected;
    } rsqrt_cases[] = {
        {0u, 0u},
        {1u, 98304u},
        {4u, 32768u},
        {9u, 21829u},
        {16u, 16384u},
        {100u, 6534u},
        {255u, 4104u},
        {65536u, 256u},
    };

    static const struct {
        int32_t dx;
        int32_t dy;
        int32_t dz;
        uint32_t expected;
    } distance_cases[] = {
        {3, 4, 12, 12u},
        {100, 0, 0, 99u},
        {1000, 2000, 4000, 4486u},
        {12345, 6789, 1011, 9132u},
    };

    bool passed = true;

    for (uint32_t i = 0; i < (sizeof(rsqrt_cases) / sizeof(rsqrt_cases[0])); i++) {
        uint32_t observed = fast_rsqrt_asm(rsqrt_cases[i].input);

        if (observed != rsqrt_cases[i].expected) {
            passed = false;

            TEST_LOGGER("  FAILED fast_rsqrt_asm case ");
            print_dec((unsigned long) (i + 1));

            TEST_LOGGER("    Input: ");
            print_dec((unsigned long) rsqrt_cases[i].input);
            TEST_LOGGER("    Expected: ");
            print_dec((unsigned long) rsqrt_cases[i].expected);
            TEST_LOGGER("    Observed: ");
            print_dec((unsigned long) observed);

            break;
        }
    }

    if (passed) {
        for (uint32_t i = 0; i < (sizeof(distance_cases) / sizeof(distance_cases[0])); i++) {
            uint32_t observed =
                fast_distance_3d(distance_cases[i].dx, distance_cases[i].dy,
                                 distance_cases[i].dz);

            if (observed != distance_cases[i].expected) {
                passed = false;

                TEST_LOGGER("  FAILED fast_distance_3d case ");
                print_dec((unsigned long) (i + 1));

                TEST_LOGGER("    dx: ");
                print_dec((unsigned long) distance_cases[i].dx);
                TEST_LOGGER("    dy: ");
                print_dec((unsigned long) distance_cases[i].dy);
                TEST_LOGGER("    dz: ");
                print_dec((unsigned long) distance_cases[i].dz);

                TEST_LOGGER("    Expected distance: ");
                print_dec((unsigned long) distance_cases[i].expected);
                TEST_LOGGER("    Observed distance: ");
                print_dec((unsigned long) observed);

                break;
            }
        }
    }

    if (passed)
        TEST_LOGGER("  fast_rsqrt_asm / fast_distance_3d: PASSED\n");

    return passed;
}

int main(void)
{
    uint64_t start_ticks, end_ticks, ticks_elapsed;
    uint64_t start_cycles, end_cycles, cycles_elapsed;
    uint64_t start_instret, end_instret, instret_elapsed;

    TEST_LOGGER("\n=== Assembly Tests ===\n\n");
    TEST_LOGGER("Test: Tower of Hanoi (assembly implementation)\n");

    start_ticks = get_ticks();
    start_cycles = get_cycles();
    start_instret = get_instret();

    bool hanoi_passed = run_hanoi_test(hanoi_generate_moves_asm);

    end_ticks = get_ticks();
    end_cycles = get_cycles();
    end_instret = get_instret();
    ticks_elapsed = end_ticks - start_ticks;
    cycles_elapsed = end_cycles - start_cycles;
    instret_elapsed = end_instret - start_instret;

    TEST_LOGGER("  Ticks: ");
    print_dec((unsigned long) ticks_elapsed);
    TEST_LOGGER("  Cycles: ");
    print_dec((unsigned long) cycles_elapsed);
    TEST_LOGGER("  Instructions: ");
    print_dec((unsigned long) instret_elapsed);

    TEST_LOGGER("\nTest: fast reciprocal square root (rsqrt.S)\n");

    start_ticks = get_ticks();
    start_cycles = get_cycles();
    start_instret = get_instret();

    bool rsqrt_passed = run_rsqrt_test();

    end_ticks = get_ticks();
    end_cycles = get_cycles();
    end_instret = get_instret();
    ticks_elapsed = end_ticks - start_ticks;
    cycles_elapsed = end_cycles - start_cycles;
    instret_elapsed = end_instret - start_instret;

    TEST_LOGGER("  Ticks: ");
    print_dec((unsigned long) ticks_elapsed);
    TEST_LOGGER("  Cycles: ");
    print_dec((unsigned long) cycles_elapsed);
    TEST_LOGGER("  Instructions: ");
    print_dec((unsigned long) instret_elapsed);
    TEST_LOGGER("\n=== Assembly Tests Completed ===\n");

    return (hanoi_passed && rsqrt_passed) ? 0 : 1;
}
