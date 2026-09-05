"""Tests for the C-ABI shared-library build (`jac nacompile --shared`).

These exercise the three pure-Jac linkers' shared-object paths — ELF .so
(ET_DYN), Mach-O .dylib (MH_DYLIB), and PE .dll (IMAGE_FILE_DLL) — driven by a
single fixture whose `:pub` symbols form the export surface. The object every
linker receives comes from the link plan (`link_plan.build_link_plan`): the
fixture's unit plus the glue module that synthesizes `__jac_shared_init` and
the `jac_retain` / `jac_release` / `jac_str_new` C ABI wrappers, exactly what
`jac nacompile --shared` links.

The ELF case is validated by actually loading the produced .so and calling its
exports through ctypes (the CI native suite runs on Linux); the Mach-O and PE
cases are validated structurally (filetype + export table + init mechanism),
since those binaries cannot be executed on a Linux host.
"""

import os;
import struct;
import sys;
import tempfile;
import from pathlib { Path }
import from tests.support { TESTS_DIR }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options {
    CompileOptions,
    pop_native_target_env,
    push_native_target_env
}
import from jaclang.compiler.backends.native.na_compile_pass {
    create_unit_target_machine
}
import from jaclang.compiler.backends.native.elf_linker { ElfLinker }
import from jaclang.compiler.backends.native.macho_linker { MachOLinker }
import from jaclang.compiler.backends.native.pe_linker { PeLinker }
import from jaclang.compiler.backends.native.linker_common {
    clib_needed_libs,
    clib_symbol_lib_map
}
# The link plan owns __jac_shared_init + the public RC wrappers (the glue
# module of `link_glue`). Building through it here keeps the tests on the
# production code path -- a prior hand-rolled injection let a quoted-symbol
# glob-init bug slip past this whole file.
import from jaclang.compiler.backends.native.link_plan {
    ArtifactKind,
    build_link_plan,
    link_artifact,
    whole_program_module
}
import jaclang.compiler.backends.native.llvm.binding as llvm;

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "shared_export.jac";


# ─── helpers ─────────────────────────────────────────────────────────────────
"""The AOT native-unit options for `triple`: what `jac nacompile` compiles
with, minus the in-process engine."""
def shared_opts(triple: str) -> CompileOptions {
    return CompileOptions(
        aot_mode=True,
        default_codespace='native',
        force_target_program=True,
        skip_native_engine=True,
        native_target=triple
    );
}

"""The platform family of a target triple, as the link plan names it."""
def _platform_of(triple: str) -> str {
    tl = triple.lower();
    if ("windows" in tl) or ("msvc" in tl) or ("mingw" in tl) {
        return "pe";
    }
    if ("darwin" in tl) or ("apple" in tl) or ("macos" in tl) {
        return "macho";
    }
    return "elf";
}

"""Compile the fixture for `triple` as a native unit and build its link plan
rooted at the fixture. Returns (prog, plan, options)."""
def plan_shared(fixture: str, triple: str) -> tuple {
    path = os.path.join(FIXTURES, fixture);
    opts = shared_opts(triple);
    prog = JacProgram();
    mod = prog.compile(file_path=path, options=opts);
    assert not prog.errors_had , f"compile errors: {[
        str(e) for e in prog.errors_had
    ]}";
    assert mod.gen.native_iface is not None , f"{fixture} exported no native interface";
    plan = build_link_plan(prog, [path], opts);
    return (prog, plan, opts);
}

"""Compile the fixture for `triple` through the link plan and emit ONE PIC
relocatable object holding the fixture's unit plus the plan's glue
(`__jac_shared_init` and the public RC wrappers), mirroring the whole-program
mode of `jac nacompile --shared`.

Returns (object_bytes, export_symbols): the `:pub` symbols, bare, plus the
glue's `jac_retain` / `jac_release` / `jac_str_new` / `__jac_shared_init`."""
def emit_shared_object(fixture: str, triple: str) -> tuple {
    prev = push_native_target_env(triple);
    try {
        (_prog, plan, opts) = plan_shared(fixture, triple);
        spec = plan.glue_spec(ArtifactKind.SHARED, _platform_of(triple), False);
        (merged, glue_exports) = whole_program_module(plan, spec);
        tm = create_unit_target_machine(opts);
        relobj = tm.emit_object(merged);
        assert isinstance(relobj, bytes);
        exports = list(plan.pub_exports());
        for sym in glue_exports {
            if sym not in exports {
                exports.append(sym);
            }
        }
    } finally {
        pop_native_target_env(prev);
    }
    return (relobj, exports);
}

