/* Reference C library for Jac's C pointer interop tests: out-params,
 * in-place mutation, scalar out-params, C-owned buffers, opaque handles and
 * a pointer the library retains between calls. */
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct { float x, y, z; } CpVec3;
typedef struct { CpVec3 position; CpVec3 target; float fovy; int32_t mode; } CpCamera;

void cp_camera_init(CpCamera *cam, float fovy) {
    cam->position = (CpVec3){0.0f, 2.0f, 4.0f};
    cam->target = (CpVec3){0.0f, 0.0f, 0.0f};
    cam->fovy = fovy;
    cam->mode = 1;
}

void cp_camera_orbit(CpCamera *cam, float dx) {
    cam->position.x += dx;
    cam->target.y -= dx;
    cam->mode += 1;
}

float cp_camera_span(const CpCamera *cam) {
    return (cam->position.x - cam->target.x) + (cam->position.y - cam->target.y)
        + (cam->position.z - cam->target.z);
}

float cp_camera_sum(CpCamera cam) {
    return cam.position.x + cam.position.y + cam.position.z + cam.fovy + (float)cam.mode;
}

CpCamera cp_camera_make(float fovy) {
    CpCamera cam;
    cp_camera_init(&cam, fovy);
    return cam;
}

void cp_window_size(int32_t *w, int32_t *h) {
    *w = 1280;
    *h = 720;
}

void cp_bump(int64_t *v, double *d, uint8_t *b, bool *flag) {
    *v += 1;
    *d *= 2.0;
    *b += 3;
    *flag = !*flag;
}

uint8_t *cp_buffer_new(int32_t n) {
    uint8_t *buf = (uint8_t *)malloc((size_t)n);
    for (int32_t i = 0; i < n; i++) buf[i] = (uint8_t)(i * 3);
    return buf;
}

int32_t cp_buffer_sum(const uint8_t *buf, int32_t n) {
    int32_t total = 0;
    for (int32_t i = 0; i < n; i++) total += buf[i];
    return total;
}

void cp_buffer_free(uint8_t *buf) { free(buf); }

CpVec3 *cp_points_new(int32_t n) {
    CpVec3 *pts = (CpVec3 *)malloc(sizeof(CpVec3) * (size_t)n);
    for (int32_t i = 0; i < n; i++) pts[i] = (CpVec3){(float)i, (float)(i * 2), 0.5f};
    return pts;
}

void cp_points_sort(CpVec3 *pts, int32_t n, int32_t (*before)(const CpVec3 *, const CpVec3 *)) {
    for (int32_t i = 1; i < n; i++) {
        CpVec3 cur = pts[i];
        int32_t j = i - 1;
        while (j >= 0 && before(&cur, &pts[j])) {
            pts[j + 1] = pts[j];
            j--;
        }
        pts[j + 1] = cur;
    }
}

float cp_points_sum(const CpVec3 *pts, int32_t n) {
    float total = 0.0f;
    for (int32_t i = 0; i < n; i++) total += pts[i].x + pts[i].y + pts[i].z;
    return total;
}

void cp_points_free(CpVec3 *pts) { free(pts); }

CpVec3 *cp_find(int32_t key) {
    static CpVec3 found = {7.0f, 8.0f, 9.0f};
    return key == 42 ? &found : NULL;
}

typedef struct CpDb { char name[32]; int32_t total; int32_t count; } CpDb;

int32_t cp_db_open(const char *name, CpDb **out) {
    if (name == NULL || name[0] == '\0') { *out = NULL; return 1; }
    CpDb *db = (CpDb *)calloc(1, sizeof(CpDb));
    strncpy(db->name, name, sizeof(db->name) - 1);
    *out = db;
    return 0;
}

int32_t cp_db_put(CpDb *db, int32_t v) { db->total += v; return ++db->count; }
int32_t cp_db_total(const CpDb *db) { return db->total; }
const char *cp_db_name(const CpDb *db) { return db->name; }
void cp_db_close(CpDb *db) { free(db); }

typedef struct { int32_t draws; int32_t last; void *vbo; CpVec3 tint; } CpBatch;

static CpBatch *active_batch = NULL;

void cp_batch_set_active(CpBatch *batch) { active_batch = batch; }
bool cp_batch_is_active(void) { return active_batch != NULL; }

int32_t cp_batch_draw(int32_t v) {
    if (active_batch == NULL) return -1;
    active_batch->draws += 1;
    active_batch->last = v;
    active_batch->tint.x += 0.5f;
    return active_batch->draws;
}

static int32_t *retained_counter = NULL;
void cp_counter_retain(int32_t *counter) { retained_counter = counter; }
void cp_counter_tick(void) { if (retained_counter) *retained_counter += 10; }

/* An optional scalar out-parameter: written only when the caller passes one. */
int32_t cp_maybe_count(int64_t *out) {
    if (!out) return 0;
    *out = 7;
    return 1;
}

typedef struct { int32_t count; CpVec3 *items; } CpPointList;

void cp_pointlist_fill(CpPointList *pl, int32_t n) {
    pl->count = n;
    pl->items = cp_points_new(n);
}

int32_t cp_global_count = 7;
bool cp_global_flag = true;
CpVec3 cp_global_origin = {1.0f, 2.0f, 3.0f};
CpVec3 *cp_global_origin_ref = &cp_global_origin;
int32_t cp_global_read(void) { return cp_global_count; }

typedef struct {
    int32_t count;
    int32_t (*scale)(int32_t);
    const char *label;
    CpVec3 *origin;
} CpRecipe;

int32_t cp_recipe_run(const CpRecipe *r, int32_t v) { return r->scale(v) + r->count; }
int32_t cp_label_len(const char *s) { return (int32_t)strlen(s); }

/* A table of type-erased function pointers, as CPython's method tables hold
 * PyCFunction casts of functions with other signatures. */
typedef struct {
    const char *name;
    void *fn;
} CpErased;

int64_t cp_erased_call(const CpErased *e, int64_t a, int64_t b) {
    return ((int64_t (*)(int64_t, int64_t))e->fn)(a, b);
}
int64_t cp_address_call(void *fn, int64_t a) { return ((int64_t (*)(int64_t))fn)(a); }
int32_t cp_call_i32(void *fn, int32_t v) { return ((int32_t (*)(int32_t))fn)(v); }
