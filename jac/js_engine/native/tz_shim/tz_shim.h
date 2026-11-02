/*
 * tz_shim.h — IANA TZif timezone lookup C API for js_engine Temporal.
 *
 * Part of libjs_native.so.  Zone files are resolved from $TZDIR when set,
 * else /usr/share/zoneinfo/.
 */

#ifndef TZ_SHIM_H
#define TZ_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Load an IANA zone by name (e.g. "UTC", "America/New_York").
 * Returns an opaque handle (>0) or 0 on failure. */
int64_t tz_load(const char *name);

/* UTC offset in seconds and DST flag for the given POSIX epoch instant.
 * Writes offset_s and is_dst (0/1).  Returns 0 on success, -1 on error. */
int tz_offset_for_instant(int64_t handle, int64_t epoch_s,
                          int64_t *offset_s, int *is_dst);

/* Possible UTC offsets (seconds) for a local civil time expressed as epoch_s.
 * During DST overlap up to two offsets may be returned; during a gap zero.
 * offsets must point to room for at least max_count int64 values.
 * Returns the number of offsets written (0..max_count), or -1 on error. */
int tz_possible_offsets_for_local(int64_t handle, int64_t local_epoch_s,
                                  int64_t *offsets, int max_count);

/* Find the next/previous transition relative to epoch_s.
 * direction > 0  → smallest transition strictly after epoch_s
 * direction <= 0 → largest transition at or before epoch_s
 * Returns transition epoch_s, or -1 if none. */
int64_t tz_next_transition(int64_t handle, int64_t epoch_s, int direction);

/* Release a handle returned by tz_load(). */
void tz_unload(int64_t handle);

#ifdef __cplusplus
}
#endif

#endif /* TZ_SHIM_H */