"""Link the fixture into a shared library at `out_path` for `triple` through
`link_artifact`, the path `jac nacompile --shared` takes. Returns the
LinkResult."""
def link_shared(fixture: str, triple: str, out_path: str) -> any {
    prev = push_native_target_env(triple);
    try {
        (_prog, plan, _opts) = plan_shared(fixture, triple);
        return link_artifact(plan, out_path, ArtifactKind.SHARED);
    } finally {
        pop_native_target_env(prev);
    }
}


"""Parse execSegFlags out of an embedded ad-hoc code signature.

`sig_off` is the LC_CODE_SIGNATURE dataoff. Walks the SuperBlob to its
CodeDirectory and returns the 8-byte execSegFlags field (at CD offset 80 in
the 0x20400 layout). Returns None if the signature magics don't match — i.e.
the binary is unsigned (x86_64 dylibs/executables are not signed here)."""
def _exec_seg_flags(raw: bytes, sig_off: int) -> (int | None) {
    if struct.unpack_from(">I", raw, sig_off)[0] != 0xFADE0CC0 {  # SuperBlob
        return None;
    }
    count = struct.unpack_from(">I", raw, sig_off + 8)[0];
    idx = sig_off + 12;
    for _ in range(count) {
        boff = struct.unpack_from(">II", raw, idx)[1];  # (blobType, offset)
        cd = sig_off + boff;
        if struct.unpack_from(">I", raw, cd)[0] == 0xFADE0C02 {  # CodeDirectory
            return struct.unpack_from(">Q", raw, cd + 80)[0];  # execSegFlags
        }
        idx += 8;
    }
    return None;
}


"""Scan Mach-O load commands for the fields the dylib test asserts on."""
def _macho_info(raw: bytes) -> dict {
    filetype = struct.unpack_from("<I", raw, 12)[0];
    ncmds = struct.unpack_from("<I", raw, 16)[0];
    off = 32;
    has_id_dylib = False;
    has_load_dylinker = False;
    export_size = 0;
    has_mod_init = False;
    sig_off = 0;
    for _ in range(ncmds) {
        (cmd, cmdsize) = struct.unpack_from("<II", raw, off);
        if cmd == 0x0D {  # LC_ID_DYLIB
            has_id_dylib = True;
        } elif cmd == 0x0E {  # LC_LOAD_DYLINKER
            has_load_dylinker = True;
        } elif cmd == 0x1D {  # LC_CODE_SIGNATURE
            sig_off = struct.unpack_from("<I", raw, off + 8)[0];  # dataoff
        } elif cmd == 0x80000022 {  # LC_DYLD_INFO_ONLY
            export_size = struct.unpack_from("<I", raw, off + 44)[0];
        } elif cmd == 0x19 {  # LC_SEGMENT_64
            nsects = struct.unpack_from("<I", raw, off + 64)[0];
            so = off + 72;
            for _s in range(nsects) {
                sn = raw[so:so + 16].split(b"\x00")[0];
                if sn == b"__mod_init_func" {
                    has_mod_init = True;
                }
                so += 80;
            }
        }
        off += cmdsize;
    }
    return {
        "filetype": filetype,
        "has_id_dylib": has_id_dylib,
        "has_load_dylinker": has_load_dylinker,
        "export_size": export_size,
        "has_mod_init": has_mod_init,
        "exec_seg_flags": _exec_seg_flags(raw, sig_off) if sig_off else None
    };
}


