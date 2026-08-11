"""Round-trip test for the sealed AOT native lexer.

Exercises the exact pipeline the seal runs (utils/precompile_bytecode.jac
`seal_native_artifacts`) and the exact pipeline the sealed runtime runs
(frontend.jac `_native_scan` via jac0core/native_dylib.jac): AOT-compile the
compiler's own lexer, emit a shared library + layout JSON with the in-house
linkers, dlopen it with plain ctypes (no LLVM engine), and assert
token-for-token parity against the bytecode lexer.
"""

import ctypes;
import json;
import os;
import tempfile;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.codeinfo { native_layout_to_dict }
import from jaclang.jac0core.native_dylib { DylibEngine, layout_from_dict }
import from jaclang.jac0core.native_marshal {
    build_ctypes_classes,
    build_enum_maps,
    wrap_native_function
}
import from jaclang.compiler.passes.native.shared_emit { emit_shared_library }
import jaclang.jac0core.parser.lexer as bytecode_lexer;

glob LEXER_PATH = str(
         Path(jaclang.__file__).parent / "jac0core" / "parser" / "lexer.jac"
     ),
     _ARTIFACT_MEMO: list = [];

"""Compile + link the lexer dylib once for this worker; returns
(lib_path, layout_dict, tmp_dir_keepalive)."""
def _build_artifact -> tuple {
    if _ARTIFACT_MEMO {
        return _ARTIFACT_MEMO[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=LEXER_PATH,
        options=CompileOptions(
            aot_mode=True,
            type_check=False,
            force_codespace='native',
            force_target_program=True,
            na_gc_mode='cycles'
        )
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"lexer AOT compile errors: {errors}";
    assert ir is not None and ir.gen.llvm_ir is not None , "no llvm ir";
    layout = ir.gen.native_layout;
    assert layout is not None , "no native layout";
    manifest = ir.gen.interop_manifest;
    assert not (manifest is not None and manifest.native_imports) , (
        "lexer must have no python-side imports"
    );

    tmp_dir = tempfile.mkdtemp(prefix="jac_sealed_lexer_");
    ext = ".dylib" if os.uname().sysname == "Darwin" else ".so";
    lib_path = os.path.join(tmp_dir, f"libjac_lexer{ext}");
    exports = sorted(layout.functions.keys());
    assert "tokenize_full" in exports , f"exports missing tokenize_full: {exports}";
    transitive = list(manifest.native_transitive_sources) if manifest else [];
    (ok, err) = emit_shared_library(str(ir.gen.llvm_ir), transitive, exports, lib_path);
    assert ok , f"emit_shared_library failed: {err}";

    layout_dict = json.loads(json.dumps(native_layout_to_dict(layout)));
    result = (lib_path, layout_dict, tmp_dir);
    _ARTIFACT_MEMO.append(result);
    return result;
}

class JacStrABI(ctypes.Structure) {
    # Register view of a by-value JacStr {root, data, len} return. LLVM
    # lowers the aggregate return into scalar return registers; a 16-byte
    # two-pointer struct restype makes libffi read the first two of them,
    # which yields root and data. len rides in the third return register,
    # unreachable through libffi, but Jac string payloads are always
    # NUL-terminated at len so a bounded read is recovered from data.
    has _fields_: list[tuple[str, type]] = [
        ("root", ctypes.c_void_p),
        ("data", ctypes.c_void_p)
    ];
}

"""Descriptor-ABI wrapper for layout-described functions: the by-value JacStr
descriptor param ('jacstr3'/'jacstr2' in the exported layout) is decomposed by
LLVM into scalar register slots, so each such param must be declared as
(root, data, len) scalars in the CFUNCTYPE -- declaring one slot and passing
three routes the extras through the variadic (stack) area on arm64 and the
callee reads garbage registers. str args build their backing storage via
jac_str_new (the sealed dylib exports that spelling; dlsym does not resolve
the __jac_str_new alias); return values marshal through the library's
marshal_value so struct/tuple results behave exactly as with
wrap_native_function."""
def wrap_native_sfunc(
    eng: object,
    func_layout: object,
    ct_classes: dict,
    enum_maps: dict,
    py_classes: dict,
    layout: object = None
) -> object {
    import from jaclang.jac0core.native_marshal { LLVM_TO_CTYPES, marshal_value }
    addr = eng.get_function_address(func_layout.name);
    assert addr != 0 , f"Function '{func_layout.name}' not found in dylib";
    param_types = func_layout.param_types;
    real_args: list = [];
    for pt in param_types {
        if pt == "jacstr3" {
            real_args.extend([ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64]);
        } elif pt == "jacstr2" {
            real_args.extend([ctypes.c_void_p, ctypes.c_int64]);
        } else {
            ct = LLVM_TO_CTYPES.get(pt);
            real_args.append(ct if ct is not None else ctypes.c_void_p);
        }
    }
    ret_type = func_layout.ret_type;
    if ret_type in ("jacstr3", "jacstr2") {
        real_res = JacStrABI;
    } else {
        real_res = LLVM_TO_CTYPES.get(ret_type);
        if real_res is None and ret_type != "void" {
            real_res = ctypes.c_void_p;
        }
    }
    raw = ctypes.CFUNCTYPE(real_res, *real_args)(addr);
    sn_addr = 0;
    for sn in ("jac_str_new", "__jac_str_new") {
        try {
            sn_addr = eng.get_function_address(sn);
        } except Exception {
            sn_addr = 0;
        }
        if sn_addr {
            break;
        }
    }
    mkstr = (
        ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64)(sn_addr)
            if sn_addr
            else None
    );
    def _call(*args: any) -> any {
        c_args: list = [];
        for (a, pt) in zip(args, param_types) {
            if pt in ("jacstr3", "jacstr2") and isinstance(a, (str, bytes)) {
                assert mkstr is not None , "jac_str_new not found in dylib";
                b = a.encode("utf-8") if isinstance(a, str) else a;
                p = mkstr(b, len(b));
                if pt == "jacstr3" {
                    c_args.extend([p, p, len(b)]);
                } else {
                    c_args.extend([p, len(b)]);
                }
            } elif pt == "i8*" and isinstance(a, str) {
                b = a.encode("utf-8");
                assert mkstr is not None , "jac_str_new not found in dylib";
                c_args.append(ctypes.cast(mkstr(b, len(b)), ctypes.c_char_p));
            } else {
                c_args.append(a);
            }
        }
        r = raw(*c_args);
        if real_res is JacStrABI {
            if not r.data {
                return b"";
            }
            return ctypes.string_at(r.data);
        }
        return marshal_value(
            r,
            ret_type,
            ct_classes,
            enum_maps,
            py_classes,
            func_layout=func_layout,
            layout=layout,
            view_memo={}
        );
    }
    return _call;
}

def _bind_tokenize_full -> any {
    (lib_path, layout_dict, _keep) = _build_artifact();
    eng = DylibEngine(lib_path);
    eng.initialize();
    layout = layout_from_dict(layout_dict);
    ns = bytecode_lexer.__dict__;
    cc = build_ctypes_classes(layout);
    em = build_enum_maps(layout, ns);
    pc: dict = {};
    for sn in layout.structs {
        if ns.get(sn) is not None {
            pc[sn] = ns[sn];
        }
    }
    fl = layout.functions.get("tokenize_full");
    assert fl is not None;
    fn = wrap_native_sfunc(eng, fl, cc, em, pc, layout=layout);
    assert fn is not None , "wrap_native_sfunc returned None";
    fn.__jac_engine__ = eng;
    return fn;
}

glob SOURCES: list[str] = [
         "x = 1;",
         "def add(a: int, b: int) -> int { return a + b; }",
         "obj Point { has x: float = 0.0, y: float = 0.0; }",
         "with entry { print(f\"hi {1 + 2} there\"); }",
         "# comment line\nglob X = [1, 2, 3];  # trailing\n",
         "s = \"café üñí\";  # unicode bytes\n",
         "node N { has val: int = 0; } edge E {} walker W { can go with N entry; }"
     ];

test "sealed dylib lexer binds without llvm" {
    fn = _bind_tokenize_full();
    (tokens, comments, diags, err_count) = fn("x = 1;", "probe.jac");
    assert err_count == 0;
    assert len(tokens) >= 4;
}

test "sealed dylib lexer matches bytecode lexer token for token" {
    fn = _bind_tokenize_full();
    for src in SOURCES {
        (na_toks, na_comments, na_diags, na_errs) = fn(src, "parity.jac");
        (py_toks, py_comments, py_diags, py_errs) = bytecode_lexer.tokenize_full(
            src, "parity.jac"
        );
        assert na_errs == py_errs , f"error count diverged for {src!r}";
        assert len(na_toks) == len(py_toks) , (
            f"token count diverged for {src!r}: {len(na_toks)} vs {len(py_toks)}"
        );
        for i in range(len(py_toks)) {
            nt = na_toks[i];
            pt = py_toks[i];
            assert nt.kind == pt.kind , f"{src!r}[{i}]: {nt.kind} != {pt.kind}";
            assert nt.value == pt.value , (
                f"{src!r}[{i}]: {nt.value!r} != {pt.value!r}"
            );
            assert nt.loc.pos_start == pt.loc.pos_start;
            assert nt.loc.pos_end == pt.loc.pos_end;
            assert nt.loc.line == pt.loc.line;
            assert nt.loc.col_start == pt.loc.col_start;
        }
        assert len(na_comments) == len(py_comments);
        assert len(na_diags) == len(py_diags);
    }
}

test "sealed scan self-check keeps lexer diagnostics intact" {
    # The dylib-level diag marshal drops warnings (pre-existing on main;
    # exposed once the descriptor-ABI marshal let the sealed lexer bind).
    # frontend._native_scan self-checks at bind time and falls back to the
    # bytecode lexer when diagnostics do not survive, so W0100-class
    # warnings never silently disappear from sealed builds.
    import from jaclang.jac0core.parser.frontend { _native_scan, parse }
    _scan = _native_scan();
    if _scan is not None {
        (_t, _c, _d, _e) = _scan('x = "\\q";', "selfcheck.jac");
        assert len(_d) == 1 and _d[0].code_str == "W0100" , (
            "sealed scan bound without surviving diagnostics"
        );
    }
    (py_toks, py_comments, py_diags, py_errs) = bytecode_lexer.tokenize_full(
        'with entry { x = "press \\q now"; }', "diagprobe.jac"
    );
    assert len(py_diags) == 1 and py_diags[0].code_str == "W0100";
}

test "sealed manifest round trip resolves the artifact" {
    import hashlib;
    import from jaclang.jac0core.sealed { load_image }
    (lib_path, layout_dict, tmp_dir) = _build_artifact();

    pkg_root = Path(tmp_dir) / "pkgroot";
    pre = pkg_root / "_precompiled";
    nat = pre / "native" / "test-triple";
    nat.mkdir(parents=True, exist_ok=True);
    import shutil;
    staged_lib = nat / os.path.basename(lib_path);
    shutil.copyfile(lib_path, str(staged_lib));
    staged_layout = nat / "lexer.layout.json";
    staged_layout.write_text(json.dumps(layout_dict), encoding="utf-8");

    import sys;
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    import from jaclang.jac0core.jir { FORMAT_VERSION }
    manifest = {
        "format": 4,
        "package": "jaclang",
        "python_tag": pyver,
        "jir_format_version": FORMAT_VERSION,
        "jaclang_version": "0.0.0-test",
        "modules": {},
        "native_artifacts": {
            "jaclang.jac0core.parser.lexer": {
                "lib": staged_lib.relative_to(pre).as_posix(),
                "layout": staged_layout.relative_to(pre).as_posix(),
                "triple": "test-triple",
                "lib_sha256": hashlib.sha256(staged_lib.read_bytes()).hexdigest(),
                "layout_sha256": hashlib.sha256(staged_layout.read_bytes()).hexdigest()
            }
        }
    };
    (pre / "MANIFEST.json").write_text(
        json.dumps(manifest, indent=1), encoding="utf-8"
    );

    image = load_image(str(pre));
    assert image is not None , "format-4 manifest failed to load";
    found = image.native_artifact("jaclang.jac0core.parser.lexer");
    assert found is not None , "artifact did not resolve";
    (found_lib, found_layout) = found;
    assert os.path.samefile(found_lib, str(staged_lib));

    eng = DylibEngine(found_lib);
    eng.initialize();
    layout = layout_from_dict(found_layout);
    assert "tokenize_full" in layout.functions;

    # Tampering must fail closed. Tamper a fresh staged copy, never the one
    # dlopen'd above: truncating a mapped ELF in place drops even the COW'd
    # pages holding glibc's relocated .dynamic entries, and the next dlopen
    # in this process would segfault walking the stale soname (glibc
    # _dl_map_object, dl-load.c).
    nat2 = pre / "native" / "tamper-triple";
    nat2.mkdir(parents=True, exist_ok=True);
    tampered_lib = nat2 / os.path.basename(lib_path);
    shutil.copyfile(lib_path, str(tampered_lib));
    tampered_layout = nat2 / "lexer.layout.json";
    shutil.copyfile(str(staged_layout), str(tampered_layout));
    manifest["native_artifacts"]["jaclang.jac0core.parser.lexer"] = {
        "lib": tampered_lib.relative_to(pre).as_posix(),
        "layout": tampered_layout.relative_to(pre).as_posix(),
        "triple": "tamper-triple",
        "lib_sha256": hashlib.sha256(tampered_lib.read_bytes()).hexdigest(),
        "layout_sha256": hashlib.sha256(tampered_layout.read_bytes()).hexdigest()
    };
    (pre / "MANIFEST.json").write_text(
        json.dumps(manifest, indent=1), encoding="utf-8"
    );
    tampered_lib.write_bytes(tampered_lib.read_bytes() + b"x");
    image2 = load_image(str(pre));
    assert image2 is not None , "restaged manifest failed to load";
    assert image2.native_artifact("jaclang.jac0core.parser.lexer") is None , (
        "tampered artifact must not resolve"
    );
}

test "parse() binds the sealed native lexer through the registered image" {
    import hashlib;
    import shutil;
    import sys;
    import from jaclang.jac0core.sealed { register_image }
    import from jaclang.jac0core.jir { FORMAT_VERSION }
    import jaclang.jac0core.parser.frontend as rd_parser;

    (lib_path, layout_dict, tmp_dir) = _build_artifact();
    pkg_root = Path(tmp_dir) / "bindroot";
    pre = pkg_root / "_precompiled";
    nat = pre / "native" / "test-triple";
    nat.mkdir(parents=True, exist_ok=True);
    staged_lib = nat / os.path.basename(lib_path);
    shutil.copyfile(lib_path, str(staged_lib));
    staged_layout = nat / "lexer.layout.json";
    staged_layout.write_text(json.dumps(layout_dict), encoding="utf-8");
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    manifest = {
        "format": 4,
        "package": "jaclang-native-bind-test",
        "python_tag": pyver,
        "jir_format_version": FORMAT_VERSION,
        "jaclang_version": "0.0.0-test",
        "modules": {},
        "native_artifacts": {
            "jaclang.jac0core.parser.lexer": {
                "lib": staged_lib.relative_to(pre).as_posix(),
                "layout": staged_layout.relative_to(pre).as_posix(),
                "triple": "test-triple",
                "lib_sha256": hashlib.sha256(staged_lib.read_bytes()).hexdigest(),
                "layout_sha256": hashlib.sha256(staged_layout.read_bytes()).hexdigest()
            }
        }
    };
    (pre / "MANIFEST.json").write_text(
        json.dumps(manifest, indent=1), encoding="utf-8"
    );
    image = register_image(str(pre));
    assert image is not None;

    rd_parser._NATIVE_SCAN_MEMO.clear();
    try {
        scan = rd_parser._native_scan();
        assert scan is not None , (
            "parse()-side bind must resolve the registered sealed artifact"
        );
        (mod, had_err) = rd_parser.parse(
            "with entry { print('sealed'); }", "sealed_bind_probe.jac"
        );
        assert not had_err;
        assert mod is not None;
    } finally {
        rd_parser._NATIVE_SCAN_MEMO.clear();
    }
}
