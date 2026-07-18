/*
 * jacrt.c - implementation of the canonical Jac runtime ABI (see jacrt.h).
 *
 * Portable C mirror of the native LLVM runtime emitted by
 * passes/native/na_ir_gen_pass.impl/{refcount,vtable,exceptions}.impl.jac.
 */
#include "jacrt.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Compile-time guarantee that the header is exactly the ABI header size. */
typedef char jac_hdr_size_check[(sizeof(jac_header) == JAC_HDR_TOTAL) ? 1 : -1];

static int64_t jac_alloc_id_counter = 0;
static int64_t jac_live_counter = 0;

jac_header *jac_rc_hdr(void *user) {
    return (jac_header *)((char *)user + JAC_HDR_ALLOC_ID_OFF);
}

void *jac_rc_alloc(size_t size, int64_t type_id, jac_dtor_fn dtor) {
    char *raw = (char *)calloc(1, JAC_HDR_TOTAL + size);
    if (raw == NULL) {
        return NULL;
    }
    void *user = raw + JAC_HDR_TOTAL;
    jac_header *h = jac_rc_hdr(user);
    h->alloc_id = ++jac_alloc_id_counter;
    h->tag = (JAC_HDR_MAGIC << 32) | (type_id & 0xffffffffLL);
    h->rc = 1;
    h->dtor = dtor;
    jac_live_counter += 1;
    return user;
}

int64_t jac_rc_live(void) {
    return jac_live_counter;
}

void jac_rc_retain(void *user) {
    if (user == NULL) {
        return;
    }
    jac_rc_hdr(user)->rc += 1;
}

void jac_rc_release(void *user) {
    if (user == NULL) {
        return;
    }
    jac_header *h = jac_rc_hdr(user);
    h->rc -= 1;
    if (h->rc <= 0) {
        if (h->dtor != NULL) {
            h->dtor(user);
        }
        free(h);
        jac_live_counter -= 1;
    }
}

int64_t jac_rc_typeid(void *user) {
    return jac_rc_hdr(user)->tag & 0xffffffffLL;
}

int64_t jac_rc_count(void *user) {
    return jac_rc_hdr(user)->rc;
}

void *jac_vtable_slot(void *const *vtable, int index) {
    return (void *)vtable[JAC_VTABLE_HEADER_SLOTS + index];
}

/* --- strings ------------------------------------------------------------- */

char *jac_str_from_lit(const char *lit) {
    size_t n = strlen(lit);
    char *s = (char *)jac_rc_alloc(n + 1, JAC_TYPEID_STR, NULL);
    memcpy(s, lit, n + 1);
    return s;
}

char *jac_str_concat(const char *a, const char *b) {
    size_t na = strlen(a);
    size_t nb = strlen(b);
    char *s = (char *)jac_rc_alloc(na + nb + 1, JAC_TYPEID_STR, NULL);
    memcpy(s, a, na);
    memcpy(s + na, b, nb + 1);
    return s;
}

int64_t jac_str_len(const char *s) {
    return (int64_t)strlen(s);
}

int jac_str_eq(const char *a, const char *b) {
    return strcmp(a, b) == 0;
}

/* --- exceptions ---------------------------------------------------------- */

static jac_exc_frame *jac_exc_top = NULL;
static int64_t        jac_exc_type = 0;
static void          *jac_exc_payload = NULL;
static int            jac_exc_payload_owned = 0;

static void jac_exc_link(jac_exc_frame *frame, int catching) {
    frame->n_owned = 0;
    frame->catching = catching;
    frame->prev = jac_exc_top;
    jac_exc_top = frame;
}

void jac_exc_push(jac_exc_frame *frame) {
    jac_exc_link(frame, 1);
}

void jac_exc_push_cleanup(jac_exc_frame *frame) {
    jac_exc_link(frame, 0);
}

void jac_exc_pop(void) {
    if (jac_exc_top != NULL) {
        jac_exc_top = jac_exc_top->prev;
    }
}

void jac_exc_track(void *p) {
    jac_exc_frame *frame = jac_exc_top;
    if (p == NULL || frame == NULL || frame->n_owned >= JAC_EXC_OWNED_MAX) {
        return;
    }
    frame->owned[frame->n_owned++] = p;
}

void jac_exc_untrack(void *p) {
    jac_exc_frame *frame = jac_exc_top;
    int i;
    if (p == NULL || frame == NULL) {
        return;
    }
    for (i = frame->n_owned - 1; i >= 0; i--) {
        if (frame->owned[i] == p) {
            frame->n_owned -= 1;
            frame->owned[i] = frame->owned[frame->n_owned];
            return;
        }
    }
}

void jac_exc_landing_pad(jac_exc_frame *frame) {
    int i;
    if (frame == NULL) {
        return;
    }
    for (i = frame->n_owned - 1; i >= 0; i--) {
        jac_rc_release(frame->owned[i]);
        frame->owned[i] = NULL;
    }
    frame->n_owned = 0;
}

static void jac_exc_unwind_to_handler(void) {
    while (jac_exc_top != NULL) {
        jac_exc_frame *frame = jac_exc_top;
        jac_exc_top = frame->prev;
        jac_exc_landing_pad(frame);
        if (frame->catching) {
            longjmp(frame->env, 1);
        }
    }
    jac_exc_rethrow_uncaught();
}

static void jac_exc_set_current(int64_t type_id, void *payload, int owned) {
    if (jac_exc_payload_owned && jac_exc_payload != NULL && jac_exc_payload != payload) {
        jac_rc_release(jac_exc_payload);
    }
    jac_exc_type = type_id;
    jac_exc_payload = payload;
    jac_exc_payload_owned = owned;
}

void jac_exc_throw(int64_t type_id, void *payload) {
    jac_exc_set_current(type_id, payload, 0);
    jac_exc_unwind_to_handler();
}

void jac_exc_throw_owned(int64_t type_id, void *payload) {
    jac_exc_set_current(type_id, payload, 1);
    jac_exc_unwind_to_handler();
}

void jac_exc_rethrow(void) {
    jac_exc_unwind_to_handler();
}

int64_t jac_exc_current_type(void) {
    return jac_exc_type;
}

void *jac_exc_current_payload(void) {
    return jac_exc_payload;
}

void *jac_exc_take_payload(void) {
    void *p = jac_exc_payload;
    jac_exc_payload = NULL;
    jac_exc_payload_owned = 0;
    jac_exc_type = 0;
    return p;
}

void jac_exc_clear(void) {
    if (jac_exc_payload_owned && jac_exc_payload != NULL) {
        jac_rc_release(jac_exc_payload);
    }
    jac_exc_type = 0;
    jac_exc_payload = NULL;
    jac_exc_payload_owned = 0;
}

void jac_exc_rethrow_uncaught(void) {
    fprintf(stderr, "Uncaught exception: type %lld\n", (long long)jac_exc_type);
    abort();
}