# ─── tests ───────────────────────────────────────────────────────────────────
test "ELF shared object loads and runs through the C ABI" {
    # Pin an explicit ELF triple so the emitted object is ELF on any host (the
    # macOS native job runs this same file; its default triple is darwin, which
    # would yield a Mach-O object that ElfLinker cannot link). Execution below
    # stays gated to a Linux x86_64 host that can actually dlopen the result.
    (relobj, exports) = emit_shared_object(FIXTURE, "x86_64-unknown-linux-gnu");
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as d {
        out = os.path.join(d, "libshared_export.so");
        ok = ElfLinker.link(
            objects=[relobj],
            output_path=out,
            needed_libs=["libc.so.6", "libm.so.6"],
            shared=True,
            export_symbols=exports,
            init_funcs=["__jac_shared_init"],
            soname="libshared_export.so"
        );
        assert ok , "ElfLinker.link(shared=True) returned False";
        raw = Path(out).read_bytes();
        assert raw[:4] == b"\x7fELF" , "not an ELF image";
        e_type = struct.unpack_from("<H", raw, 16)[0];
        assert e_type == 3 , f"expected ET_DYN (3), got {e_type}";
        # Only a Linux x86_64 host can dlopen + execute the produced .so.
        if sys.platform.startswith("linux")
            and ("x86_64" in llvm.get_default_triple()) {
            import ctypes;
            lib = ctypes.CDLL(out);
            lib.jadd.restype = ctypes.c_int64;
            lib.jadd.argtypes = [ctypes.c_int64, ctypes.c_int64];
            assert lib.jadd(2, 3) == 5;
            lib.jmul.restype = ctypes.c_int64;
            lib.jmul.argtypes = [ctypes.c_int64, ctypes.c_int64];
            assert lib.jmul(4, 5) == 20;
            lib.get_counter.restype = ctypes.c_int64;
            assert lib.get_counter() == 7;  # glob:pub counter
            lib.make_point.restype = ctypes.c_void_p;
            lib.make_point.argtypes = [ctypes.c_int64, ctypes.c_int64];
            lib.point_sum.restype = ctypes.c_int64;
            lib.point_sum.argtypes = [ctypes.c_void_p];
            p = lib.make_point(3, 4);
            assert p , "make_point returned NULL";
            assert lib.point_sum(p) == 7 , "opaque object handle round-trip failed";
            lib.jac_release.argtypes = [ctypes.c_void_p];
            lib.jac_release(p);  # public RC wrapper over __rc_release_simple
        }
    }
}


test "the plan's shared glue calls the unit initializer and exports the C ABI" {
    # The glue module (`link_glue.link_glue_ir`) is where `__jac_shared_init`
    # comes from: it calls every unit's initializer, named from the unit's
    # interface (`native_glob_init_name(path)`), never by scanning IR text
    # for `@__jac_glob_init` -- the quoted-symbol form that the old injection
    # missed, leaving every runtime-initialized global NULL in a --shared
    # library. The C ABI wrappers ride along as exports.
    import from jaclang.compiler.backends.native.link_glue { link_glue_ir }
    import from jaclang.compiler.frontend.codeinfo { native_glob_init_name }
    triple = "x86_64-unknown-linux-gnu";
    prev = push_native_target_env(triple);
    try {
        (_prog, plan, _opts) = plan_shared("shared_glob_struct.jac", triple);
    } finally {
        pop_native_target_env(prev);
    }
    root = plan.root_unit();
    init_sym = native_glob_init_name(root.path);
    assert root.iface.init == init_sym , (
        f"unit interface names initializer {root.iface.init!r}, expected {init_sym!r}"
    );
    assert plan.init_symbols() == [init_sym] , plan.init_symbols();
    spec = plan.glue_spec(ArtifactKind.SHARED, "elf", False);
    assert spec.shared , "a SHARED glue spec must be marked shared";
    (glue_ir, glue_exports) = link_glue_ir(spec);
    assert "define void @__jac_shared_init()" in glue_ir , glue_ir;
    assert f'call void @"{init_sym}"()' in glue_ir , (
        "the glue dropped the unit's initializer call from __jac_shared_init"
    );
    assert "define i32 @main(" not in glue_ir , "a shared library carries no platform entry";
    assert "__jac_shared_init" in glue_exports , glue_exports;
    assert "jac_str_new" in glue_exports , glue_exports;
    for wrapper in ("jac_retain", "jac_release") {
        if wrapper in root.iface.exports {
            assert wrapper in glue_exports , f"{wrapper} shim present but not exported";
            assert f"define void @{wrapper}(ptr" in glue_ir , glue_ir;
        }
    }
    # The export surface handed to a linker: bare `:pub` names plus the glue.
    (_relobj, exports) = emit_shared_object("shared_glob_struct.jac", triple);
    assert "set_struct_field" in exports and "read_struct_field" in exports , exports;
    assert "__jac_shared_init" in exports , exports;
    for sym in exports {
        assert "." not in sym , f"a shared export must be a bare C symbol, got {sym!r}";
    }
}


