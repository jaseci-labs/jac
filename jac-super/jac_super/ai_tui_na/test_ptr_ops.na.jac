"""Probe what `ptr` can actually do in Jac NA.

Questions:
  1. Can we declare a ptr variable?
  2. Can we assign 0 / null to it?
  3. Can we get a ptr from malloc / some allocation?
  4. Can we write bytes into it to build a uint16_t[4] RGBA array?
  5. Can we cast i64 -> ptr to use an existing buffer address?
"""

import sys;

import from .tui_helpers { def tui_write(fd: i32, s: str) -> None;  }

# Try: import malloc/free from libc via shim
import from .opentui_shim {
    def shim_alloc16(n: i32) -> ptr;  def shim_free(p: ptr) -> None;  def shim_write16(
        p: ptr, idx: i32, val: i32
    ) -> None;  def shim_fill_rect_ptr(
        buf: i64, x: i32, y: i32, w: i32, h: i32, bg: ptr
    ) -> None;
}

import from .opentui {
    def createRenderer(w: i32, h: i32, testing: i32, remote: i32) -> i64;  def destroyRenderer(
        renderer: i64
    ) -> None;  def getNextBuffer(renderer: i64) -> i64;  def render(
        renderer: i64, force: i32
    ) -> None;
}

# Test: can we declare a ptr variable?
glob p: ptr = shim_alloc16(4),
     null_p: ptr = shim_alloc16(0);

with entry {
    tui_write(2, "[ptr-test] ptr variable declared and assigned  PASS\n");

    # Test: can we write to it via shim?
    shim_write16(p, 0, 255);
    shim_write16(p, 1, 128);
    shim_write16(p, 2, 64);
    shim_write16(p, 3, 255);
    tui_write(2, "[ptr-test] shim_write16 (write RGBA via ptr)   PASS\n");
}

# Test: can we use the ptr directly in bufferFillRect?
glob h: i64 = createRenderer(80, 24, 1, 0),
     null64: i64 = 0;

with entry {
    if h != null64 {
        buf: i64 = getNextBuffer(h);
        if buf != null64 {
            shim_fill_rect_ptr(buf, 0, 0, 80, 24, p);
            tui_write(2, "[ptr-test] bufferFillRect with ptr bg        PASS\n");
        }
        render(h, 1);
        destroyRenderer(h);
    }

    shim_free(p);
    tui_write(2, "[ptr-test] ALL DONE\n");
}
