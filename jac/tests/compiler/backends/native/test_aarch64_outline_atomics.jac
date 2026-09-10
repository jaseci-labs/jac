"""Compiler runtime helpers are selected from the upstream archive on every host."""
import struct;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.dist.payload.vendor { build_outline_atomics }
import from jaclang.compiler.backends.native.elf_linker { ElfLinker }
import from jaclang.compiler.backends.native.linker_common {
    StaticRuntime,
    parse_ar_archive,
    object_undefined_symbols
}

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

def _parsed(blob: bytes) -> ElfLinker {
    linker = ElfLinker(
        obj_data=blob, sections=[], symbols=[], relocations=[], needed_libs=[]
    );
    assert linker.parse_object();
    return linker;
}

test "upstream runtime has independently selectable helpers without libc definitions" {
    members = parse_ar_archive(_runtime());
    definitions: dict[str, str] = {};
    for member in members {
        parsed = _parsed(member.data);
        for symbol in parsed.symbols {
            if symbol.shndx > 0 and symbol.bind > 0 {
                assert symbol.name not in definitions;
                definitions[symbol.name] = member.name;
            }
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

test "archive selection supplies a floor atomic and its runtime feature detection" {
    import jaclang.compiler.backends.native.llvm.binding as llvm;
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
    runtime = StaticRuntime(archives=[_runtime()], crt_objects=[]);
    selected = runtime.select([caller]);
    assert len(selected) == 2;
    assert any("getauxval" in object_undefined_symbols(blob) for blob in selected);
    with tempfile.TemporaryDirectory() as work {
        output = str(Path(work) / "probe.so");
        assert ElfLinker.link(
            objects=[caller],
            archive_members=selected,
            output_path=output,
            shared=True,
            export_symbols=["probe"],
            needed_libs=["libc.so.6"]
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