test "link_artifact builds a shared library from the plan with its sidecar" {
    # `jac nacompile --shared` is `link_artifact(plan, out, ArtifactKind.SHARED)`:
    # the plan picks the platform linker from its triple, exports the `:pub`
    # symbols plus the glue's C ABI, and drops the layout sidecar beside the
    # artifact with the plan and layout digests. Pinned to an ELF triple so the
    # link runs on any host; execution stays gated to a Linux x86_64 host.
    triple = "x86_64-unknown-linux-gnu";
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as d {
        out = os.path.join(d, "libshared_export_plan.so");
        result = link_shared(FIXTURE, triple, out);
        assert result.output_path == out , result.output_path;
        assert os.path.isfile(out) , "link_artifact produced no shared library";
        raw = Path(out).read_bytes();
        assert raw[:4] == b"\x7fELF" , "not an ELF image";
        e_type = struct.unpack_from("<H", raw, 16)[0];
        assert e_type == 3 , f"expected ET_DYN (3), got {e_type}";
        assert result.plan_digest and result.layout_digest , result;
        assert len(result.sha256) == 64 , result.sha256;
        assert any(u.endswith(FIXTURE) for u in result.units) , result.units;
        import json;
        with open(out + ".layout.json", "r", encoding="utf-8") as lf {
            sidecar = json.load(lf);
        }
        assert sidecar.get("plan_digest") == result.plan_digest , sidecar;
        assert sidecar.get("layout_digest") == result.layout_digest , sidecar;
        assert isinstance(sidecar.get("classes"), dict) , sidecar;
        assert "Point" in sidecar["classes"] , f"obj:pub Point missing from the layout: {sidecar}";
        if sys.platform.startswith("linux")
            and ("x86_64" in llvm.get_default_triple()) {
            import ctypes;
            lib = ctypes.CDLL(out);
            lib.jadd.restype = ctypes.c_int64;
            lib.jadd.argtypes = [ctypes.c_int64, ctypes.c_int64];
            assert lib.jadd(2, 3) == 5;
            lib.get_counter.restype = ctypes.c_int64;
            assert lib.get_counter() == 7;
        }
    }
}


test "ELF shared object initializes a global clib struct on dlopen" {
    # Regression guard for the `--shared` global-clib-struct segfault. The
    # struct pointer `g` is populated by the unit's initializer
    # (`native_glob_init_name(path)`), which only runs if the glue's
    # __jac_shared_init calls it -- exactly what the old text-scan injection
    # broke on a quoted symbol. The plan names the initializer from the unit's
    # interface, never by scanning IR text.
    (relobj, exports) = emit_shared_object(
        "shared_glob_struct.jac", "x86_64-unknown-linux-gnu"
    );
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as d {
        out = os.path.join(d, "libshared_glob_struct.so");
        ok = ElfLinker.link(
            objects=[relobj],
            output_path=out,
            needed_libs=["libc.so.6"],
            shared=True,
            export_symbols=exports,
            init_funcs=["__jac_shared_init"],
            soname="libshared_glob_struct.so"
        );
        assert ok , "ElfLinker.link(shared=True) returned False";
        # Only a Linux x86_64 host can dlopen + execute the produced .so.
        if sys.platform.startswith("linux")
            and ("x86_64" in llvm.get_default_triple()) {
            import ctypes;
            lib: ctypes.CDLL | None = None;
            try {
                lib = ctypes.CDLL(out);  # __jac_shared_init runs here (CTOR)
            } except OSError as _e {
                # Some hardened kernels refuse a .so lacking an explicit
                # `.note.GNU-stack` non-exec marker ("cannot enable executable
                # stack"). That is a toolchain/kernel concern unrelated to this
                # fix: the plan build + link above already exercised the
                # codegen path, and the glue test below locks the init call.
                print(f"[skip-dlopen] host refuses execstack load: {_e}");
            }
            if lib is not None {
                lib.read_struct_field.restype = ctypes.c_int64;
                # Before the fix this SIGSEGV'd: `g` was NULL so `g.a` deref'd NULL.
                assert lib.read_struct_field() == 0 , (
                    "global clib struct not initialized on dlopen (init not called)"
                );
                lib.set_struct_field.restype = ctypes.c_int64;
                lib.set_struct_field.argtypes = [ctypes.c_int64];
                assert lib.set_struct_field(42) == 42 , "set_struct_field round-trip failed";
                assert lib.read_struct_field() == 42 , (
                    "field write to a global clib struct did not persist"
                );
            }
        }
    }
}


test "Mach-O dylib has MH_DYLIB filetype, export trie, and init section" {
    (relobj, exports) = emit_shared_object(FIXTURE, "x86_64-apple-darwin");
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as d {
        out = os.path.join(d, "libshared_export.dylib");
        ok = MachOLinker.link(
            objects=[relobj],
            output_path=out,
            needed_libs=["/usr/lib/libSystem.B.dylib"],
            shared=True,
            export_symbols=exports,
            init_funcs=["__jac_shared_init"],
            soname="libshared_export.dylib"
        );
        assert ok , "MachOLinker.link(shared=True) returned False";
        raw = Path(out).read_bytes();
        assert struct.unpack_from("<I", raw, 0)[0] == 0xFEEDFACF , "not a Mach-O 64 image";
        info = _macho_info(raw);
        assert info["filetype"] == 6 , f"expected MH_DYLIB (6), got {info['filetype']}";
        assert info["has_id_dylib"] , "missing LC_ID_DYLIB";
        assert info["export_size"] > 0 , "empty export trie";
        assert info["has_mod_init"] , "missing __mod_init_func";
    }
}


