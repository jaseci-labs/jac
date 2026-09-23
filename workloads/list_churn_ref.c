/* C-equivalent ceiling for the list churn workload: one heap buffer, the
   header (len/cap/data) lives on the stack frame — what V2 builds for Jac. */
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    long n = 100000000;
    long cap = 8, len = 0;
    long *data = malloc(cap * sizeof(long));
    data[len++] = 1;
    long s = 0;
    for (long i = 0; i < n; i++) {
        if (len >= cap) {
            cap *= 2;
            data = realloc(data, cap * sizeof(long));
        }
        data[len++] = i;
        s += data[i];
    }
    printf("%ld\n", s % 7);
    free(data);
    return 0;
}
