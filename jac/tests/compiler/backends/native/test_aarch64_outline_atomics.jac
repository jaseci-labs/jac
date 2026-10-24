"""Compiler runtime helpers are selected from the upstream archive on every host."""
import struct;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.dist.payload.vendor { build_outline_atomics }
import from jaclang.compiler.backends.native.native_link { NativeLinkJob, link_native }
import jaclang.compiler.backends.native.llvm.binding as llvm;

glob _runtime_cache: list[bytes] = [];

def _runtime -> bytes {
    if not _runtime_cache {
        zig = shutil.which("zig");
        assert zig is not None , "outline-atomics packaging tests require Zig";
        with tempfile.TemporaryDirectory() as work {
            build_outline_atomics(work, zig);
            path = Path(work) / "libclang_rt.atomics.a";
            first = path.stat().st_mtime_ns;
            _runtime_cache.append(path.read_bytes());
            build_outline_atomics(work, zig);
            assert path.stat().st_mtime_ns == first;
        }
    }
    return _runtime_cache[0];
}

"""The (name, bytes) members of a GNU `ar` archive, symbol and name tables
skipped."""
def _ar_members(blob: bytes) -> list[tuple[str, bytes]] {
    assert blob[:8] == b"!<arch>\n";
    names = b"";
    members: list[tuple[str, bytes]] = [];
    offset = 8;
    while offset + 60 <= len(blob) {
        header = blob[offset:offset + 60];
        name = header[:16].decode().strip();
        size = int(header[48:58].decode().strip());
        data = blob[offset + 60:offset + 60 + size];
        if name == "//" {
            names = data;
        } elif name not in ("/", "/SYM64/") {
            if name.startswith("/") and names {
                start = int(name[1:]);
                name = names[start:names.index(b"/\n", start)].decode();
            }
            members.append((name.rstrip("/"), data));
        }
        offset += 60 + size + (size % 2);
    }
    return members;
}

test "upstream runtime has independently selectable helpers without libc definitions" {
    definitions: dict[str, str] = {};
    for (name, data) in _ar_members(_runtime()) {
        (defined, _undefined) = llvm.object_symbols(data);
        for symbol in defined {
            assert symbol not in definitions;
            definitions[symbol] = name;
        }
    }
    assert "__aarch64_have_lse_atomics" in definitions;
    assert not ({"memcpy", "memset", "strlen", "memcmp"} & set(definitions));
    helpers: list[str] = [];
    for order in ["relax", "acq", "rel", "acq_rel", "sync"] {
        for op in ["cas", "swp", "ldadd", "ldclr", "ldeor", "ldset"] {
            for size in ([1, 2, 4, 8, 16] if op == "cas" else [1, 2, 4, 8]) {
                name = f"__aarch64_{op}{size}_{order}";
                assert name in definitions;
                helpers.append(definitions[name]);
            }
        }
    }
    assert len(helpers) == len(set(helpers)) == 125;
}

test "the atomics archive supplies a floor atomic and its runtime feature detection" {
    import from jaclang.compiler.backends.native.link_glue { init_object_codegen }
    init_object_codegen();
    triple = "aarch64-unknown-linux-gnu";
    module = llvm.parse_assembly(
        f'target triple = "{triple}"\n'
            + 'declare i64 @__aarch64_ldadd8_acq_rel(i64, ptr)\n'
            + 'define i64 @probe(ptr %p) { %v = call i64 @__aarch64_ldadd8_acq_rel(i64 1, ptr %p) ret i64 %v }\n'
    );
    tm = llvm.Target.from_triple(triple).create_target_machine(opt=2, reloc="pic");
    caller = tm.emit_object(module);
    with tempfile.TemporaryDirectory() as work {
        archive = Path(work) / "libclang_rt.atomics.a";
        archive.write_bytes(_runtime());
        output = str(Path(work) / "probe.so");
        link_native(
            NativeLinkJob(
                platform="elf",
                triple=triple,
                output_path=output,
                shared=True,
                soname="probe.so",
                objects=[caller],
                archives=[str(archive)],
                export_symbols=["probe"],
                needed_libs=["libc.so.6"]
            )
        );
        raw = Path(output).read_bytes();
        offset = struct.unpack_from("<Q", raw, 40)[0];
        (size, count) = struct.unpack_from("<HH", raw, 58);
        headers = [
            struct.unpack_from("<IIQQQQIIQQ", raw, offset + i * size)
            for i in range(count)
        ];
        arrays = [
            header
            for header in headers
            if header[1] == 14
        ];
        assert len(arrays) == 1 and arrays[0][5] == 8;
        import platform;
        if platform.system() == "Linux"
            and platform.machine() in ["aarch64", "arm64"] {
            import ctypes;
            library = ctypes.CDLL(output);
            probe = library.probe;
            probe.argtypes = [ctypes.POINTER(ctypes.c_int64)];
            probe.restype = ctypes.c_int64;
            value = ctypes.c_int64(7);
            assert probe(ctypes.byref(value)) == 7 and value.value == 8;
        }
    }
}