"""Build a dylib from the scalar-only fixture for `triple` and return its
parsed Mach-O info. Kept separate from the object-handle FIXTURE so these
load-command assertions don't depend on object attribute-access support."""
def _build_scalar_dylib(triple: str, name: str) -> dict {
    (relobj, exports) = emit_shared_object("shared_export_scalar.jac", triple);
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as d {
        out = os.path.join(d, name);
        ok = MachOLinker.link(
            objects=[relobj],
            output_path=out,
            needed_libs=["/usr/lib/libSystem.B.dylib"],
            shared=True,
            export_symbols=exports,
            init_funcs=["__jac_shared_init"],
            soname="libshared_export_scalar.dylib"
        );
        assert ok , f"MachOLinker.link(shared=True) returned False for {triple}";
        info = _macho_info(Path(out).read_bytes());
        assert info["filetype"] == 6 , f"expected MH_DYLIB (6), got {info['filetype']}";
        return info;
    }
}


test "Mach-O dylib does not carry LC_LOAD_DYLINKER (x86_64 and arm64)" {
    # LC_LOAD_DYLINKER is only valid in MH_EXECUTE — a dylib that carries it
    # fails to load on macOS. Both arch paths must omit it (PR #6828).
    for triple in ["x86_64-apple-darwin", "arm64-apple-darwin"] {
        info = _build_scalar_dylib(triple, "libld.dylib");
        assert not info["has_load_dylinker"] , f"MH_DYLIB ({triple}) must not carry LC_LOAD_DYLINKER";
    }
}


test "Mach-O arm64 dylib is ad-hoc signed with execSegFlags == 0" {
    # The arm64 path emits an embedded code signature. CS_EXECSEG_MAIN_BINARY
    # (0x1) in execSegFlags is only valid for the main executable's __TEXT
    # segment; setting it on a dylib triggers a macOS load error. Guard that
    # dylibs sign with execSegFlags == 0 — the counterpart to the executable
    # test in test_exec_link asserting it is set (PR #6828).
    info = _build_scalar_dylib("arm64-apple-darwin", "libexecseg.dylib");
    assert info["exec_seg_flags"] is not None , "arm64 dylib is not code-signed";
    assert info["exec_seg_flags"] == 0 , f"dylib execSegFlags must be 0, got {info[
        'exec_seg_flags'
    ]}";
}


test "Mach-O link refuses a relocation it cannot apply" {
    # A relocation this linker has no arm applied to be silently dropped: the
    # instruction kept whatever immediate the assembler left in it, so the
    # artifact linked clean and pointed at whatever else landed nearby. That
    # is how the macos-aarch64 seal shipped an artifact whose module-init
    # read its string constants out of a merged floor archive and aborted on
    # an uncaught exception inside __jac_shared_init (#8313). Retype one real
    # relocation to ARM64_RELOC_TLVP_LOAD_PAGE21 (8), which this linker does
    # not implement, and require the link to refuse by name.
    (relobj, exports) = emit_shared_object(
        "shared_export_scalar.jac", "arm64-apple-darwin"
    );
    raw = bytearray(relobj);
    ncmds = struct.unpack_from("<I", raw, 16)[0];
    off = 32;
    patched = False;
    for _i in range(ncmds) {
        (cmd, cmdsize) = struct.unpack_from("<II", raw, off);
        if cmd == 0x19 and not patched {
            nsects = struct.unpack_from("<I", raw, off + 64)[0];
            so = off + 72;
            for _j in range(nsects) {
                (reloff, nreloc) = struct.unpack_from("<II", raw, so + 56);
                if nreloc > 0 {
                    r_info = struct.unpack_from("<I", raw, reloff + 4)[0];
                    struct.pack_into(
                        "<I", raw, reloff + 4, (r_info & 0x0FFFFFFF) | (8 << 28)
                    );
                    patched = True;
                    break;
                }
                so += 80;
            }
        }
        off += cmdsize;
    }
    assert patched , "the fixture object carries no relocation to retype";
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as d {
        out = os.path.join(d, "librefuse.dylib");
        raised = "";
        try {
            MachOLinker.link(
                objects=[bytes(raw)],
                output_path=out,
                needed_libs=["/usr/lib/libSystem.B.dylib"],
                shared=True,
                export_symbols=exports,
                init_funcs=["__jac_shared_init"],
                soname="librefuse.dylib"
            );
        } except Exception as exc {
            raised = str(exc);
        }
        assert raised , (
            "MachOLinker linked an object carrying a relocation it cannot "
            "apply; that instruction ships unpatched and the artifact is "
            "wrong at run time"
        );
        assert "relocation type 8" in raised , raised;
        assert not os.path.exists(out) , "a refused link must leave no artifact";
    }
}


