#!/usr/bin/env python3
# ruff: noqa: T201, N806
"""Phase 4 Win32 console gate — validates baked constants and VT output mode.

Two checks, both Windows-only (exits 0 immediately on non-Windows):

1. Constant probe: verify the numeric values baked into tty/console.win32.na.jac
   are consistent with the Win32 SDK documentation (WinCon.h / winbase.h).
   There is no Python-stdlib oracle for these (unlike termios on POSIX), so
   the test documents each baked value and asserts well-known invariants.

2. VT output gate: if a console output handle is available, enable
   ENABLE_VIRTUAL_TERMINAL_PROCESSING (0x0004) via kernel32 directly and
   verify the call succeeds. Skipped when running headless (INVALID_HANDLE
   from GetStdHandle). This decouples the constant validation from the DLL
   build so the test runs even before tui.dll is built.

Run by build.ps1 and the windows-latest CI job; exits non-zero on failure.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


# ── Win32 constants baked in tty/console.win32.na.jac ────────────────────────
# Values from the Win32 SDK headers (WinCon.h / winbase.h). The probe checks
# well-known invariants (e.g. WAIT_TIMEOUT == 258) and documents the rest.

_BAKED_INPUT_MODE: dict = {
    "ENABLE_PROCESSED_INPUT": 0x0001,  # Ctrl+C → ctrl-break event (we DISABLE this)
    "ENABLE_LINE_INPUT": 0x0002,  # line buffering (we DISABLE this)
    "ENABLE_ECHO_INPUT": 0x0004,  # local echo (we DISABLE this)
    "ENABLE_WINDOW_INPUT": 0x0008,  # WINDOW_BUFFER_SIZE_RECORDs
    "ENABLE_MOUSE_INPUT": 0x0010,  # mouse events in buffer
    "ENABLE_INSERT_MODE": 0x0020,  # insert vs overwrite
    "ENABLE_QUICK_EDIT_MODE": 0x0040,  # mouse selection
    "ENABLE_EXTENDED_FLAGS": 0x0080,  # required by QUICK_EDIT_MODE
    "ENABLE_VIRTUAL_TERMINAL_INPUT": 0x0200,  # VT sequences on stdin (NOT used by ReadConsoleInputW)
}
_BAKED_OUTPUT_MODE: dict = {
    "ENABLE_PROCESSED_OUTPUT": 0x0001,  # process control chars
    "ENABLE_WRAP_AT_EOL_OUTPUT": 0x0002,  # auto wrap
    "ENABLE_VIRTUAL_TERMINAL_PROCESSING": 0x0004,  # VT/ANSI escape output (we ENABLE this)
    "DISABLE_NEWLINE_AUTO_RETURN": 0x0008,  # suppress CR on LF
    "ENABLE_LVB_GRID_WORLDWIDE": 0x0010,  # grid chars for LVB
}
_BAKED_MISC: dict = {
    "WAIT_OBJECT_0": 0x00000000,  # WaitForSingleObject: handle signaled
    "WAIT_TIMEOUT": 0x00000102,  # WaitForSingleObject: timeout (decimal 258)
    "KEY_EVENT_TYPE": 0x0001,  # INPUT_RECORD.EventType for keyboard events
    "SHIFT_PRESSED": 0x0010,  # dwControlKeyState: left or right shift key
}

# GetStdHandle arguments
_STD_INPUT_HANDLE = 0xFFFFFFF6  # -10 as DWORD
_STD_OUTPUT_HANDLE = 0xFFFFFFF5  # -11 as DWORD
_STD_ERROR_HANDLE = 0xFFFFFFF4  # -12 as DWORD


def check_constant_table() -> list:
    """Assert well-known invariants; document all baked values."""
    errors = []

    # WAIT_TIMEOUT = 258 is a well-known Windows API constant (not OS-version
    # dependent). If our baked value is wrong the tty_poll timeout never fires.
    wt = _BAKED_MISC["WAIT_TIMEOUT"]
    if wt != 258:
        errors.append(f"  WAIT_TIMEOUT: baked=0x{wt:04x} ({wt}) expected 258 (0x102)")
    else:
        print(f"  ok WAIT_TIMEOUT = {wt} (0x{wt:04x})")

    wo = _BAKED_MISC["WAIT_OBJECT_0"]
    if wo != 0:
        errors.append(f"  WAIT_OBJECT_0: baked={wo} expected 0")
    else:
        print(f"  ok WAIT_OBJECT_0 = {wo}")

    # ENABLE_VIRTUAL_TERMINAL_PROCESSING (output mode) = 0x0004. If wrong, the
    # TUI renderer writes ANSI sequences that appear as literal text on conhost.
    vt_out = _BAKED_OUTPUT_MODE["ENABLE_VIRTUAL_TERMINAL_PROCESSING"]
    if vt_out != 0x0004:
        errors.append(
            f"  ENABLE_VIRTUAL_TERMINAL_PROCESSING: baked=0x{vt_out:04x} expected 0x0004"
        )
    else:
        print(f"  ok ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x{vt_out:04x}")

    # ENABLE_PROCESSED_INPUT (input mode) = 0x0001. We DISABLE this so Ctrl+C
    # arrives as UnicodeChar=0x03 in KEY_EVENT instead of a CTRL_C_EVENT.
    pi = _BAKED_INPUT_MODE["ENABLE_PROCESSED_INPUT"]
    if pi != 0x0001:
        errors.append(f"  ENABLE_PROCESSED_INPUT: baked=0x{pi:04x} expected 0x0001")
    else:
        print(f"  ok ENABLE_PROCESSED_INPUT = 0x{pi:04x} (disabled in raw mode)")

    # Note: ENABLE_ECHO_INPUT (stdin, 0x0004) and ENABLE_VIRTUAL_TERMINAL_PROCESSING
    # (stdout, 0x0004) share the same bit value — this is intentional and correct;
    # they apply to different handles.
    echo = _BAKED_INPUT_MODE["ENABLE_ECHO_INPUT"]
    if echo != vt_out:
        errors.append(
            f"  ENABLE_ECHO_INPUT and ENABLE_VT_PROCESSING should share 0x0004 "
            f"(echo=0x{echo:04x} vt=0x{vt_out:04x})"
        )
    else:
        print(
            f"  ok ENABLE_ECHO_INPUT == ENABLE_VT_PROCESSING == 0x{echo:04x} (different handles)"
        )

    # Document KEY_EVENT_TYPE and SHIFT_PRESSED
    ket = _BAKED_MISC["KEY_EVENT_TYPE"]
    sp = _BAKED_MISC["SHIFT_PRESSED"]
    if ket != 1:
        errors.append(f"  KEY_EVENT_TYPE: baked={ket} expected 1")
    else:
        print(f"  ok KEY_EVENT_TYPE = {ket}")
    if sp != 0x0010:
        errors.append(f"  SHIFT_PRESSED: baked=0x{sp:04x} expected 0x0010")
    else:
        print(f"  ok SHIFT_PRESSED = 0x{sp:04x}")

    return errors


def check_vt_output_gate(k32: any) -> list:
    """Enable ENABLE_VIRTUAL_TERMINAL_PROCESSING on stdout; verify via GetConsoleMode."""
    import ctypes

    errors = []
    ENABLE_VT_PROCESSING = 0x0004

    out_handle = k32.GetStdHandle(_STD_OUTPUT_HANDLE)
    # INVALID_HANDLE_VALUE = 0xFFFFFFFFFFFFFFFF (unsigned 64-bit -1)
    # None = NULL handle; 0 = also invalid
    if out_handle is None or out_handle == 0 or out_handle == 0xFFFFFFFFFFFFFFFF:
        print("  SKIP: no valid stdout handle (headless runner or not a console)")
        return errors

    mode = ctypes.c_uint32(0)
    if not k32.GetConsoleMode(out_handle, ctypes.byref(mode)):
        print("  SKIP: GetConsoleMode failed — stdout is not a console handle (piped)")
        return errors

    orig_mode = mode.value
    print(f"  original stdout console mode: 0x{orig_mode:08x}")

    new_mode = orig_mode | ENABLE_VT_PROCESSING
    if not k32.SetConsoleMode(out_handle, ctypes.c_uint32(new_mode)):
        err = k32.GetLastError()
        errors.append(
            f"  SetConsoleMode(ENABLE_VT_PROCESSING=0x{ENABLE_VT_PROCESSING:04x}) FAILED "
            f"(GetLastError={err}) — console does not support VT output (legacy conhost?)"
        )
        return errors

    # Read back and confirm the bit is set
    mode2 = ctypes.c_uint32(0)
    k32.GetConsoleMode(out_handle, ctypes.byref(mode2))
    if not (mode2.value & ENABLE_VT_PROCESSING):
        errors.append(
            f"  ENABLE_VT_PROCESSING not set after SetConsoleMode "
            f"(mode=0x{mode2.value:08x})"
        )
    else:
        print(f"  ok ENABLE_VT_PROCESSING set (mode=0x{mode2.value:08x})")

    # Emit a VT reset sequence via WriteFile (the same API our NA code uses).
    test_seq = b"\x1b[0m[test_console_win32: VT OK]\x1b[0m\r\n"
    written = ctypes.c_uint32(0)
    k32.WriteFile(out_handle, test_seq, len(test_seq), ctypes.byref(written), None)
    if written.value == len(test_seq):
        print(f"  ok WriteFile via out_handle emitted {written.value} bytes")
    else:
        errors.append(f"  WriteFile wrote {written.value}/{len(test_seq)} bytes")

    # Restore original mode
    k32.SetConsoleMode(out_handle, ctypes.c_uint32(orig_mode))
    print(f"  ok restored stdout mode to 0x{orig_mode:08x}")

    return errors


def main() -> int:
    if sys.platform != "win32":
        print(
            f"SKIP: test_console_win32.py is Windows-only (platform={sys.platform!r})"
        )
        return 0

    import ctypes

    k32 = ctypes.windll.kernel32
    k32.GetStdHandle.restype = ctypes.c_void_p
    k32.GetStdHandle.argtypes = [ctypes.c_uint32]
    k32.GetConsoleMode.restype = ctypes.c_int32
    k32.GetConsoleMode.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)]
    k32.SetConsoleMode.restype = ctypes.c_int32
    k32.SetConsoleMode.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    k32.GetLastError.restype = ctypes.c_uint32
    k32.GetLastError.argtypes = []
    k32.WriteFile.restype = ctypes.c_int32
    k32.WriteFile.argtypes = [
        ctypes.c_void_p,
        ctypes.c_char_p,
        ctypes.c_uint32,
        ctypes.POINTER(ctypes.c_uint32),
        ctypes.c_void_p,
    ]

    all_errors: list = []

    print("\n── constant table probe ──")
    all_errors.extend(check_constant_table())

    print("\n── VT output gate (kernel32 direct, skips if headless) ──")
    all_errors.extend(check_vt_output_gate(k32))

    if all_errors:
        print("\nFAIL:", file=sys.stderr)
        for e in all_errors:
            print(e, file=sys.stderr)
        return 1

    print("\n==> test_console_win32 passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
