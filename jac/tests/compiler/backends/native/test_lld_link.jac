"""LLD links every native artifact in-process (native_link.jac).

These cover the parts of that link no other test reaches: a Windows
executable cross-linked on any host (import libraries written in-process for
each DLL, CRT aliases imported under the CRT's own names), a wasm module whose
host-ABI imports move to the host module after wasm-ld, and a failed link
surfacing LLD's own message.
"""

import os;
import struct;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { jac_command, TESTS_DIR }
import from jaclang.compiler.backends.native.native_link {
    NativeLinkError,
    NativeLinkJob,
    link_native,
    macho_stub_symbols,
    musl_runtime
}
import from jaclang.compiler.backends.native.wasm_build { link_wasm_object }
import from jaclang.compiler.backends.native.wasm_artifact {
    wasm_import_map,
    wasm_object_functions
}
import jaclang.compiler.backends.native.llvm.binding as llvm;

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""The DLL names a PE image's import directory lists."""
def _pe_import_dlls(raw: bytes) -> list[str] {
    e_lfanew = struct.unpack_from("<I", raw, 0x3C)[0];
    nsections = struct.unpack_from("<H", raw, e_lfanew + 6)[0];
    opt_size = struct.unpack_from("<H", raw, e_lfanew + 20)[0];
    opt = e_lfanew + 24;
    (import_rva, _import_size) = struct.unpack_from("<II", raw, opt + 120);
    sections = [
        struct.unpack_from("<8sIIII", raw, opt + opt_size + i * 40)
        for i in range(nsections)
    ];
    def to_offset(rva: int) -> int {
        for (_name, vsize, vaddr, rawsize, rawptr) in sections {
            if vaddr <= rva < vaddr + max(vsize, rawsize) {
                return rawptr + rva - vaddr;
            }
        }
        raise AssertionError(f"rva {hex(rva)} lies in no section");
    }
    dlls: list[str] = [];
    descriptor = to_offset(import_rva);
    while True {
        name_rva = struct.unpack_from("<I", raw, descriptor + 12)[0];
        if name_rva == 0 {
            break;
        }
        start = to_offset(name_rva);
        dlls.append(raw[start:raw.index(b"\x00", start)].decode());
        descriptor += 20;
    }
    return dlls;
}

test "a Windows executable cross-links with import libraries for its DLLs" {
    with tempfile.TemporaryDirectory() as work {
        out = os.path.join(work, "pe_smoke.exe");
        built = subprocess.run(
            jac_command(
                "build",
                "--native",
                "--target-triple",
                "x86_64-pc-windows-msvc",
                os.path.join(FIXTURES, "pe_smoke.jac"),
                "-o",
                out
            ),
            capture_output=True,
            text=True,
            timeout=900
        );
        assert built.returncode == 0 , built.stdout[-800:] + built.stderr[-800:];
        raw = Path(out).read_bytes();
        assert raw[:2] == b"MZ" , "missing MZ signature";
        e_lfanew = struct.unpack_from("<I", raw, 0x3C)[0];
        assert raw[e_lfanew:e_lfanew + 4] == b"PE\x00\x00" , "missing PE signature";
        chars = struct.unpack_from("<H", raw, e_lfanew + 22)[0];
        assert not (chars & 0x2000) , "an executable must not be marked IMAGE_FILE_DLL";
        dlls = [d.lower() for d in _pe_import_dlls(raw)];
        assert "ucrtbase.dll" in dlls , dlls;
        assert "kernel32.dll" in dlls , dlls;
    }
}

test "a wasm module imports its host ABI from the host module and the rest from env" {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    module = llvm.parse_assembly(
        'target triple = "wasm32-unknown-unknown"\n'
            + "declare i32 @write(i32, ptr, i32)\n"
            + "declare i32 @app_hook(i32)\n"
            + "define i32 @run(ptr %p) {\n"
            + "  %a = call i32 @write(i32 1, ptr %p, i32 3)\n"
            + "  %b = call i32 @app_hook(i32 %a)\n"
            + "  ret i32 %b\n}\n"
    );
    tm = llvm.Target.from_triple("wasm32-unknown-unknown").create_target_machine(opt=2);
    wasm_obj = tm.emit_object(module);
    content = link_wasm_object(
        wasm_obj,
        ["run"],
        host_abi={"write"},
        host_module="jac_host1",
        app_imports={"app_hook"}
    );
    imports = wasm_import_map(content);
    assert imports.get("jac_host1") == ["write"] , imports;
    assert imports.get("env") == ["app_hook"] , imports;
    raised = "";
    try {
        link_wasm_object(
            wasm_obj,
            ["run"],
            host_abi={"write"},
            host_module="jac_host1",
            app_imports=set()
        );
    } except RuntimeError as e {
        raised = str(e);
    }
    assert "app_hook" in raised and "neither part of the" in raised , raised;
}

test "a failed link reports LLD's own message and leaves the old output in place" {
    with tempfile.TemporaryDirectory() as work {
        out = os.path.join(work, "libmissing.so");
        Path(out).write_bytes(b"previous build");
        raised = "";
        try {
            link_native(
                NativeLinkJob(
                    platform="elf",
                    triple="x86_64-unknown-linux-gnu",
                    output_path=out,
                    shared=True,
                    archives=[os.path.join(work, "missing.a")],
                    export_symbols=["nothing"]
                )
            );
        } except NativeLinkError as e {
            raised = str(e);
        }
        assert "missing.a" in raised , raised;
        assert Path(out).read_bytes() == b"previous build" , "a failed link replaced the output";
        assert sorted(os.listdir(work)) == ["libmissing.so"] , os.listdir(work);
    }
}