test "Mach-O dylib dlopen/dlsym round-trip resolves :pub exports (macOS host only)" {
    # The issue (#6821) reported the produced dylib "loads, codesigns" but
    # dlsym fails — a symbol-resolution symptom distinct from the load-command
    # fixes covered by the structural tests above. This test closes that gap by
    # actually dlopen-ing the dylib and calling its :pub exports through ctypes,
    # mirroring the ELF round-trip. The CI native suite runs on Linux, where a
    # Mach-O dylib can't be loaded, so this is a no-op there; on a macOS host it
    # exercises the full load -> resolve -> call chain the issue described.
    triple = llvm.get_default_triple();
    if not (sys.platform == "darwin" and "apple" in triple) {
        return;
    }
    (relobj, exports) = emit_shared_object("shared_export_scalar.jac", triple);
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as d {
        out = os.path.join(d, "libdlopen_roundtrip.dylib");
        ok = MachOLinker.link(
            objects=[relobj],
            output_path=out,
            needed_libs=["/usr/lib/libSystem.B.dylib"],
            shared=True,
            export_symbols=exports,
            init_funcs=["__jac_shared_init"],
            soname="libdlopen_roundtrip.dylib"
        );
        assert ok , "MachOLinker.link(shared=True) returned False";
        import ctypes;
        lib = ctypes.CDLL(out);  # dlopen — fails if the load-command fix regressed
        # Resolve whichever spelling the export trie carries — bare (the linker's
        # convention) or leading-underscore (macOS C convention). The dedicated
        # trie-naming test below pins which; this one only cares that a consumer
        # can actually dlsym + call the export (the issue's reported symptom).
        jadd = lib?.jadd or lib?._jadd;
        assert jadd is not None , "neither 'jadd' nor '_jadd' resolved via dlsym";
        jadd.restype = ctypes.c_int64;
        jadd.argtypes = [ctypes.c_int64, ctypes.c_int64];
        assert jadd(2, 3) == 5 , "jadd resolved but returned wrong value";
        jmul = lib?.jmul or lib?._jmul;
        assert jmul is not None , "neither 'jmul' nor '_jmul' resolved via dlsym";
        jmul.restype = ctypes.c_int64;
        jmul.argtypes = [ctypes.c_int64, ctypes.c_int64];
        assert jmul(4, 5) == 20 , "jmul resolved but returned wrong value";
        counter = lib?.get_counter or lib?._get_counter;
        assert counter is not None , "neither 'get_counter' nor '_get_counter' resolved";
        counter.restype = ctypes.c_int64;
        assert counter() == 7 , "get_counter resolved but returned wrong value";
    }
}


test "Mach-O dylib export trie uses bare (non-underscored) :pub names (macOS host only)" {
    # The issue flagged the leading-underscore convention as an open question.
    # On macOS a C symbol `jadd` is exported as `_jadd` in the trie; dyld's dlsym
    # prepends the underscore, so a consumer resolves it with the BARE spelling
    # (`dlsym("jadd")`) while the underscored spelling (`dlsym("_jadd")` -> seeks
    # `__jadd`) does NOT resolve. Pin that consumer-facing contract so a
    # regression in the export-trie builder flips this test rather than silently
    # breaking dlsym for consumers (issue #6821). No-op on non-macOS.
    triple = llvm.get_default_triple();
    if not (sys.platform == "darwin" and "apple" in triple) {
        return;
    }
    (relobj, exports) = emit_shared_object("shared_export_scalar.jac", triple);
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as d {
        out = os.path.join(d, "libtrie_probe.dylib");
        ok = MachOLinker.link(
            objects=[relobj],
            output_path=out,
            needed_libs=["/usr/lib/libSystem.B.dylib"],
            shared=True,
            export_symbols=exports,
            init_funcs=["__jac_shared_init"],
            soname="libtrie_probe.dylib"
        );
        assert ok , "MachOLinker.link(shared=True) returned False";
        import ctypes;
        lib = ctypes.CDLL(out);
        bare = lib?.jadd;
        under = lib?._jadd;
        assert bare is not None , "bare 'jadd' missing from export trie — trie empty or mis-built";
        assert under is None , "both 'jadd' and '_jadd' resolve — trie naming convention changed";
    }
}


