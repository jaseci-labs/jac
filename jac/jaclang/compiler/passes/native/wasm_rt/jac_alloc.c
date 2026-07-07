/* In-module allocator for the jac native wasm floor.
 *
 * Replaces the `env.malloc`/`env.free` host imports every JS shim used to
 * hand-implement over exported memory. Heap starts at the linker-provided
 * `__heap_base` (the jac WasmLinker resolves the undefined data symbol to the
 * first byte above the stack) and grows with wasm `memory.grow`.
 *
 * Design: boundary-tag free list, address-ordered first-fit, immediate
 * coalescing with both neighbors, 16-byte aligned payloads. Single-threaded
 * (wasm MVP has one thread). Header holds the chunk size with the low bit as
 * the in-use flag; footer mirrors the header so `free` can coalesce left.
 */
#include <stddef.h>
#include <string.h>

extern unsigned char __heap_base[];

#define ALIGN 16u
#define HDR 8u /* header + footer are one size_t each, but keep 8 for i32 wasm */
#define MIN_CHUNK (2 * HDR + ALIGN)
#define USED 1u

typedef struct chunk {
    size_t size; /* whole chunk size incl. header/footer; low bit = USED */
    struct chunk *next; /* free list link (valid only when free) */
    struct chunk *prev;
} chunk_t;

static chunk_t *free_list;
static unsigned char *heap_top; /* first never-carved byte */
static unsigned char *heap_end; /* current end of grown memory */

static size_t csize(const chunk_t *c) { return c->size & ~USED; }

static void set_size(chunk_t *c, size_t sz, size_t used) {
    c->size = sz | used;
    *(size_t *)((unsigned char *)c + sz - HDR) = sz | used;
}

static chunk_t *right_of(chunk_t *c) {
    return (chunk_t *)((unsigned char *)c + csize(c));
}

static void unlink_free(chunk_t *c) {
    if (c->prev) { c->prev->next = c->next; } else { free_list = c->next; }
    if (c->next) { c->next->prev = c->prev; }
}

static void push_free(chunk_t *c) {
    c->next = free_list;
    c->prev = 0;
    if (free_list) { free_list->prev = c; }
    free_list = c;
}

static int grow_to(unsigned char *want) {
    if (want <= heap_end) { return 1; }
    size_t cur_pages = __builtin_wasm_memory_size(0);
    size_t need = (size_t)(want - heap_end + 0xffffu) >> 16;
    if (__builtin_wasm_memory_grow(0, need) == (size_t)-1) { return 0; }
    (void)cur_pages;
    heap_end = (unsigned char *)(__builtin_wasm_memory_size(0) << 16);
    return 1;
}

static void init_heap(void) {
    if (heap_top) { return; }
    size_t base = (size_t)__heap_base;
    heap_top = (unsigned char *)((base + ALIGN - 1) & ~(size_t)(ALIGN - 1));
    heap_end = (unsigned char *)(__builtin_wasm_memory_size(0) << 16);
}

void *malloc(size_t n) {
    init_heap();
    if (n == 0) { n = 1; }
    size_t need = (n + HDR + HDR + ALIGN - 1) & ~(size_t)(ALIGN - 1);
    if (need < MIN_CHUNK) { need = MIN_CHUNK; }
    /* address-ordered first fit keeps fragmentation predictable */
    chunk_t *best = 0;
    for (chunk_t *c = free_list; c; c = c->next) {
        if (csize(c) >= need && (!best || c < best)) { best = c; }
    }
    if (best) {
        unlink_free(best);
        size_t rest = csize(best) - need;
        if (rest >= MIN_CHUNK) {
            set_size(best, need, USED);
            chunk_t *split = right_of(best);
            set_size(split, rest, 0);
            push_free(split);
        } else {
            set_size(best, csize(best), USED);
        }
        return (unsigned char *)best + HDR;
    }
    if (!grow_to(heap_top + need)) { return 0; }
    chunk_t *c = (chunk_t *)heap_top;
    heap_top += need;
    set_size(c, need, USED);
    return (unsigned char *)c + HDR;
}

void free(void *p) {
    if (!p) { return; }
    chunk_t *c = (chunk_t *)((unsigned char *)p - HDR);
    size_t sz = csize(c);
    /* coalesce right */
    unsigned char *rgt = (unsigned char *)c + sz;
    if (rgt < heap_top) {
        chunk_t *r = (chunk_t *)rgt;
        if (!(r->size & USED)) {
            unlink_free(r);
            sz += csize(r);
        }
    }
    /* coalesce left via the footer just below us */
    if ((unsigned char *)c > (unsigned char *)__heap_base + ALIGN) {
        size_t lsz = *(size_t *)((unsigned char *)c - HDR);
        if (!(lsz & USED)) {
            chunk_t *l = (chunk_t *)((unsigned char *)c - (lsz & ~USED));
            unlink_free(l);
            c = l;
            sz += lsz & ~USED;
        }
    }
    /* give the top chunk back to the bump region */
    if ((unsigned char *)c + sz == heap_top) {
        heap_top = (unsigned char *)c;
        return;
    }
    set_size(c, sz, 0);
    push_free(c);
}

void *calloc(size_t nm, size_t sz) {
    if (sz && nm > (size_t)-1 / sz) { return 0; }
    size_t n = nm * sz;
    void *p = malloc(n);
    if (p) { memset(p, 0, n); }
    return p;
}

void *realloc(void *p, size_t n) {
    if (!p) { return malloc(n); }
    if (!n) {
        free(p);
        return 0;
    }
    chunk_t *c = (chunk_t *)((unsigned char *)p - HDR);
    size_t avail = csize(c) - 2 * HDR;
    if (avail >= n) { return p; }
    void *q = malloc(n);
    if (!q) { return 0; }
    memcpy(q, p, avail);
    free(p);
    return q;
}

/* The GC debug floor probes live allocation sizes with this. */
size_t malloc_usable_size(void *p) {
    if (!p) { return 0; }
    chunk_t *c = (chunk_t *)((unsigned char *)p - HDR);
    return csize(c) - 2 * HDR;
}