"""Emit `ir` as a position-independent object for `triple`."""
def _object(ir: str, triple: str) -> bytes {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    module = llvm.parse_assembly(f'target triple = "{triple}"\n' + ir);
    tm = llvm.Target.from_triple(triple).create_target_machine(
        opt=2, reloc="pic", codemodel="small"
    );
    return tm.emit_object(module);
}

test "a dylib named by a bare file name loads from beside the binary" {
    triple = "arm64-apple-darwin";
    relobj = _object(
        "declare i32 @raylib_probe()\n"
            + "define i32 @main() {\n  %r = call i32 @raylib_probe()\n  ret i32 %r\n}\n",
        triple
    );
    with tempfile.TemporaryDirectory() as work {
        out = os.path.join(work, "probe");
        link_native(
            NativeLinkJob(
                platform="macho",
                triple=triple,
                output_path=out,
                objects=[relobj],
                needed_libs=["/usr/lib/libSystem.B.dylib", "libraylib.dylib"],
                symbol_lib_map={"raylib_probe": "libraylib.dylib"}
            )
        );
        raw = Path(out).read_bytes();
        assert b"@loader_path/libraylib.dylib\x00" in raw , "bare dylib name not made loader-relative";
    }
}

test "a static link's unresolved-symbol warnings reach the caller" {
    triple = "x86_64-unknown-linux-gnu";
    runtime = musl_runtime(triple);
    if runtime is None {
        return;
    }
    (crt, archives) = runtime;
    relobj = _object(
        "declare i32 @nowhere_defined()\n"
            + "define i32 @main() {\n  %r = call i32 @nowhere_defined()\n  ret i32 %r\n}\n",
        triple
    );
    with tempfile.TemporaryDirectory() as work {
        warnings = link_native(
            NativeLinkJob(
                platform="elf",
                triple=triple,
                output_path=os.path.join(work, "probe"),
                objects=[relobj],
                crt_objects=crt,
                archives=archives,
                static_musl=True
            )
        );
        assert any("nowhere_defined" in w for w in warnings) , warnings;
    }
}

test "a C wasm object with no named exports exports every function it defines" {
    import shutil;
    zig = shutil.which("zig");
    if zig is None {
        return;
    }
    with tempfile.TemporaryDirectory() as work {
        source = Path(work) / "arena.c";
        source.write_text(
            "static int state;\n"
                + "int init(void) { state = 1; return state; }\n"
                + "int tick(int n) { state += n; return state; }\n"
                + "static int helper(void) { return state; }\n"
                + "int peek(void) { return helper(); }\n"
        );
        obj_path = Path(work) / "arena.o";
        subprocess.run(
            [
                zig,
                "cc",
                "-target",
                "wasm32-wasi",
                "-O2",
                "-c",
                str(source),
                "-o",
                str(obj_path)
            ],
            check=True
        );
        functions = wasm_object_functions(obj_path.read_bytes());
        assert sorted(functions) == ["init", "peek", "tick"] , functions;
        content = link_wasm_object(obj_path.read_bytes(), functions);
        raw = content;
        assert b"\x04init" in raw and b"\x04tick" in raw , "functions not exported";
    }
}

test "a macOS dylib leaves its C imports to the host process" {
    undefined = ["_PyGILState_Ensure", "_malloc", "_raylib_probe"];
    shared = NativeLinkJob(
        platform="macho",
        triple="arm64-apple-darwin",
        output_path="libprobe.dylib",
        shared=True,
        needed_libs=["/usr/lib/libSystem.B.dylib", "libraylib.dylib"]
    );
    stubs = macho_stub_symbols(shared, undefined);
    assert set(stubs)
        == {"/usr/lib/libSystem.B.dylib", "@loader_path/libraylib.dylib"} , stubs;
    assert all(not syms for syms in stubs.values()) , f"a dylib bound imports two-level: {stubs}";
    executable = NativeLinkJob(
        platform="macho",
        triple="arm64-apple-darwin",
        output_path="probe",
        needed_libs=["/usr/lib/libSystem.B.dylib", "libraylib.dylib"],
        symbol_lib_map={"raylib_probe": "libraylib.dylib"}
    );
    stubs = macho_stub_symbols(executable, undefined);
    assert stubs["@loader_path/libraylib.dylib"] == ["_raylib_probe"] , stubs;
    assert "_malloc" in stubs["/usr/lib/libSystem.B.dylib"] , stubs;
    relobj = _object(
        "declare i32 @PyGILState_Ensure()\n"
            + "define i32 @probe() {\n  %r = call i32 @PyGILState_Ensure()\n  ret i32 %r\n}\n",
        "arm64-apple-darwin"
    );
    with tempfile.TemporaryDirectory() as work {
        out = os.path.join(work, "libprobe.dylib");
        link_native(
            NativeLinkJob(
                platform="macho",
                triple="arm64-apple-darwin",
                output_path=out,
                shared=True,
                objects=[relobj],
                needed_libs=["/usr/lib/libSystem.B.dylib"],
                export_symbols=["probe"]
            )
        );
        assert Path(out).read_bytes()[:4] == b"\xcf\xfa\xed\xfe";
    }
}
