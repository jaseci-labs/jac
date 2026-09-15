"""Input constructors retain their priority and precede explicit shared initializers."""
import ctypes;
import platform;
import shutil;
import struct;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.backends.native.elf_linker { ElfLinker }

test "ELF input constructors run in priority order before the shared initializer" {
    zig = shutil.which("zig");
    assert zig is not None , "ELF constructor tests require Zig";
    for arch in ["x86_64", "aarch64"] {
        with tempfile.TemporaryDirectory() as work {
            source = Path(work) / "constructors.c";
            source.write_text(
                "static volatile int value;\n"
                    + "__attribute__((constructor(110))) static void second(void) { value = value * 10 + 2; }\n"
                    + "__attribute__((constructor(90))) static void first(void) { value = value * 10 + 1; }\n"
                    + "void last(void) { value = value * 10 + 3; }\n"
                    + "int result(void) { return value; }\n"
            );
            obj_path = Path(work) / "constructors.o";
            subprocess.run(
                [
                    zig,
                    "cc",
                    "-target",
                    arch + "-linux-musl",
                    "-fPIC",
                    "-fno-stack-protector",
                    "-O2",
                    "-c",
                    str(source),
                    "-o",
                    str(obj_path)
                ],
                check=True
            );
            output = Path(work) / "constructors.so";
            assert ElfLinker.link(
                objects=[obj_path.read_bytes()],
                output_path=str(output),
                shared=True,
                export_symbols=["result"],
                init_funcs=["last"]
            );
            raw = output.read_bytes();
            offset = struct.unpack_from("<Q", raw, 40)[0];
            (size, count) = struct.unpack_from("<HH", raw, 58);
            headers = [
                struct.unpack_from("<IIQQQQIIQQ", raw, offset + i * size)
                for i in range(count)
            ];
            arrays = [
                hdr
                for hdr in headers
                if hdr[1] == 14
            ];
            assert len(arrays) == 1 and arrays[0][5] == 24 , arrays;
            host_arch = "aarch64"
                if platform.machine() == "arm64"
                else platform.machine();
            if platform.system() == "Linux" and host_arch == arch {
                library = ctypes.CDLL(str(output));
                assert library.result() == 123;
            }
        }
    }
}
