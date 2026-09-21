#include <stdint.h>

typedef struct { int64_t first, last; } Small;
typedef struct { int64_t first, last, length; } Large;

Small small_bytes(const unsigned char *data, int32_t n) {
    Small result = {n ? data[0] : 0, n ? data[n - 1] : 0};
    return result;
}

Large large_bytes(const unsigned char *data, int32_t n) {
    Large result = {n ? data[0] : 0, n ? data[n - 1] : 0, n};
    return result;
}

int64_t mixed_bytes(Small prefix, const unsigned char *a, const char *label,
                    const unsigned char *b, int32_t n) {
    return prefix.first + prefix.last + a[0] * 100 + b[n - 1] + label[0];
}
