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

extern uint64_t get_cycles(void);
extern uint64_t get_instret(void);
extern void hanoi_generate_moves_asm(hanoi_move_t moves[static 7]);

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

int main(void)
{
    uint64_t start_cycles, end_cycles, cycles_elapsed;
    uint64_t start_instret, end_instret, instret_elapsed;

    TEST_LOGGER("\n=== Hanoi (Assembly) Tests ===\n\n");
    TEST_LOGGER("Test: Tower of Hanoi (assembly implementation)\n");

    start_cycles = get_cycles();
    start_instret = get_instret();

    bool passed = run_hanoi_test(hanoi_generate_moves_asm);

    end_cycles = get_cycles();
    end_instret = get_instret();
    cycles_elapsed = end_cycles - start_cycles;
    instret_elapsed = end_instret - start_instret;

    TEST_LOGGER("  Cycles: ");
    print_dec((unsigned long) cycles_elapsed);
    TEST_LOGGER("  Instructions: ");
    print_dec((unsigned long) instret_elapsed);
    TEST_LOGGER("\n=== Hanoi Test Completed ===\n");

    return passed ? 0 : 1;
}
