"""Test: ptr subscript read — p[i] without assignment."""

import from .tui_helpers { def tui_write(fd: i32, s: str) -> None;  }
import from .opentui_shim {
    def shim_alloc16(n: i32) -> ptr;  def shim_free(p: ptr) -> None;  def shim_write16(
        p: ptr, idx: i32, val: i32
    ) -> None;
}

glob p: ptr = shim_alloc16(4);

with entry {
    shim_write16(p, 0, 255);
}

# Attempt subscript read
glob v: int = p[0];

with entry {
    tui_write(2, f"[ptr-read] p[0] = {v}\n");
    shim_free(p);
}
