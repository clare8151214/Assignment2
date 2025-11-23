#include <stdio.h>
#include <stdint.h>

int main(void) {
    uint32_t disk_pos[3] = {0, 0, 0};

    for (uint32_t n = 1; n < 8; n++) {
        uint32_t g = n ^ (n >> 1);
        uint32_t n_prev = n - 1;
        uint32_t g_prev = n_prev ^ (n_prev >> 1);

        uint32_t changed = g ^ g_prev;

        uint32_t disk;
        if (changed & 1) {
            disk = 0;
        } else if (changed & 2) {
            disk = 1;
        } else {
            disk = 2;
        }

        uint32_t from = disk_pos[disk];
        uint32_t to;

        if (disk == 0) {
            to = from + 2;
            if (to >= 3) to -= 3;
        } else {
            uint32_t small_pos = disk_pos[0];
            to = 3 - from - small_pos;
        }

        printf("Move Disk %u from %c to %c\n",
               disk + 1,
               'A' + from,
               'A' + to);

        disk_pos[disk] = to;
    }

    return 0;
}
