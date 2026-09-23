"""A copy-relocated variable reached through the GOT, in an ELF executable.

An executable takes libc's `stderr` by `R_*_COPY`: the loader copies the
variable into storage the executable owns. Code that reads it directly uses
that storage. Code that reads it through the GOT (`-fPIC` objects, and
aarch64's large code model, which is what the launcher is built with) loads the
variable's address from a GOT slot first, so the slot must hold the address of
the copy. The linker once resolved the GOT reference to the copy itself, and
`fputs(..., stderr)` then received the FILE's first word (`0xfbad2086`) as its
stream. The linux-aarch64 launcher segfaulted on `jac --version` that way.
"""

import from unittest { SkipTest }
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.backends.native.elf_linker { ElfLinker }

test "a GOT load of a copy-relocated stderr yields the stream, not its contents" {
    if sys.platform != "linux" or shutil.which("cc") is None {
        raise SkipTest("requires Linux and a C compiler");
    }
    with tempfile.TemporaryDirectory() as directory {
        temp_dir = Path(directory);
        source = temp_dir / "probe.c";
        obj_path = temp_dir / "probe.o";
        entry_source = temp_dir / "entry.c";
        entry_obj = temp_dir / "entry.o";
        output = temp_dir / "probe";
        source.write_text(
            "#include <stdio.h>\n"
            "int probe(void) { return fputs(\"copy-got-ok\\n\", stderr) < 0 || fflush(stderr); }\n"
        );
        # x86_64 enters _start with the stack 8 bytes off a C call's alignment.
        entry_source.write_text(
            "extern int probe(void); extern void _exit(int);\n"
            "#if defined(__x86_64__)\n"
            "__attribute__((force_align_arg_pointer))\n"
            "#endif\n"
            "void _start(void) { _exit(probe()); }\n"
        );
        for (src, obj) in [(source, obj_path), (entry_source, entry_obj)] {
            subprocess.run(["cc", "-c", "-fPIC", str(src), "-o", str(obj)], check=True);
        }
        assert ElfLinker.link(
            objects=[entry_obj.read_bytes()],
            output_path=str(output),
            needed_libs=["libc.so.6"],
            archive_members=[obj_path.read_bytes()]
        );
        run = subprocess.run([str(output)], capture_output=True, text=True, timeout=10);
        assert run.returncode == 0 , (
            f"probe exited {run.returncode} (a -11 is the double dereference); "
            f"stderr={run.stderr!r}"
        );
        assert run.stderr == "copy-got-ok\n" , f"stderr was {run.stderr!r}";
    }
}
