/*
 * jacrt.h - canonical Jac runtime ABI for the C emission backend (jac2c, #7145).
 *
 * This header defines, in portable C, the *same* runtime object model the native
 * LLVM backend emits inline (under passes/native/na_ir_gen_pass.impl). Both
 * backends agree by construction: the layout constants below are the single source
 * of truth mirrored from na_ir_gen_pass.jac:
 *
 *     HDR_ALLOC_ID_OFF = -32   (relative to the user pointer)
 *     HDR_TAG_OFF      = -24   ((MAGIC << 32) | type_id)
 *     HDR_RC_OFF       = -16   (reference count)
 *     HDR_DTOR_OFF     = -8    (destructor function pointer)
 *     HDR_TOTAL        = 32    (header bytes preceding the user pointer)
 *     HDR_MAGIC        = 44061
 *
 * A heap object's "user pointer" points HDR_TOTAL bytes past the raw allocation;
 * the 32-byte header lives immediately before it, exactly as the native backend
 * lays it out. Conformance is behavioral (whole-program C vs whole-program
 * native), not byte-identity across a C<->native link boundary.
 */
#ifndef JACRT_H
#define JACRT_H

#include <stddef.h>
#include <stdint.h>
#include <setjmp.h>

#ifdef __cplusplus
extern "C" {
#endif

#define JAC_HDR_ALLOC_ID_OFF (-32)
#define JAC_HDR_TAG_OFF      (-24)
#define JAC_HDR_RC_OFF       (-16)
#define JAC_HDR_DTOR_OFF     (-8)
#define JAC_HDR_TOTAL        (32)
#define JAC_HDR_MAGIC        ((int64_t)44061)

typedef void (*jac_dtor_fn)(void *user);

/* The header preceding every RC object's user pointer. sizeof == JAC_HDR_TOTAL
 * on any LP64 target (3 * int64 + 1 pointer == 32). */
typedef struct jac_header {
    int64_t     alloc_id;   /* user - 32 : monotonic id for leak/double-free debug */
    int64_t     tag;        /* user - 24 : (JAC_HDR_MAGIC << 32) | type_id          */
    int64_t     rc;         /* user - 16 : reference count                          */
    jac_dtor_fn dtor;       /* user -  8 : per-type destructor, or NULL             */
} jac_header;

/* Reserved type ids used by the runtime itself. User archetype ids start at 1. */
#define JAC_TYPEID_RAW 0
#define JAC_TYPEID_STR 1

/* Immortal refcount sentinel, mirroring the native backend's RC_SENTINEL
 * (na_ir_gen_pass.jac). An object whose rc slot holds this is never retained,
 * released, or freed -- retain/release are no-ops. Used for string literals and
 * other statically-allocated, process-lifetime constants. */
#define JAC_RC_IMMORTAL ((int64_t)0x7fffffffffffffffLL)

/* Define a statically-allocated immortal string, exactly as the native backend
 * emits string literals: a 16-byte header (rc, dtor) immediately preceding the
 * NUL-terminated bytes, so the "string value" `name` is `&storage.data[0]` with
 * rc at value-16 and dtor at value-8. No heap allocation, never freed, and
 * retain/release on it are no-ops (rc == JAC_RC_IMMORTAL). `s` must be a string
 * literal so `sizeof` captures its length. */
#define JAC_STR_LITERAL(name, s)                                             \
    static struct { int64_t rc; int64_t dtor; char data[sizeof(s)]; }        \
        name##__storage = { JAC_RC_IMMORTAL, 0, s };                         \
    static char *const name = name##__storage.data

/* --- object lifecycle ---------------------------------------------------- */

/* Allocate `size` payload bytes (zeroed) behind a fresh RC header. Returns the
 * user pointer. rc starts at 1. */
void   *jac_rc_alloc(size_t size, int64_t type_id, jac_dtor_fn dtor);
void    jac_rc_retain(void *user);
void    jac_rc_release(void *user);
int64_t jac_rc_typeid(void *user);
int64_t jac_rc_count(void *user);

/* Number of live RC allocations (allocated minus freed). Zero after a
 * balanced program; a leak leaves it positive, a double-free drives it
 * negative. Intended for conformance/leak assertions. */
int64_t jac_rc_live(void);
jac_header *jac_rc_hdr(void *user);

/* --- vtable dispatch ----------------------------------------------------- */

/* A vtable is `void*[]` whose slot 0 (JAC_VTABLE_HEADER_SLOTS) is the class-name
 * const, followed by one function pointer per method slot -- matching the native
 * backend's VTABLE_HEADER_SLOTS = 1. */
#define JAC_VTABLE_HEADER_SLOTS 1
void *jac_vtable_slot(void *const *vtable, int index);

/* --- runtime strings ----------------------------------------------------- */

/* Jac strings are RC objects whose payload is a NUL-terminated byte buffer; the
 * user pointer *is* the char data (type_id == JAC_TYPEID_STR). */
char *jac_str_from_lit(const char *lit);
char *jac_str_concat(const char *a, const char *b);
int64_t jac_str_len(const char *s);
int     jac_str_eq(const char *a, const char *b);

/* --- exceptions (setjmp/longjmp) ----------------------------------------- */

/* setjmp/longjmp plus landing-pad ownership: each frame records owned RC
 * pointers introduced while it is current. On throw, every frame between the
 * raise and the catching handler runs its landing pad (releases owned), then
 * the catching frame longjmps. Cleanup-only frames (function scopes) have no
 * setjmp; catching frames do. This is what makes RC compose with exceptions --
 * without it, longjmp skips scope_release epilogues and leaks. */
#define JAC_EXC_OWNED_MAX 64

typedef struct jac_exc_frame {
    jmp_buf                env;
    struct jac_exc_frame  *prev;
    void                  *owned[JAC_EXC_OWNED_MAX];
    int                    n_owned;
    int                    catching; /* 1 = setjmp handler; 0 = cleanup-only */
} jac_exc_frame;

void     jac_exc_push(jac_exc_frame *frame);         /* catching frame           */
void     jac_exc_push_cleanup(jac_exc_frame *frame); /* function-scope cleanup   */
void     jac_exc_pop(void);                          /* unlink; no release       */
void     jac_exc_track(void *p);                     /* record owned on top      */
void     jac_exc_untrack(void *p);                   /* drop before normal release */
void     jac_exc_landing_pad(jac_exc_frame *frame);  /* release frame's owned    */
void     jac_exc_throw(int64_t type_id, void *payload);       /* borrowed payload */
void     jac_exc_throw_owned(int64_t type_id, void *payload); /* takes RC ownership */
void     jac_exc_rethrow(void);                      /* continue with current    */
int64_t  jac_exc_current_type(void);
void    *jac_exc_current_payload(void);
void    *jac_exc_take_payload(void);                 /* clear + transfer ownership */
void     jac_exc_clear(void);                        /* consume; release if owned */
void     jac_exc_rethrow_uncaught(void);

#ifdef __cplusplus
}
#endif

#endif /* JACRT_H */
