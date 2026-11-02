/*
 * tz_shim.c — IANA TZif v1/v2/v3 parser for js_engine Temporal.
 *
 * Reads zone files from $TZDIR when set, else /usr/share/zoneinfo/ (the
 * lookup glibc and Python's zoneinfo make).
 */

#include "tz_shim.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#define TZ_MAGIC "TZif"
#define TZ_HEADER_SIZE 44
#define TZ_MAX_HANDLES 128
#define TZ_NAME_MAX 256

typedef struct {
    int32_t  gmtoff;
    uint8_t  isdst;
    uint8_t  abbrind;
} tz_ttinfo;

typedef struct {
    int64_t  *transitions;
    uint8_t  *types;
    int       ntrans;
    tz_ttinfo *ttinfo;
    int       ntypes;
    char     *abbrs;
    int       nabbrs;
} tz_data;

typedef struct {
    int      in_use;
    char     name[TZ_NAME_MAX];
    tz_data  data;
} tz_slot;

static tz_slot g_slots[TZ_MAX_HANDLES];
static int     g_next_id = 1;

/* ── Endian helpers ─────────────────────────────────────────────────────────── */

static int32_t read_be32(const uint8_t *p) {
    return ((int32_t)p[0] << 24) | ((int32_t)p[1] << 16)
         | ((int32_t)p[2] << 8)  |  (int32_t)p[3];
}

static int64_t read_be64(const uint8_t *p) {
    uint64_t hi = (uint64_t)read_be32(p);
    uint64_t lo = (uint64_t)(uint32_t)read_be32(p + 4);
    return (int64_t)((hi << 32) | lo);
}

static int32_t read_be32_signed(const uint8_t *p) {
    return read_be32(p);
}

/* ── TZif parsing ───────────────────────────────────────────────────────────── */

static void tz_data_free(tz_data *d) {
    free(d->transitions);
    free(d->types);
    free(d->ttinfo);
    free(d->abbrs);
    memset(d, 0, sizeof(*d));
}

static int parse_tzif_block(const uint8_t *data, size_t len, size_t *consumed,
                            tz_data *out, int use_64bit) {
    if (len < TZ_HEADER_SIZE) return -1;
    if (memcmp(data, TZ_MAGIC, 4) != 0) return -1;

    int32_t ttisgmtcnt = read_be32(data + 20);
    int32_t ttisstdcnt = read_be32(data + 24);
    int32_t leapcnt    = read_be32(data + 28);
    int32_t timecnt    = read_be32(data + 32);
    int32_t typecnt    = read_be32(data + 36);
    int32_t charcnt    = read_be32(data + 40);

    if (timecnt < 0 || typecnt <= 0 || charcnt < 0
        || ttisgmtcnt < 0 || ttisstdcnt < 0 || leapcnt < 0) {
        return -1;
    }

    size_t off = TZ_HEADER_SIZE;
    size_t tsize = use_64bit ? 8 : 4;
    size_t need = (size_t)timecnt * tsize
                + (size_t)timecnt
                + (size_t)typecnt * 6
                + (size_t)charcnt
                + (size_t)leapcnt * (use_64bit ? 12 : 8)
                + (size_t)ttisstdcnt
                + (size_t)ttisgmtcnt;
    if (off + need > len) return -1;

    int64_t *trans = NULL;
    uint8_t *types = NULL;
    tz_ttinfo *tti = NULL;
    char *abbrs = NULL;

    if (timecnt > 0) {
        trans = (int64_t *)calloc((size_t)timecnt, sizeof(int64_t));
        types = (uint8_t *)calloc((size_t)timecnt, sizeof(uint8_t));
        if (!trans || !types) goto fail;
        for (int32_t i = 0; i < timecnt; i++) {
            if (use_64bit) {
                trans[i] = read_be64(data + off + (size_t)i * 8);
            } else {
                trans[i] = (int64_t)read_be32_signed(data + off + (size_t)i * 4);
            }
        }
    }
    off += (size_t)timecnt * tsize;

    if (timecnt > 0) {
        memcpy(types, data + off, (size_t)timecnt);
        off += (size_t)timecnt;
    }

    tti = (tz_ttinfo *)calloc((size_t)typecnt, sizeof(tz_ttinfo));
    if (!tti) goto fail;
    for (int32_t i = 0; i < typecnt; i++) {
        const uint8_t *e = data + off + (size_t)i * 6;
        tti[i].gmtoff  = read_be32_signed(e);
        tti[i].isdst   = e[4];
        tti[i].abbrind = e[5];
    }
    off += (size_t)typecnt * 6;

    abbrs = (char *)malloc((size_t)charcnt + 1);
    if (!abbrs) goto fail;
    memcpy(abbrs, data + off, (size_t)charcnt);
    abbrs[charcnt] = '\0';
    off += (size_t)charcnt;

    off += (size_t)leapcnt * (use_64bit ? 12 : 8);
    off += (size_t)ttisstdcnt;
    off += (size_t)ttisgmtcnt;

    tz_data_free(out);
    out->transitions = trans;
    out->types       = types;
    out->ntrans      = timecnt;
    out->ttinfo      = tti;
    out->ntypes      = typecnt;
    out->abbrs       = abbrs;
    out->nabbrs      = charcnt;
    *consumed = off;
    return 0;

fail:
    free(trans);
    free(types);
    free(tti);
    free(abbrs);
    return -1;
}

