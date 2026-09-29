"""Optional native imports remain optional after linking, including address guards."""

import ctypes;
import from unittest { SkipTest }
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.backends.native.elf_linker { ElfLinker }


def _weak_probe(shared: bool, provided: bool = False) {
    if sys.platform != "linux" or shutil.which("cc") is None {
        raise SkipTest("requires Linux and a C compiler");
    }
    with tempfile.TemporaryDirectory() as directory {
        temp_dir = Path(directory);
        source = temp_dir / "probe.c";
        obj_path = temp_dir / "probe.o";
        output = temp_dir / ("probe.so" if shared else "probe");
        source.write_text(
            "extern int optional_hook(void) __attribute__((weak));\n"
            "int probe(void) { return optional_hook ? optional_hook() : 42; }\n"
        );
        subprocess.run(
            ["cc", "-c", "-fPIC", str(source), "-o", str(obj_path)], check=True
        );
        expected = 7 if provided else 42;
        needed_libs: list[str] = ["libc.so.6"];
        if provided {
            provider = temp_dir / "provider.c";
            provider_lib = temp_dir / "provider.so";
            provider.write_text("int optional_hook(void) { return 7; }");
            subprocess.run(
                ["cc", "-shared", "-fPIC", str(provider), "-o", str(provider_lib)],
                check=True
            );
            needed_libs.append(str(provider_lib));
        }
        members: list[bytes] = [];
        main_object = obj_path.read_bytes();
        if not shared {
            entry_source = temp_dir / "entry_source.c";
            entry_obj = temp_dir / "entry_source.o";
            entry_source.write_text(
                "extern int probe(void); extern void _exit(int);\n"
                "void _start(void) { _exit(probe() == "
                    + str(expected)
                    + " ? 0 : 1); }\n"
            );
            subprocess.run(
                ["cc", "-c", "-fPIC", str(entry_source), "-o", str(entry_obj)],
                check=True
            );
            members.append(main_object);
            main_object = entry_obj.read_bytes();
        }
        assert ElfLinker.link(
            objects=[main_object],
            output_path=str(output),
            needed_libs=needed_libs,
            shared=shared,
            export_symbols=["probe"] if shared else [],
            archive_members=members
        );
        if shared {
            library = ctypes.CDLL(str(output));
            assert library.probe() == expected;
        } else {
            subprocess.run([str(output)], check=True, timeout=10);
        }
    }
}

test "missing weak function has a null address in a shared library" {
    _weak_probe(True);
}

test "missing weak function has a null address in an executable" {
    _weak_probe(False);
}

test "provided weak function resolves in a shared library" {
    _weak_probe(True, True);
}

test "provided weak function resolves in an executable" {
    _weak_probe(False, True);
}

test "a strong reference remains required when merged with a weak reference" {
    if sys.platform != "linux" or shutil.which("cc") is None {
        raise SkipTest("requires Linux and a C compiler");
    }
    with tempfile.TemporaryDirectory() as directory {
        temp_dir = Path(directory);
        weak_source = temp_dir / "weak.c";
        strong_source = temp_dir / "strong.c";
        weak_source.write_text(
            "extern int required_hook(void) __attribute__((weak));\n"
            "int weak_use(void) { return required_hook ? required_hook() : 42; }\n"
        );
        strong_source.write_text(
            "extern int required_hook(void);\n"
            "int strong_use(void) { return required_hook(); }\n"
        );
        for source in [weak_source, strong_source] {
            subprocess.run(
                ["cc", "-c", "-fPIC", str(source), "-o", str(source.with_suffix(".o"))],
                check=True
            );
        }
        for reverse in [False, True] {
            sources = [weak_source, strong_source];
            if reverse {
                sources.reverse();
            }
            output = temp_dir / f"required_{reverse}.so";
            assert ElfLinker.link(
                objects=[sources[0].with_suffix(".o").read_bytes()],
                output_path=str(output),
                shared=True,
                export_symbols=["weak_use", "strong_use"],
                archive_members=[sources[1].with_suffix(".o").read_bytes()]
            );
            rejected = False;
            try {
                ctypes.CDLL(str(output));
            } except OSError as error {
                assert "required_hook" in str(error);
                rejected = True;
            }
            assert rejected , "a strong undefined reference became optional";
        }
    }
}
