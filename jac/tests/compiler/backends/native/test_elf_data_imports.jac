"""Executable data imports work through both direct references and the GOT; a GOT-only import binds to the defining library's variable."""

import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from unittest { SkipTest }
import from jaclang.compiler.backends.native.elf_linker { ElfLinker }

test "ELF executable keeps imported data separate from its GOT address" {
    if sys.platform != "linux" or shutil.which("cc") is None {
        raise SkipTest("requires Linux and a C compiler");
    }
    with tempfile.TemporaryDirectory() as directory {
        work = Path(directory);
        objects: list[bytes] = [];
        for (name, flag) in [("pic", "-fPIC"), ("direct", "-fno-pic")] {
            source = work / f"{name}.c";
            obj_path = work / f"{name}.o";
            source.write_text(
                "#include <stdio.h>\n"
                    + f"int {name}_probe(void) {{\n"
                    + "  return fileno(stderr) == 2 && fileno(stdout) == 1 && stderr != stdout;\n}\n"
            );
            subprocess.run(
                ["cc", "-c", flag, str(source), "-o", str(obj_path)], check=True
            );
            objects.append(obj_path.read_bytes());
        }
        entry_source = work / "entry.c";
        entry_obj = work / "entry.o";
        entry_source.write_text(
            "extern int pic_probe(void), direct_probe(void);\n"
                + "extern void _exit(int);\n"
                + "void _start(void) { _exit(pic_probe() && direct_probe() ? 0 : 1); }\n"
        );
        subprocess.run(
            ["cc", "-c", "-fPIC", str(entry_source), "-o", str(entry_obj)], check=True
        );
        output = work / "probe";
        assert ElfLinker.link(
            objects=[entry_obj.read_bytes()] + objects,
            output_path=str(output),
            needed_libs=["libc.so.6"]
        );
        ran = subprocess.run([str(output)], capture_output=True, timeout=10);
        assert ran.returncode == 0 , (ran.returncode, ran.stderr);
    }
}

test "ELF executable binds GOT-only data imports to the library's own variables" {
    if sys.platform != "linux" or shutil.which("cc") is None {
        raise SkipTest("requires Linux and a C compiler");
    }
    with tempfile.TemporaryDirectory() as directory {
        work = Path(directory);
        library_source = work / "data.c";
        library_source.write_text(
            "typedef struct { float x, y, z; } Vec3;\n"
                + "int lib_count = 7;\n"
                + "Vec3 lib_origin = {1.0f, 2.0f, 3.0f};\n"
                + "int lib_read(void) { return lib_count; }\n"
        );
        subprocess.run(
            [
                "cc",
                "-shared",
                "-fPIC",
                str(library_source),
                "-o",
                str(work / "libdata.so")
            ],
            check=True
        );
        entry_source = work / "entry.c";
        entry_obj = work / "entry.o";
        entry_source.write_text(
            "typedef struct { float x, y, z; } Vec3;\n"
                + "extern int lib_count;\n"
                + "extern Vec3 lib_origin;\n"
                + "extern int lib_read(void);\n"
                + "extern void _exit(int);\n"
                + "#if defined(__x86_64__)\n"
                + "__attribute__((force_align_arg_pointer))\n"
                + "#endif\n"
                + "void _start(void) {\n"
                + "  lib_count += 5;\n"
                + "  _exit(lib_read() == 12 && lib_origin.z == 3.0f ? 0 : 1);\n}\n"
        );
        subprocess.run(
            ["cc", "-c", "-fPIC", str(entry_source), "-o", str(entry_obj)], check=True
        );
        output = work / "probe";
        assert ElfLinker.link(
            objects=[entry_obj.read_bytes()],
            output_path=str(output),
            needed_libs=["libdata.so", "libc.so.6"]
        );
        ran = subprocess.run([str(output)], capture_output=True, timeout=10);
        assert ran.returncode == 0 , (ran.returncode, ran.stderr);
    }
}