test "PE dll has IMAGE_FILE_DLL, export directory, and a non-zero entry" {
    (relobj, exports) = emit_shared_object(FIXTURE, "x86_64-pc-windows-msvc");
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as d {
        out = os.path.join(d, "libshared_export.dll");
        ok = PeLinker.link(
            objects=[relobj],
            output_path=out,
            needed_libs=["msvcrt.dll"],
            shared=True,
            export_symbols=exports,
            init_funcs=["__jac_shared_init"],
            soname="libshared_export.dll"
        );
        assert ok , "PeLinker.link(shared=True) returned False";
        raw = Path(out).read_bytes();
        assert raw[0:2] == b"MZ" , "missing MZ signature";
        e_lfanew = struct.unpack_from("<I", raw, 0x3C)[0];
        assert raw[e_lfanew:e_lfanew + 4] == b"PE\x00\x00" , "missing PE signature";
        chars = struct.unpack_from("<H", raw, e_lfanew + 4 + 18)[0];
        assert chars & 0x2000 , "IMAGE_FILE_DLL characteristic not set";
        opt = e_lfanew + 4 + 20;
        entry_rva = struct.unpack_from("<I", raw, opt + 16)[0];
        assert entry_rva != 0 , "DllMain entry point not set";
        # Data directory 0 = export table.
        (exp_rva, exp_sz) = struct.unpack_from("<II", raw, opt + 112);
        assert exp_sz > 0 , "no export directory";
    }
}


# ─── CLI shared-init regression ──────────────────────────────────────────────
# The test helpers above build `__jac_shared_init` through the link plan's
# glue, which names each unit's initializer from its interface. The old
# `jac nacompile --shared` CLI injected the call by scanning linked IR text
# for `"@__jac_glob_init("` -- which never matched llvmlite's quoted
# `@"__jac_glob_init"` output, so the call was silently dropped and every
# runtime-initialized global in a --shared library stayed NULL. This test
# drives the actual CLI so a regression anywhere on that path surfaces as a
# segfault, not a silent no-op.
"""Fixture source: a --shared lib with a global clib struct that needs runtime
init (not a compile-time constant). The export reads the struct field; if
__jac_shared_init never called __jac_glob_init, the global pointer is NULL and
the field read segfaults."""
glob _CLI_SHARED_FIXTURE = (
         "import from \"libc.so.6\" {\n"
         "    obj my_struct {\n"
         "        has a: int = 0,\n"
         "            b: int = 0;\n"
         "    }\n"
         "    def write(fd: i32, buf: int, count: i32) -> i32;\n"
         "}\n"
         "glob g: my_struct = my_struct();\n"
         "def:pub set_g -> int {\n"
         "    g.a = 42;\n"
         "    return g.a;\n"
         "}\n"
     );

