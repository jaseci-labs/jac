/* vec2 — a tiny self-contained 2D integer-vector lib (c2jac P4 fixture).
 * No system headers, so it preprocesses with pcpp + no fake libc. */
#ifndef VEC2_H
#define VEC2_H

#define VEC2_VERSION 1
#define SQR(x) ((x) * (x))

struct Vec2 {
    int x;
    int y;
};

struct Vec2 vec2_add(struct Vec2 a, struct Vec2 b);
int vec2_dot(struct Vec2 a, struct Vec2 b);
int vec2_len_sq(struct Vec2 v);
int vec2_sum_to(int n);

#endif /* VEC2_H */