static int parse_tzif_file(const uint8_t *data, size_t len, tz_data *out) {
    if (len < TZ_HEADER_SIZE || memcmp(data, TZ_MAGIC, 4) != 0) return -1;

    char version = (char)data[4];
    if (version == '2' || version == '3') {
        /* Skip the v1-compatible block, then parse the 64-bit block. */
        size_t consumed = 0;
        if (parse_tzif_block(data, len, &consumed, out, 0) != 0) return -1;
        if (consumed + TZ_HEADER_SIZE > len) return -1;
        const uint8_t *v2 = data + consumed;
        size_t v2_len = len - consumed;
        if (v2_len < 4 || memcmp(v2, TZ_MAGIC, 4) != 0) return -1;
        size_t consumed2 = 0;
        return parse_tzif_block(v2, v2_len, &consumed2, out, 1);
    }

    size_t consumed = 0;
    return parse_tzif_block(data, len, &consumed, out, version == '\0' ? 0 : 1);
}

/* ── Zone file loading ──────────────────────────────────────────────────────── */

static int try_open_zone(const char *root, const char *name, uint8_t **out, size_t *out_len) {
    char path[512];
    if (snprintf(path, sizeof(path), "%s/%s", root, name) >= (int)sizeof(path))
        return -1;

    FILE *f = fopen(path, "rb");
    if (!f) return -1;

    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return -1; }
    long sz = ftell(f);
    if (sz <= 0 || sz > 1024 * 1024) { fclose(f); return -1; }
    if (fseek(f, 0, SEEK_SET) != 0) { fclose(f); return -1; }

    uint8_t *buf = (uint8_t *)malloc((size_t)sz);
    if (!buf) { fclose(f); return -1; }
    if (fread(buf, 1, (size_t)sz, f) != (size_t)sz) {
        free(buf);
        fclose(f);
        return -1;
    }
    fclose(f);
    *out = buf;
    *out_len = (size_t)sz;
    return 0;
}

static int load_zone_data(const char *name, tz_data *out) {
    uint8_t *buf = NULL;
    size_t len = 0;
    const char *env = getenv("TZDIR");

    if (env && env[0] && try_open_zone(env, name, &buf, &len) == 0) goto parsed;
    if (try_open_zone("/usr/share/zoneinfo", name, &buf, &len) == 0) goto parsed;

    return -1;

parsed:
    {
        int rc = parse_tzif_file(buf, len, out);
        free(buf);
        return rc;
    }
}

/* ── Offset lookup ──────────────────────────────────────────────────────────── */

