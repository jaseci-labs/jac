"""Input constructors retain their priority and run before the shared
initializer, which the link glue lists in `.init_array` as the last input."""
import ctypes;
import platform;
import shutil;
import struct;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.backends.native.native_link { NativeLinkJob, link_native }

test "ELF input constructors run in priority order before the glue's shared initializer" {
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
            glue = Path(work) / "glue.c";
            glue.write_text(
                "extern void last(void);\n"
                    + "__attribute__((section(\".init_array\"), used))\n"
                    + "static void (*const last_entry)(void) = last;\n"
            );
            objects: list[bytes] = [];
            for unit in [source, glue] {
                obj_path = unit.with_suffix(".o");
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
                        str(unit),
                        "-o",
                        str(obj_path)
                    ],
                    check=True
                );
                objects.append(obj_path.read_bytes());
            }
            output = Path(work) / "constructors.so";
            link_native(
                NativeLinkJob(
                    platform="elf",
                    triple=arch + "-unknown-linux-gnu",
                    output_path=str(output),
                    shared=True,
                    soname=output.name,
                    objects=objects,
                    export_symbols=["result"]
                )
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
