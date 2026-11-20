/* compiler-rt builtins the wasm32 backend emits libcalls for.
 *
 * zig ships compiler-rt as Zig source, so there is no C we can compile to
 * bitcode; the set the jac floor can actually trigger is tiny (128-bit
 * multiply from i64 overflow-checked arithmetic), so it lives here.
 *
 * Written with 32-bit half-word arithmetic only — a 128-bit `*` in this file
 * would lower right back into a __multi3 libcall and recurse.
 */
typedef unsigned long long u64;

/* full 64x64 -> 128 multiply; returns low half, stores high half in *hi */
static u64 mul64wide(u64 a, u64 b, u64 *hi) {
    u64 alo = a & 0xffffffffu, ahi = a >> 32;
    u64 blo = b & 0xffffffffu, bhi = b >> 32;
    u64 ll = alo * blo;
    u64 lh = alo * bhi;
    u64 hl = ahi * blo;
    u64 hh = ahi * bhi;
    u64 mid = (ll >> 32) + (lh & 0xffffffffu) + (hl & 0xffffffffu);
    *hi = hh + (lh >> 32) + (hl >> 32) + (mid >> 32);
    return (mid << 32) | (ll & 0xffffffffu);
}

__int128 __multi3(__int128 a, __int128 b) {
    u64 alo = (u64)a, ahi = (u64)((unsigned __int128)a >> 64);
    u64 blo = (u64)b, bhi = (u64)((unsigned __int128)b >> 64);
    u64 hi;
    u64 lo = mul64wide(alo, blo, &hi);
    hi += alo * bhi + ahi * blo;
    return (__int128)(((unsigned __int128)hi << 64) | lo);
}
