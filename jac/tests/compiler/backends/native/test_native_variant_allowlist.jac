"""The bundled stdlib's per-target files are a short, named list (#10219).

Whatever a C library spells, lays out or numbers per target belongs in the
runtime floor, which keeps a module the same unit on every target; the
compiler kernel imports no module with a variant. What is left are tables
and ABIs the floor does not model, each with its reason. A new per-target
file fails this test until it joins the list or moves behind the floor.
"""
import os;
import re;
import from jaclang.compiler.frontend.codeinfo { native_stdlib_root }

glob ALLOWED: dict[str, str] = {
         "_dl_native.darwin.jac": "glibc before 2.34 keeps dlopen in libdl.so.2, which only a unit's own import names",
         "_dl_native.linux.jac": "glibc before 2.34 keeps dlopen in libdl.so.2, which only a unit's own import names",
         "_fcntl_native.darwin.jac": "the F_* commands and O_* flags each libc numbers its own way",
         "_fcntl_native.linux.jac": "the F_* commands and O_* flags each libc numbers its own way",
         "_locale_native.darwin.jac": "the LC_* ids and CODESET each libc numbers its own way",
         "_locale_native.linux.jac": "the LC_* ids and CODESET each libc numbers its own way",
         "_platform_native.darwin.jac": "utsname field widths and the libc version query",
         "_platform_native.linux.jac": "utsname field widths and the libc version query",
         "_signal_native.linux.jac": "signal handling exists only on Linux so far",
         "_subprocess_native.linux.jac": "posix_spawn subprocesses exist only on Linux so far",
         "_termios_native.darwin.jac": "struct termios layout (tcflag_t width, NCCS), the c_cc indices and TIOCGWINSZ per libc",
         "_termios_native.linux.jac": "struct termios layout (tcflag_t width, NCCS), the c_cc indices and TIOCGWINSZ per libc",
         "signal.linux.jac": "signal handling exists only on Linux so far",
         "subprocess.linux.jac": "posix_spawn subprocesses exist only on Linux so far",
         "_zlib_abi.windows.jac": "z_stream under Windows' 32-bit long, another layout class",
         "errno.darwin.jac": "errno's names and values as CPython exposes them per platform",
         "errno.linux.jac": "errno's names and values as CPython exposes them per platform"
     };

test "the bundled stdlib's per-target files are exactly the allowed ones" {
    stdlib = native_stdlib_root();
    assert stdlib is not None;
    pattern = re.compile(
        r"\.(darwin|linux|windows|aarch64|x86_64|wasm32|i686|riscv64)(\.\w+)?\.jac$"
    );
    found: set[str] = set();
    for (dirpath, _dirs, files) in os.walk(stdlib) {
        for name in files {
            if pattern.search(name) {
                found.add(os.path.relpath(os.path.join(dirpath, name), stdlib));
            }
        }
    }
    extra = sorted(found - set(ALLOWED));
    gone = sorted(set(ALLOWED) - found);
    assert not extra , f"new per-target files; move them behind the floor or list them: {extra}";
    assert not gone , f"listed per-target files that no longer exist: {gone}";
}
