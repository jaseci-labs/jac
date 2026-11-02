"""IANA timezone shim FFI bindings for js_engine Temporal.

Thin wrapper over the TZif v1/v2/v3 parser in libjs_native.so.
Other modules should import from this file rather than the .so directly.

  import from engine.src.ffi.tz {
      tz_load, tz_offset_for_instant, tz_unload, ...
  }

Zone files are resolved from share/tzdata/ first, then /usr/share/zoneinfo/.
Override with TZDATA_PATH environment variable.
"""

import from "libjs_native.so" {
    def tz_load(name: str) -> int;  def tz_offset_for_instant(
        handle: int, epoch_s: int, offset_out: int, is_dst_out: int
    ) -> int;  def tz_possible_offsets_for_local(
        handle: int, local_epoch_s: int, offsets: int, max_count: int
    ) -> int;  def tz_next_transition(
        handle: int, epoch_s: int, direction: int
    ) -> int;  def tz_unload(handle: int) -> None;
}

import from engine.src.runtime.mem { io_alloc, read_i32, write_i64 }

"""Load an IANA zone; returns handle (>0) or 0 on failure."""
def:pub tz_load_zone(name: str) -> int {
    return tz_load(name);
}

"""UTC offset (seconds) and DST flag for a POSIX instant."""
def:pub tz_get_offset(handle: int, epoch_s: int) -> tuple[int, bool] {
    buf: int = io_alloc(16);
    rc: int = tz_offset_for_instant(handle, epoch_s, buf, buf + 8);
    if rc != 0 {
        return (0, False);
    }
    off: int = read_i32(buf, 0);
    dst: bool = read_i32(buf, 8) != 0;
    return (off, dst);
}

"""Write up to max_count possible UTC offsets for a local civil time into offsets_buf (int64[]).
Returns count written, or -1 on error."""
def:pub tz_get_possible_offsets(
    handle: int, local_epoch_s: int, offsets_buf: int, max_count: int
) -> int {
    return tz_possible_offsets_for_local(handle, local_epoch_s, offsets_buf, max_count);
}

"""Find next (>0 direction) or previous (<=0) transition epoch, or -1."""
def:pub tz_get_next_transition(handle: int, epoch_s: int, forward: bool) -> int {
    dir: int = 1 if forward else -1;
    return tz_next_transition(handle, epoch_s, dir);
}

"""Store one int64 offset into a buffer at byte offset."""
def:pub tz_write_offset(buf: int, index: int, offset_s: int) {
    write_i64(buf, index * 8, offset_s);
}
