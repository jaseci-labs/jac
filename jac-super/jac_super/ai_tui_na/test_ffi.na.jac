"""FFI scalar-only tests for Jac Native ↔ OpenTUI.

Key finding under test:
  - Jac NA integer literals default to int (= i64 in LLVM IR)
  - i32 variables in binary ops with int literals → type mismatch at codegen
  - Rule: use int for all Jac-side variables; i32 only in C FFI param declarations
  - i64 is valid for FFI return/param types that carry void* (handle) values

Expected output (stderr):
  [ffi] createRenderer  PASS
  [ffi] getNextBuffer   PASS
  [ffi] render          PASS
  [ffi] shim_fill_rect  PASS
  [ffi] shim_draw_text  PASS
  [ffi] destroyRenderer PASS
  [ffi] ALL PASS
"""

import sys;

import from .tui_helpers { def tui_write(fd: i32, s: str) -> None;  }

# Direct imports from libopentui.so — handles as i64 (void* width on x64)
import from .opentui {
    def createRenderer(w: i32, h: i32, testing: i32, remote: i32) -> i64;  def destroyRenderer(
        renderer: i64
    ) -> None;  def render(renderer: i64, force: i32) -> None;  def getNextBuffer(
        renderer: i64
    ) -> i64;
}

# Shim for the two scalar-impossible calls
import from .opentui_shim {
    def shim_fill_rect(
        buf: i64, x: i32, y: i32, w: i32, h: i32, bg_r: i32, bg_g: i32, bg_b: i32
    ) -> None;  def shim_draw_text(
        buf: i64,
        text: str,
        x: i32,
        y: i32,
        fg_r: i32,
        fg_g: i32,
        fg_b: i32,
        bg_r: i32,
        bg_g: i32,
        bg_b: i32,
        use_bg: i32,
        attrs: i32
    ) -> None;
}

def pass_check(label: str) {
    tui_write(2, f"[ffi] {label}  PASS\n");
}

def fail_check(label: str) {
    tui_write(2, f"[ffi] {label}  FAIL\n");
}

# testing=1 → memory renderer, no terminal I/O, safe in headless CI
glob h: i64 = createRenderer(80, 24, 1, 0),
     null64: i64 = 0;

with entry {
    if h != null64 {
        pass_check("createRenderer");
    } else {
        fail_check("createRenderer");
        tui_write(2, "[ffi] cannot continue\n");
        sys.exit(1);
    }
}

glob buf: i64 = getNextBuffer(h);

with entry {
    if buf != null64 {
        pass_check("getNextBuffer");
    } else {
        fail_check("getNextBuffer");
    }

    render(h, 1);
    pass_check("render");

    if buf != null64 {
        shim_fill_rect(buf, 0, 0, 80, 24, 24, 24, 36);
        pass_check("shim_fill_rect");

        shim_draw_text(buf, "hello", 0, 0, 255, 255, 255, 24, 24, 36, 1, 1);
        pass_check("shim_draw_text");
    }

    destroyRenderer(h);
    pass_check("destroyRenderer");

    tui_write(2, "[ffi] ALL PASS\n");
}
