"""EXPECTED: compile error — `ptr` is not a valid Jac NA FFI type.

This file proves the scalar-only boundary by attempting to declare
bufferFillRect with a `ptr` type for the RGBA array argument.
nacompile should reject this before emitting any LLVM IR.
"""

import from .tui_helpers { def tui_write(fd: i32, s: str) -> None;  }

# bufferFillRect actual C sig: (void* buf, u32 x, u32 y, u32 w, u32 h, const uint16_t* bg)
# Attempt: declare bg as `ptr` — not a Jac NA scalar type.
import from .opentui {
    def bufferFillRect(buf: i64, x: i32, y: i32, w: i32, h: i32, bg: ptr) -> None;
}

with entry {
    tui_write(2, "should not reach here\n");
}
