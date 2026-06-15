import sys;

import from .tui_helpers { def tui_write(fd: i32, s: str) -> None;  }

import from .opentui {
    def createRenderer(w: i32, h: i32, testing: i32, remote: i32) -> i64;  def destroyRenderer(
        renderer: i64
    ) -> None;  def render(renderer: i64, force: i32) -> None;  def getNextBuffer(
        renderer: i64
    ) -> i64;  def bufferFillRect(
        buf: i64, x: i32, y: i32, w: i32, h: i32, bg: str
    ) -> None;
}

glob h: i64 = createRenderer(80, 24, 1, 0),
     null64: i64 = 0;

with entry {
    if h == null64 {
        tui_write(2, "[str-test] createRenderer failed\n");
        sys.exit(1);
    }
}

glob buf: i64 = getNextBuffer(h);

with entry {
    if buf == null64 {
        tui_write(2, "[str-test] getNextBuffer failed\n");
        destroyRenderer(h);
        sys.exit(1);
    }

    tui_write(2, "[str-test] calling bufferFillRect with str bg (wrong type)\n");
    bufferFillRect(buf, 0, 0, 80, 24, "rgba");
    tui_write(2, "[str-test] call returned (may have been a no-op or UB)\n");

    render(h, 1);
    destroyRenderer(h);

    tui_write(2, "[str-test] conclusion: str cannot encode uint16_t[4] RGBA\n");
    tui_write(
        2, "[str-test]   - any RGB value < 256 produces 0x00 high byte in uint16_t LE\n"
    );
    tui_write(
        2, "[str-test]   - 0x00 is a C string NUL terminator at every other byte\n"
    );
    tui_write(2, "[str-test]   - the C shim is the minimum required bridge\n");
}
