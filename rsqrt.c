#include <stdint.h>

static const uint32_t rsqrt_table[32] = {
    65536, 46341, 32768, 23170, 16384, /* 2^0  to 2^4  */
    11585, 8192,  5793,  4096,  2896,  /* 2^5  to 2^9  */
    2048,  1448,  1024,  724,   512,   /* 2^10 to 2^14 */
    362,   256,   181,   128,   90,    /* 2^15 to 2^19 */
    64,    45,    32,    23,    16,    /* 2^20 to 2^24 */
    11,    8,     6,     4,     3,     /* 2^25 to 2^29 */
    2,     1                          /* 2^30, 2^31   */
};

/* 32-bit leading zero count */
static int clz32(uint32_t x)
{
    if (x == 0)
        return 32;

    int n = 0;
    if ((x & 0xFFFF0000u) == 0) { n += 16; x <<= 16; }
    if ((x & 0xFF000000u) == 0) { n += 8;  x <<= 8;  }
    if ((x & 0xF0000000u) == 0) { n += 4;  x <<= 4;  }
    if ((x & 0xC0000000u) == 0) { n += 2;  x <<= 2;  }
    if ((x & 0x80000000u) == 0) { n += 1; }
    return n;
}

/* 32x32 -> 64 multiply (can be replaced by RV32I shift-add version) */
static uint64_t mul32(uint32_t a, uint32_t b)
{
    return (uint64_t)a * (uint64_t)b;
}

uint64_t __muldi3(uint64_t a, uint64_t b)
{
    uint64_t result = 0;

    while (b) {
        if (b & 1)
            result += a;
        a <<= 1;
        b >>= 1;
    }

    return result;
}

/* Fast reciprocal square root with 2^16 fixed-point scaling:
 * returns y ≈ 2^16 / sqrt(x), for x > 0
 */
uint32_t fast_rsqrt(uint32_t x)
{
    if (x == 0)
        return 0;  /* or some saturated value, depending on spec */

    /* 1. Find exponent (MSB position) */
    int exp = 31 - clz32(x);              /* C03: 31 - clz(x) */

    /* 2. Initial estimate from lookup table */
    uint32_t y      = rsqrt_table[exp];   /* C04 */
    uint32_t y_next = (exp < 31) ? rsqrt_table[exp + 1] : 0;  /* C05 */

    /* 3. Linear interpolation between table[exp] and table[exp+1] */
    uint32_t delta = y - y_next;          /* C06 */

    /* frac = ((x - 2^exp) << 16) / 2^exp, but done with shifts */
    uint32_t frac = (uint32_t)
        ((((uint64_t)x - (1ULL << exp)) << 16) >> exp);       /* C07 */

    uint32_t interp = (uint32_t)
        (((uint64_t)delta * frac) >> 16);                     /* C08 */

    y = y - interp;  /* refined initial guess */

    /* 4. One Newton-Raphson iteration in 2^16 fixed point:
     *   y_{n+1} = y_n * (3 - x * y_n^2 / 2^16) / 2
     */

    uint32_t y2  = (uint32_t)mul32(y, y);                     /* C09 */
    uint32_t xy2 = (uint32_t)(mul32(x, y2) >> 16);            /* C10 */

    y = (uint32_t)(
        mul32(y, (3u << 16) - xy2) >> 17                      /* C11 */
    );

    return y;
}

/* Example usage: distance = sqrt(dx^2 + dy^2 + dz^2) approximation */
uint32_t fast_distance_3d(int32_t dx, int32_t dy, int32_t dz)
{
    uint64_t dist_sq = (uint64_t)dx * dx
                     + (uint64_t)dy * dy
                     + (uint64_t)dz * dz;

    if (dist_sq > 0xFFFFFFFFu)
        dist_sq >>= 16;

    uint32_t inv_dist = fast_rsqrt((uint32_t)dist_sq);

    /* sqrt(x) ≈ x * (1/sqrt(x)) */
    uint64_t dist = dist_sq * inv_dist;
    dist >>= 16;

    return (uint32_t)dist;
}
