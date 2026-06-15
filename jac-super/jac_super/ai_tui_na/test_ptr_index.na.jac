"""Test: can Jac NA write into a ptr via indexing?

If p[0] = 255 compiles and works, we could construct uint16_t[4] in Jac NA
without needing shim_write16, eliminating the last RGBA shim function.
Expected outcomes:
  - COMPILE ERROR if ptr indexing is not supported
  - Runtime proof if it works
"""

import from .tui_helpers { def tui_write(fd: i32, s: str) -> None;  }
import from .opentui_shim {
    def shim_alloc16(n: i32) -> ptr;  def shim_free(p: ptr) -> None;
}

glob p: ptr = shim_alloc16(4);
# Attempt to index and write into ptr directly from Jac NA
with entry {
    p[0] = 255;
    p[1] = 128;
    p[2] = 64;
    p[3] = 255;
    tui_write(2, "[ptr-idx] ptr[i] = val  PASS\n");
    shim_free(p);
}
