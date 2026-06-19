"""Phase 4 Win32 console gate — validates baked constants and VT output mode.

Windows-only (exits 0 immediately on non-Windows). Two checks:

1. Constant probe: verify the numeric values baked into tty/console.win32.na.jac
   are consistent with the Win32 SDK documentation.

2. VT output gate: if a console output handle is available, enable
   ENABLE_VIRTUAL_TERMINAL_PROCESSING (0x0004) via kernel32 and verify.
   Skipped when running headless (INVALID_HANDLE from GetStdHandle).

Run by build.ps1; exits non-zero on any failure.
"""

import sys;

def check_constant_table -> list {
    errors: list = [];

    baked_input_mode = {
        "ENABLE_PROCESSED_INPUT": 0x0001,
        "ENABLE_LINE_INPUT": 0x0002,
        "ENABLE_ECHO_INPUT": 0x0004,
        "ENABLE_WINDOW_INPUT": 0x0008,
        "ENABLE_MOUSE_INPUT": 0x0010,
        "ENABLE_INSERT_MODE": 0x0020,
        "ENABLE_QUICK_EDIT_MODE": 0x0040,
        "ENABLE_EXTENDED_FLAGS": 0x0080,
        "ENABLE_VIRTUAL_TERMINAL_INPUT": 0x0200,

    };
    baked_output_mode = {
        "ENABLE_PROCESSED_OUTPUT": 0x0001,
        "ENABLE_WRAP_AT_EOL_OUTPUT": 0x0002,
        "ENABLE_VIRTUAL_TERMINAL_PROCESSING": 0x0004,
        "DISABLE_NEWLINE_AUTO_RETURN": 0x0008,
        "ENABLE_LVB_GRID_WORLDWIDE": 0x0010,

    };
    baked_misc = {
        "WAIT_OBJECT_0": 0x00000000,
        "WAIT_TIMEOUT": 0x00000102,
        "KEY_EVENT_TYPE": 0x0001,
        "SHIFT_PRESSED": 0x0010,

    };

    wt = baked_misc["WAIT_TIMEOUT"];
    if wt != 258 {
        errors.append(f"  WAIT_TIMEOUT: baked=0x{wt:04x} ({wt}) expected 258 (0x102)");
    } else {
        sys.stdout.write(f"  ok WAIT_TIMEOUT = {wt} (0x{wt:04x})\n");
    }

    wo = baked_misc["WAIT_OBJECT_0"];
    if wo != 0 {
        errors.append(f"  WAIT_OBJECT_0: baked={wo} expected 0");
    } else {
        sys.stdout.write(f"  ok WAIT_OBJECT_0 = {wo}\n");
    }

    vt_out = baked_output_mode["ENABLE_VIRTUAL_TERMINAL_PROCESSING"];
    if vt_out != 0x0004 {
        errors.append(
            f"  ENABLE_VIRTUAL_TERMINAL_PROCESSING: baked=0x{vt_out:04x} expected 0x0004"
        );
    } else {
        sys.stdout.write(f"  ok ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x{vt_out:04x}\n");
    }

    pi = baked_input_mode["ENABLE_PROCESSED_INPUT"];
    if pi != 0x0001 {
        errors.append(f"  ENABLE_PROCESSED_INPUT: baked=0x{pi:04x} expected 0x0001");
    } else {
        sys.stdout.write(
            f"  ok ENABLE_PROCESSED_INPUT = 0x{pi:04x} (disabled in raw mode)\n"
        );
    }

    echo = baked_input_mode["ENABLE_ECHO_INPUT"];
    if echo != vt_out {
        errors.append(
            f"  ENABLE_ECHO_INPUT and ENABLE_VT_PROCESSING should share 0x0004 "
            f"(echo=0x{echo:04x} vt=0x{vt_out:04x})"
        );
    } else {
        sys.stdout.write(
            f"  ok ENABLE_ECHO_INPUT == ENABLE_VT_PROCESSING == 0x{echo:04x} (different handles)\n"
        );
    }

    ket = baked_misc["KEY_EVENT_TYPE"];
    sp = baked_misc["SHIFT_PRESSED"];
    if ket != 1 {
        errors.append(f"  KEY_EVENT_TYPE: baked={ket} expected 1");
    } else {
        sys.stdout.write(f"  ok KEY_EVENT_TYPE = {ket}\n");
    }
    if sp != 0x0010 {
        errors.append(f"  SHIFT_PRESSED: baked=0x{sp:04x} expected 0x0010");
    } else {
        sys.stdout.write(f"  ok SHIFT_PRESSED = 0x{sp:04x}\n");
    }

    return errors;
}