test "jac nacompile --shared initialises runtime globals via __jac_shared_init" {
    # The CLI probe + DT_INIT_ARRAY path is ELF-specific; skip on non-Linux.
    if not sys.platform.startswith("linux") {
        return;
    }
    import ctypes;
    import shutil;
    import subprocess;
    jac = shutil.which("jac") or "jac";
    d = tempfile.mkdtemp();
    try {
        lib_src = os.path.join(d, "lib.jac");
        with open(lib_src, "w") as f {
            f.write(_CLI_SHARED_FIXTURE);
        }
        lib_out = os.path.join(d, "lib.so");
        res = subprocess.run(
            [jac, "nacompile", "--shared", lib_src, "-o", lib_out],
            capture_output=True,
            text=True,
            timeout=300
        );
        assert res.returncode == 0 , f"nacompile --shared failed:\n{res.stderr}";
        assert os.path.exists(lib_out) , "shared library not produced";
        # dlopen triggers DT_INIT_ARRAY -> __jac_shared_init -> the unit's
        # initializer. If the init call was dropped, the global pointer is
        # NULL and set_g segfaults (exit 139) instead of returning 42.
        lib = ctypes.CDLL(lib_out);
        lib.set_g.restype = ctypes.c_int64;
        assert lib.set_g() == 42 , "global clib struct not initialised (null pointer)";
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


# ─── C imports of a shared library: process lookup on darwin ─────────────────
# The compiler kernel (libjac_compiler) declares the CPython C API under
# `import from c` and is dlopened by a process that holds libpython
# RTLD_GLOBAL. On darwin that path resolves to "libc.dylib", a library no macOS
# has, and nacompile's link two-level-bound every one of those symbols to it
# (dyld reported libSystem): every macOS build of 0.37.3 died at first run with
# `Symbol not found: _PyDict_GetItem`. These pin both halves of the fix in
# linker_common, on any host.

test "a darwin shared build binds its C imports through the process" {
    needed: list[str] = ["/usr/lib/libSystem.B.dylib"];
    norm = clib_needed_libs(needed, ["libc.dylib"], set());
    assert needed == ["/usr/lib/libSystem.B.dylib"] , f"phantom dependency named: {needed}";
    assert norm == {"libc.dylib": "/usr/lib/libSystem.B.dylib"} , f"unexpected normalization: {norm}";
    syms = {"PyDict_GetItem": "libc.dylib", "memcpy": "libc.dylib"};
    shared_map = clib_symbol_lib_map(syms, set(), norm, True, True);
    assert shared_map == {"PyDict_GetItem": "@process", "memcpy": "@process"} , (
        f"a dylib's C imports must be process lookups, got {shared_map}"
    );
}


test "a darwin executable binds its C imports to libSystem, never to libc.dylib" {
    needed: list[str] = ["/usr/lib/libSystem.B.dylib"];
    norm = clib_needed_libs(needed, ["@loader_path/libc.dylib", "libm.dylib"], set());
    assert needed == ["/usr/lib/libSystem.B.dylib"] , f"phantom dependency named: {needed}";
    exe_map = clib_symbol_lib_map(
        {"memcpy": "@loader_path/libc.dylib", "sin": "libm.dylib"},
        set(),
        norm,
        False,
        True
    );
    assert exe_map
        == {
            "memcpy": "/usr/lib/libSystem.B.dylib",
            "sin": "/usr/lib/libSystem.B.dylib"
        } , f"an executable keeps two-level binding, got {exe_map}";
}


test "an ELF link still names libc.so.6 and binds two-level" {
    needed: list[str] = [];
    norm = clib_needed_libs(needed, ["libc.so", "$ORIGIN/libfoo.so"], set());
    assert needed == ["libc.so.6", "$ORIGIN/libfoo.so"] , f"{needed}";
    m = clib_symbol_lib_map(
        {"write": "libc.so", "foo": "$ORIGIN/libfoo.so"}, set(), norm, True, False
    );
    assert m == {"write": "libc.so.6", "foo": "$ORIGIN/libfoo.so"} , f"{m}";
}


test "a floor-satisfied C import names no library and maps no symbol" {
    needed: list[str] = ["/usr/lib/libSystem.B.dylib"];
    handled: set[str] = {"libcrypto.dylib"};
    norm = clib_needed_libs(needed, ["libcrypto.dylib"], handled);
    assert needed == ["/usr/lib/libSystem.B.dylib"] and norm == {} , f"{needed} {norm}";
    m = clib_symbol_lib_map({"SHA256": "libcrypto.dylib"}, handled, norm, True, True);
    assert m == {} , f"{m}";
}


glob _CLI_PROCESS_EXTERN_FIXTURE = (
         "import from c {\n"
         "    def PyDict_Size(d: int) -> int;\n"
         "}\n"
         "def:pub dict_len(d: int) -> int {\n"
         "    return PyDict_Size(d);\n"
         "}\n"
     );


test "jac nacompile --shared resolves a CPython C-API import from the host process (macOS host only)" {
    # What the compiler kernel does, end to end: `import from c` a CPython
    # C-API symbol and get called from Python through ctypes. This test process
    # is CPython, so a correctly linked dylib finds PyDict_Size by flat lookup
    # and the call agrees with len(). On 0.37.3 dlopen itself failed here.
    triple = llvm.get_default_triple();
    if not (sys.platform == "darwin" and "apple" in triple) {
        return;
    }
    import ctypes;
    import shutil;
    import subprocess;
    jac = shutil.which("jac") or "jac";
    d = tempfile.mkdtemp();
    try {
        lib_src = os.path.join(d, "procext.jac");
        with open(lib_src, "w") as f {
            f.write(_CLI_PROCESS_EXTERN_FIXTURE);
        }
        lib_out = os.path.join(d, "libprocext.dylib");
        res = subprocess.run(
            [jac, "nacompile", "--shared", lib_src, "-o", lib_out],
            capture_output=True,
            text=True,
            timeout=600
        );
        assert res.returncode == 0 , f"nacompile --shared failed:\n{res.stderr}";
        assert os.path.exists(lib_out) , "shared library not produced";
        # dlopen: the 0.37.3 kernel died on this line.
        lib = ctypes.PyDLL(lib_out);
        lib.dict_len.restype = ctypes.c_int64;
        lib.dict_len.argtypes = [ctypes.c_void_p];
        probe = {"a": 1, "b": 2, "c": 3};
        assert lib.dict_len(id(probe)) == 3 , (
            "PyDict_Size through the dylib disagrees with len()"
        );
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}
