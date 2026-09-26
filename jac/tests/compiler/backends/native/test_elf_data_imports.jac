"""Executable data imports work through both direct references and the GOT."""

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
