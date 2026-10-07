"""Dev tool: decode a .jsbc (packed binary, v4) and print its header + fn_count.
Usage: jsbc_verify <file.jsbc>

Reads the file as RAW BYTES via libc fopen/fread into ONE fixed io_alloc'd buffer
(NOT open().read(), which truncates a binary blob at the first embedded NUL, and
NOT the fs builtins, whose heavy import graph a standalone tool can't bootstrap),
then decodes from that fixed buffer via jsbc_decode(ptr, size). The buffer is a
single fixed allocation (no realloc/grow) — a growable buffer corrupts mid-read."""
import from engine.src.bytecode.jsbc { jsbc_decode, JSBCModule }
import from engine.src.runtime.mem { io_alloc }
import from engine.src.ffi.libc { fflush, _exit, stack_expand, fopen, fread, fclose }
import sys;

# Fixed staging cap — larger than any builtin .jsbc (the biggest is ~400 KB).
glob JSBC_VERIFY_CAP: int = 16777216;  # 16 MB

with entry {
    stack_expand();
    ec: int = 0;
    if len(sys.argv) < 2 {
        print("usage: jsbc_verify <file.jsbc>");
        ec = 2;
    } else {
        p: str = sys.argv[1];
        f: int = fopen(p, "rb");
        if f == 0 {
            print("cannot read " + p);
            fflush(0);
            _exit(1);
        }
        # Read the whole file into ONE fixed buffer, appending each chunk at the
        # running offset (fread into buf+size never reallocates).
        buf: int = io_alloc(JSBC_VERIFY_CAP + 1);
        size: int = 0;
        reading: int = 1;
        while reading == 1 and size < JSBC_VERIFY_CAP {
            n: int = fread(buf + size, 1, 65536, f);
            if n <= 0 {
                reading = 0;
            } else {
                size = size + n;
            }
        }
        fclose(f);
        mod: JSBCModule = jsbc_decode(buf, size);
        if mod.ok {
            print(
                "OK "
                    + p
                    + " ver="
                    + str(mod.format_ver)
                    + " opc="
                    + str(mod.opcode_count)
                    + " hash="
                    + str(mod.source_hash)
                    + " fns="
                    + str(1 + len(mod.all_fns))
                    + " top=["
                    + mod.top_fn.name
                    + "] top_code="
                    + str(len(mod.top_fn.code))
                    + " ("
                    + str(size)
                    + " bytes)"
            );
        } else {
            print("BAD " + p + " err=" + mod.err);
            ec = 1;
        }
    }
    fflush(0);
    _exit(ec);
}
