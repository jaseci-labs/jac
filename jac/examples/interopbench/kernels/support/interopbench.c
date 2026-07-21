/* Deterministic C fixture for interopbench FFI cells (Phase 4).
 *
 * Every function here is pure, allocation-free, and produces a result that
 * a Jac-side reference can reproduce bit-for-bit, so the differential
 * identity oracle can compare a clib call against a Jac computation over
 * the same inputs. No clocks, no heap, no global state, no I/O.
 *
 * Built by harness/measure.jac with:
 *   cc -shared -fPIC -O2 -o bin/libinteropbench.so <this file>
 * and loaded via import-from in iop_ffi_struct / iop_ffi_vtable.
 */

#include <stdint.h>

/* ─── Struct-by-value: 4 sizes spanning the System V classes ─────────── */

/* 4-byte struct: one int. INTEGER class, single eightbyte. */
typedef struct { int32_t a; } ib_vec4;
_Static_assert(sizeof(ib_vec4) == 4, "ib_vec4 must be exactly 4 bytes");
ib_vec4 ib_vec4_make(int32_t a) { ib_vec4 v; v.a = a; return v; }
int32_t ib_vec4_sum(ib_vec4 v) { return v.a; }

/* 12-byte struct: three ints. INTEGER class, two eightbytes (one partial). */
typedef struct { int32_t a; int32_t b; int32_t c; } ib_vec12;
_Static_assert(sizeof(ib_vec12) == 12, "ib_vec12 must be exactly 12 bytes");
ib_vec12 ib_vec12_make(int32_t a, int32_t b, int32_t c) {
    ib_vec12 v; v.a = a; v.b = b; v.c = c; return v;
}
int32_t ib_vec12_sum(ib_vec12 v) { return v.a + v.b + v.c; }

/* 16-byte struct: four ints. INTEGER class, two full eightbytes. */
typedef struct { int32_t a; int32_t b; int32_t c; int32_t d; } ib_vec16;
_Static_assert(sizeof(ib_vec16) == 16, "ib_vec16 must be exactly 16 bytes");
ib_vec16 ib_vec16_make(int32_t a, int32_t b, int32_t c, int32_t d) {
    ib_vec16 v; v.a = a; v.b = b; v.c = c; v.d = d; return v;
}
int32_t ib_vec16_sum(ib_vec16 v) { return v.a + v.b + v.c + v.d; }

/* 24-byte struct: three int64s. MEMORY class (>16B) → byval param, sret return. */
typedef struct { int64_t a; int64_t b; int64_t c; } ib_vec24;
_Static_assert(sizeof(ib_vec24) == 24, "ib_vec24 must be exactly 24 bytes");
ib_vec24 ib_vec24_make(int64_t a, int64_t b, int64_t c) {
    ib_vec24 v; v.a = a; v.b = b; v.c = c; return v;
}
int64_t ib_vec24_sum(ib_vec24 v) { return v.a + v.b + v.c; }

/* 44-byte struct: eleven named ints. Firmly MEMORY class.
 * Eleven i32 fields (not a C array) so the Jac clib obj mirrors the layout
 * field-for-field without needing inline-array support in the foreign obj. */
typedef struct {
    int32_t v0;  int32_t v1;  int32_t v2;  int32_t v3;
    int32_t v4;  int32_t v5;  int32_t v6;  int32_t v7;
    int32_t v8;  int32_t v9;  int32_t v10;
} ib_vec44;
_Static_assert(sizeof(ib_vec44) == 44, "ib_vec44 must be exactly 44 bytes");
ib_vec44 ib_vec44_make(int32_t seed) {
    ib_vec44 s;
    s.v0  = (seed * 1)  % 1009;
    s.v1  = (seed * 2)  % 1009;
    s.v2  = (seed * 3)  % 1009;
    s.v3  = (seed * 4)  % 1009;
    s.v4  = (seed * 5)  % 1009;
    s.v5  = (seed * 6)  % 1009;
    s.v6  = (seed * 7)  % 1009;
    s.v7  = (seed * 8)  % 1009;
    s.v8  = (seed * 9)  % 1009;
    s.v9  = (seed * 10) % 1009;
    s.v10 = (seed * 11) % 1009;
    return s;
}
int32_t ib_vec44_sum(ib_vec44 s) {
    return s.v0 + s.v1 + s.v2 + s.v3 + s.v4
         + s.v5 + s.v6 + s.v7 + s.v8 + s.v9 + s.v10;
}

/* ─── Vtable callback (issue #6570 trampoline shape) ─────────────────── */

/* C-owned vtable struct: reads field 0 (size) and invokes the fn-ptr slot.
 * Mirrors the event_handler_vt fixture the trampoline test already covers. */
typedef struct {
    long size;
    int32_t (*on_event)(int32_t, int32_t);
} ib_handler_vt;

int64_t ib_invoke_event(ib_handler_vt* h, int32_t a, int32_t b) {
    if (h->on_event) {
        return (int64_t)h->on_event(a, b);
    }
    return -1;
}
