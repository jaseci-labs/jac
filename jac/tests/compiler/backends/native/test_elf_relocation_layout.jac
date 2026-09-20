"""ELF eager relocation must also work with the glibc 2.17 loader."""
import ctypes;
import os;
import shutil;
import struct;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.backends.native.elf_linker { ElfLinker }

def dynamic_tags(data: bytes) -> dict[int, int] {
    phoff = struct.unpack_from("<Q", data, 32)[0];
    (size, count) = struct.unpack_from("<HH", data, 54);
    for index in range(count) {
        header = struct.unpack_from("<IIQQQQQQ", data, phoff + index * size);
        if header[0] == 2 {
            return dict(
                struct.iter_unpack("<qQ", data[header[2]:header[2] + header[5]])
            );
        }
    }
    raise AssertionError("missing PT_DYNAMIC");
}

test "data relocations precede adjacent PLT relocations under eager binding" {
    if sys.platform != "linux" or shutil.which("cc") is None {
        testskip("requires Linux and a C compiler");
    }
    with tempfile.TemporaryDirectory() as directory {
        temp_dir = Path(directory);
        source = temp_dir / "probe.c";
        obj_path = temp_dir / "probe.o";
        source.write_text(
            "extern void *stderr; extern int getpid(void); extern void _exit(int);\n"
            "int probe(void) { return stderr != 0 && getpid() > 0; }\n"
            "void _start(void) { _exit(probe() ? 0 : 3); }\n"
        );
        subprocess.run(
            ["cc", "-c", "-fPIC", str(source), "-o", str(obj_path)], check=True
        );
        for shared in [False, True] {
            output = temp_dir / ("probe.so" if shared else "probe");
            assert ElfLinker.link(
                obj_bytes=obj_path.read_bytes(),
                output_path=str(output),
                needed_libs=["libc.so.6"],
                shared=shared,
                export_symbols=["probe"] if shared else []
            );
            tags = dynamic_tags(output.read_bytes());
            # glibc 2.17 merges these ranges when binding eagerly. Reversing
            # them makes its relocation walk continue into executable code.
            assert tags[8] > 0 and tags[2] > 0;
            assert tags[7] + tags[8] == tags[23];
            if shared {
                library = ctypes.CDLL(str(output), mode=os.RTLD_NOW);
                assert library.probe() == 1;
            } else {
                env = dict(os.environ);
                env["LD_BIND_NOW"] = "1";
                subprocess.run([str(output)], env=env, check=True, timeout=10);
            }
        }
    }
}
