"""Test fixture: extensionless logical native import (issue #6387).

`import from raylib { ... }` names the library by its logical name; the native
backend resolves the platform-correct filename (libraylib.so / .dylib / .dll)
from the target triple. Mirrors clib_import.na.jac but with the dotted/
extensionless surface instead of an explicit string path.
"""

import from raylib {
    def InitWindow(width: i32, height: i32, title: str) -> None;
    def CloseWindow -> None;
}

def open_then_close(w: int, h: int, title: str) -> None {
    InitWindow(w, h, title);
    CloseWindow();
}