static int offset_for_instant_data(const tz_data *d, int64_t epoch_s,
                                   int64_t *offset_s, int *is_dst) {
    if (!d || d->ntypes <= 0 || !d->ttinfo) return -1;

    int type_idx = 0;
    if (d->ntrans > 0 && d->transitions && d->types) {
        if (epoch_s < d->transitions[0]) {
            type_idx = 0;
        } else {
            int lo = 0, hi = d->ntrans - 1, found = 0;
            while (lo <= hi) {
                int mid = lo + (hi - lo) / 2;
                if (d->transitions[mid] <= epoch_s) {
                    found = mid;
                    lo = mid + 1;
                } else {
                    hi = mid - 1;
                }
            }
            type_idx = (int)d->types[found];
        }
    }

    if (type_idx < 0 || type_idx >= d->ntypes) return -1;
    *offset_s = d->ttinfo[type_idx].gmtoff;
    *is_dst   = d->ttinfo[type_idx].isdst ? 1 : 0;
    return 0;
}

static tz_slot *slot_from_handle(int64_t handle) {
    if (handle <= 0 || handle >= TZ_MAX_HANDLES) return NULL;
    tz_slot *s = &g_slots[(int)handle];
    return s->in_use ? s : NULL;
}

/* ── Public API ─────────────────────────────────────────────────────────────── */

int64_t tz_load(const char *name) {
    if (!name || !name[0]) return 0;

    int slot_idx = -1;
    for (int i = 1; i < TZ_MAX_HANDLES; i++) {
        if (!g_slots[i].in_use) { slot_idx = i; break; }
    }
    if (slot_idx < 0) return 0;

    tz_slot *s = &g_slots[slot_idx];
    memset(s, 0, sizeof(*s));
    if (load_zone_data(name, &s->data) != 0) return 0;

    s->in_use = 1;
    strncpy(s->name, name, TZ_NAME_MAX - 1);
    s->name[TZ_NAME_MAX - 1] = '\0';
    return (int64_t)slot_idx;
}

int tz_offset_for_instant(int64_t handle, int64_t epoch_s,
                          int64_t *offset_s, int *is_dst) {
    tz_slot *s = slot_from_handle(handle);
    if (!s || !offset_s || !is_dst) return -1;
    return offset_for_instant_data(&s->data, epoch_s, offset_s, is_dst);
}

int tz_possible_offsets_for_local(int64_t handle, int64_t local_epoch_s,
                                  int64_t *offsets, int max_count) {
    tz_slot *s = slot_from_handle(handle);
    if (!s || max_count <= 0 || !offsets) return -1;

    tz_data *d = &s->data;
    int written = 0;

    for (int i = 0; i < d->ntypes; i++) {
        int64_t cand = d->ttinfo[i].gmtoff;
        int dup = 0;
        for (int j = 0; j < written; j++) {
            if (offsets[j] == cand) { dup = 1; break; }
        }
        if (dup) continue;

        int64_t instant = local_epoch_s - cand;
        int64_t off = 0;
        int is_dst = 0;
        if (offset_for_instant_data(d, instant, &off, &is_dst) != 0) continue;
        if (off != cand) continue;

        offsets[written++] = off;
        if (written >= max_count) break;
    }

    return written;
}

int64_t tz_next_transition(int64_t handle, int64_t epoch_s, int direction) {
    tz_slot *s = slot_from_handle(handle);
    if (!s) return -1;

    tz_data *d = &s->data;
    if (d->ntrans <= 0 || !d->transitions) return -1;

    if (direction > 0) {
        for (int i = 0; i < d->ntrans; i++) {
            if (d->transitions[i] > epoch_s) return d->transitions[i];
        }
        return -1;
    }

    for (int i = d->ntrans - 1; i >= 0; i--) {
        /* Strict < so "previous" of a transition epoch advances past it. */
        if (d->transitions[i] < epoch_s) return d->transitions[i];
    }
    return -1;
}

void tz_unload(int64_t handle) {
    tz_slot *s = slot_from_handle(handle);
    if (!s) return;
    tz_data_free(&s->data);
    memset(s, 0, sizeof(*s));
}
