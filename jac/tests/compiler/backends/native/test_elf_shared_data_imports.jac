"""A shared object keeps data words that point at imported functions.

A static archive member linked into a shared object can hold the address of
a function the object imports, as OpenSSL's `memset_func` holds libc's
`memset` for `OPENSSL_cleanse`. The shared-object linker only turned absolute
data relocations against local symbols into dynamic relocations and dropped
the rest, so the word stayed zero and the first call through it jumped to
address 0 (SHA-256 in a kernel built with the floor libcrypto crashed there).
Such a word now gets a symbolic dynamic relocation the loader fills in.
"""

import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from unittest { SkipTest }
import from jaclang.compiler.backends.native.elf_linker { ElfLinker }

test "a shared object's data pointer to an imported function is relocated" {
    if sys.platform != "linux" or shutil.which("cc") is None {
        raise SkipTest("requires Linux and a C compiler");
    }
    with tempfile.TemporaryDirectory() as directory {
        work = Path(directory);
        source = work / "probe.c";
        obj_path = work / "probe.o";
        source.write_text(
            "#include <string.h>\n"
                + "void *(*volatile memset_ptr)(void *, int, size_t) = memset;\n"
                + "int probe(void) {\n"
                + "  char buf[4] = {1, 1, 1, 1};\n"
                + "  if (memset_ptr == 0) return 2;\n"
                + "  memset_ptr(buf, 0, sizeof buf);\n"
                + "  return buf[0] == 0 && buf[3] == 0;\n}\n"
        );
        subprocess.run(
            ["cc", "-c", "-fPIC", "-O1", str(source), "-o", str(obj_path)], check=True
        );
        output = work / "libprobe.so";
        assert ElfLinker.link(
            objects=[obj_path.read_bytes()],
            output_path=str(output),
            needed_libs=["libc.so.6"],
            shared=True,
            export_symbols=["probe"],
            soname="libprobe.so"
        );
        script = (
            "import ctypes, sys\n"
            + f"lib = ctypes.CDLL({str(output)!r})\n"
            + "sys.exit(lib.probe())\n"
        );
        ran = subprocess.run(
            [sys.executable, "-c", script], capture_output=True, timeout=30
        );
        assert ran.returncode == 1 , (ran.returncode, ran.stderr);
    }
}