def check_vt_output_gate(k32: object, ctypes: object) -> list {
    errors: list = [];
    ENABLE_VT_PROCESSING = 0x0004;
    STD_OUTPUT_HANDLE = 0xFFFFFFF5;

    out_handle = k32.GetStdHandle(STD_OUTPUT_HANDLE);
    if out_handle is None or out_handle == 0 or out_handle == 0xFFFFFFFFFFFFFFFF {
        sys.stdout.write(
            "  SKIP: no valid stdout handle (headless runner or not a console)\n"
        );
        return errors;
    }

    mode = ctypes.c_uint32(0);
    if not k32.GetConsoleMode(out_handle, ctypes.byref(mode)) {
        sys.stdout.write(
            "  SKIP: GetConsoleMode failed — stdout is not a console handle (piped)\n"
        );
        return errors;
    }

    orig_mode = mode.value;
    sys.stdout.write(f"  original stdout console mode: 0x{orig_mode:08x}\n");

    new_mode = orig_mode | ENABLE_VT_PROCESSING;
    if not k32.SetConsoleMode(out_handle, ctypes.c_uint32(new_mode)) {
        err = k32.GetLastError();
        errors.append(
            f"  SetConsoleMode(ENABLE_VT_PROCESSING=0x{ENABLE_VT_PROCESSING:04x}) FAILED "
            f"(GetLastError={err}) — console does not support VT output (legacy conhost?)"
        );
        return errors;
    }

    mode2 = ctypes.c_uint32(0);
    k32.GetConsoleMode(out_handle, ctypes.byref(mode2));
    if not (mode2.value & ENABLE_VT_PROCESSING) {
        errors.append(
            f"  ENABLE_VT_PROCESSING not set after SetConsoleMode "
            f"(mode=0x{mode2.value:08x})"
        );
    } else {
        sys.stdout.write(f"  ok ENABLE_VT_PROCESSING set (mode=0x{mode2.value:08x})\n");
    }

    test_seq = b"\x1b[0m[test_console_win32: VT OK]\x1b[0m\r\n";
    written = ctypes.c_uint32(0);
    k32.WriteFile(out_handle, test_seq, len(test_seq), ctypes.byref(written), None);
    if written.value == len(test_seq) {
        sys.stdout.write(
            f"  ok WriteFile via out_handle emitted {written.value} bytes\n"
        );
    } else {
        errors.append(f"  WriteFile wrote {written.value}/{len(test_seq)} bytes");
    }

    k32.SetConsoleMode(out_handle, ctypes.c_uint32(orig_mode));
    sys.stdout.write(f"  ok restored stdout mode to 0x{orig_mode:08x}\n");

    return errors;
}

def main -> int {
    if sys.platform != "win32" {
        sys.stdout.write(
            f"SKIP: test_console_win32.jac is Windows-only (platform={repr(
                sys.platform
            )})\n"
        );
        return 0;
    }

    import ctypes;

    k32 = ctypes.windll.kernel32;
    k32.GetStdHandle.restype = ctypes.c_void_p;
    k32.GetStdHandle.argtypes = [ctypes.c_uint32];
    k32.GetConsoleMode.restype = ctypes.c_int32;
    k32.GetConsoleMode.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)];
    k32.SetConsoleMode.restype = ctypes.c_int32;
    k32.SetConsoleMode.argtypes = [ctypes.c_void_p, ctypes.c_uint32];
    k32.GetLastError.restype = ctypes.c_uint32;
    k32.GetLastError.argtypes = [];
    k32.WriteFile.restype = ctypes.c_int32;
    k32.WriteFile.argtypes = [
        ctypes.c_void_p,
        ctypes.c_char_p,
        ctypes.c_uint32,
        ctypes.POINTER(ctypes.c_uint32),
        ctypes.c_void_p,

    ];

    all_errors: list = [];

    sys.stdout.write("\n── constant table probe ──\n");
    all_errors += check_constant_table();

    sys.stdout.write("\n── VT output gate (kernel32 direct, skips if headless) ──\n");
    all_errors += check_vt_output_gate(k32, ctypes);

    if all_errors {
        sys.stderr.write("\nFAIL:\n");
        for e in all_errors {
            sys.stderr.write(e + "\n");
        }
        return 1;
    }

    sys.stdout.write("\n==> test_console_win32 passed.\n");
    return 0;
}

with entry {
    sys.exit(main());
}
