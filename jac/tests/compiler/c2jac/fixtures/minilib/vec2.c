#include "vec2.h"

struct Vec2 vec2_add(struct Vec2 a, struct Vec2 b) {
    struct Vec2 r;
    r.x = a.x + b.x;
    r.y = a.y + b.y;
    return r;
}

int vec2_dot(struct Vec2 a, struct Vec2 b) {
    return a.x * b.x + a.y * b.y;
}

int vec2_len_sq(struct Vec2 v) {
    return SQR(v.x) + SQR(v.y);
}

int vec2_sum_to(int n) {
    int total = 0;
    for (int i = 0; i < n; i++) {
        total = total + i;
    }
    return total;
}

/* Excluded unless -DVEC2_EXTRA — exercises conditional compilation. */
#ifdef VEC2_EXTRA
int vec2_version(void) {
    return VEC2_VERSION;
}
#endif
