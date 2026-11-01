"""Compile-options identity and boundary tests (#7871 workstream G).

CompileOptions is the single authority for codegen-affecting build options:
project settings are read once at options construction, the codegen fingerprint is
part of artifact identity (folded into the JIR module key), and no compiler
pass reads os.environ directly (source-scan gate below).
"""

import os;
import re;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options {
    CompileOptions,
    effective_codegen_fingerprint,
    link_fingerprint_mismatches
}
import from jaclang.compiler.driver.jir { compute_module_key }


def _pinned_opts(**overrides: any) -> CompileOptions {
    base: dict[str, any] = {
        "memory_profile": "managed",
        "nogc_enforce_all": False,
        "memory_enforce": [],
        "memory_exempt": [],
        "rc_debug_codegen": False,
        "native_target": "",
        "native_debug": False,
        "opt_level": 2
    };
    base.update(overrides);
    return CompileOptions(**base);
}


test "identical codegen options produce an identical fingerprint" {
    assert _pinned_opts().codegen_fingerprint() == _pinned_opts().codegen_fingerprint();
}

test "forced server compilation retains Python standard-library imports" {
    import from jaclang.compiler.driver.program { JacProgram }
    program = JacProgram();
    module = program.compile(
        file_path="forced_server_socket.jac",
        use_str="import socket;\n"
            + "def bind_local { sock = socket.socket(); "
            + "sock.bind(('127.0.0.1', 0)); sock.close(); }\n",
        options=CompileOptions(
            default_codespace="native", force_codespace="server", need_full_ast=True
        )
    );
    assert not program.errors_had , str(program.errors_had);
    assert not module.in_native_context();
    assert module.gen.py_bytecode is not None;
}

test "every codegen option flip changes the fingerprint" {
    base_fp = _pinned_opts().codegen_fingerprint();
    flips: list[any] = [
        _pinned_opts(memory_profile="nogc"),
        _pinned_opts(memory_profile="rc"),
        _pinned_opts(nogc_enforce_all=True),
        _pinned_opts(memory_enforce=["svc*"]),
        _pinned_opts(memory_exempt=["legacy*"]),
        _pinned_opts(rc_debug_codegen=True),
        _pinned_opts(native_target="wasm32-unknown-unknown"),
        _pinned_opts(native_debug=True),
        _pinned_opts(opt_level=0),
        _pinned_opts(native_threads=7),
        _pinned_opts(client_source_root="/apps/web")
    ];
    seen: set = {base_fp};
    for flipped in flips {
        fp = flipped.codegen_fingerprint();
        assert fp != base_fp , (
            f"flip did not change fingerprint: {flipped.codegen_identity()}"
        );
        seen.add(fp);
    }
    assert len(seen) == len(flips) + 1 , "fingerprint collision between flips";
}

test "client layout survives a kernel request and separates dependency caches" {
    import from jaclang.project.kernel_call { KERNEL_OPTION_FIELDS, options_record }
    first = _pinned_opts(client_source_root="/apps/first");
    second = _pinned_opts(client_source_root="/apps/second");
    record = options_record(first);
    assert record["client_source_root"] == first.client_source_root;
    restored = CompileOptions(**record);
    assert restored.client_source_root == first.client_source_root;
    assert restored.codegen_fingerprint() == first.codegen_fingerprint();
    assert set(record) == set(KERNEL_OPTION_FIELDS);
    assert first.dependency_projection("/shared/Card.jac")
        != second.dependency_projection("/shared/Card.jac");
    assert first.unit_codegen_identity("/shared/Card.jac")
        == second.unit_codegen_identity("/shared/Card.jac");
}

test "diagnostic-only options do not enter the fingerprint" {
    base_fp = _pinned_opts().codegen_fingerprint();
    diag = _pinned_opts(
        dump_ir_path="/tmp/out.ll",
        debug_ir=True,
        rc_stats=True,
        nogc_debug=True,
        na_debug=True
    );
    assert diag.codegen_fingerprint() == base_fp;
    # Strict dependency checking only changes diagnostics, so it keys the
    # diagnostic profile, not the module's cache file.
    strict = _pinned_opts();
    strict.strict_dependencies = True;
    assert strict.module_projection() == _pinned_opts().module_projection();
    assert strict.analysis_identity() != _pinned_opts().analysis_identity();
}


test "JAC_NA_DEBUG enters the options object at construction" {
    saved = os.environ.pop("JAC_NA_DEBUG", None);
    try {
        assert CompileOptions().na_debug == False;
        os.environ["JAC_NA_DEBUG"] = "1";
        assert CompileOptions().na_debug == True;
        assert CompileOptions(na_debug=False).na_debug == False;
        assert CompileOptions().clone_for_native_import().na_debug == True;
        os.environ["JAC_NA_DEBUG"] = "0";
        assert CompileOptions().na_debug == False;
    } finally {
        if saved is None {
            os.environ.pop("JAC_NA_DEBUG", None);
        } else {
            os.environ["JAC_NA_DEBUG"] = saved;
        }
    }
}

test "clone_for_native_import carries the full codegen identity" {
    parent = _pinned_opts(
        memory_profile="rc",
        rc_debug_codegen=True,
        native_target="x86_64-unknown-linux-gnu",
        native_debug=True,
        opt_level=1,
        memory_enforce=["svc*"],
        memory_exempt=["legacy*"]
    );
    child = parent.clone_for_native_import();
    assert child.skip_native_engine and child.aot_mode;
    parent_id = parent.codegen_identity();
    child_id = child.codegen_identity();
    parent_tail = parent_id.split("nogc_mods=")[1];
    child_tail = child_id.split("nogc_mods=")[1];
    assert parent_tail == child_tail;
    assert parent_id.split(";")[0] == child_id.split(";")[0];
}

test "link_fingerprint_mismatches names every non-matching participant" {
    current = _pinned_opts().codegen_fingerprint();
    other = _pinned_opts(memory_profile="nogc").codegen_fingerprint();
    got = link_fingerprint_mismatches(
        [("a.jac", current), ("b.jac", other), ("c.jac", "")], current
    );
    assert got == ["b.jac", "c.jac"];
    assert link_fingerprint_mismatches([("a.jac", current)], current) == [];
}

test "native debug enters the options object from the option, not the environment" {
    assert CompileOptions().rc_debug_codegen == False;
    assert CompileOptions(native_debug=True).rc_debug_codegen == True;
    assert CompileOptions(native_debug=True, rc_debug_codegen=False).rc_debug_codegen
        == False;
    assert CompileOptions(memory_profile="nogc").na_gc_mode == "none";
    assert CompileOptions(memory_profile="nogc").nogc_enforce_all == True;
    assert CompileOptions(memory_profile="rc").na_gc_mode == "rc";
    assert CompileOptions().na_gc_mode == "cycles";
}

test "JIR module key follows the target override, not native-only codegen flags" {
    import from jaclang.compiler.driver.compile_options {
        push_native_target,
        pop_native_target
    }
    with tempfile.TemporaryDirectory() as tmp {
        src = os.path.join(tmp, "modkey_probe.jac");
        with open(src, "w") as f {
            f.write("with entry { print(1); }\n");
        }
        base_key = compute_module_key(src);
        assert base_key == compute_module_key(src);
        prev = push_native_target("wasm32-unknown-unknown");
        try {
            tgt_key = compute_module_key(src);
        } finally {
            pop_native_target(prev);
        }
        assert tgt_key != base_key , "native target flip kept the key";
        assert compute_module_key(src) == base_key;
    }
}

test "the codegen fingerprint tracks the native debug option, not the environment" {
    base = CompileOptions().codegen_fingerprint();
    assert CompileOptions(native_debug=True).codegen_fingerprint() != base;
    saved = os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
    try {
        os.environ["JAC_RC_DEBUG_CODEGEN"] = "1";
        assert CompileOptions().codegen_fingerprint() == base , (
            "a compile-time environment variable must not enter the options"
        );
    } finally {
        os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
        if saved is not None {
            os.environ["JAC_RC_DEBUG_CODEGEN"] = saved;
        }
    }
}

test "no compiler pass reads the environment directly" {
    import jaclang;
    passes_dir = os.path.join(
        os.path.dirname(os.path.abspath(jaclang.__file__)), "compiler", "passes"
    );
    assert os.path.isdir(passes_dir) , f"passes dir missing: {passes_dir}";
    patterns = [
        re.compile(r"\.environ"),
        re.compile(r"\bos\.getenv\s*\("),
        re.compile(r"import\s+from\s+os\s*\{[^}]*environ")
    ];
    offenders: list[str] = [];
    for (dirpath, _dirs, files) in os.walk(passes_dir) {
        for fname in files {
            if not (fname.endswith(".jac") or fname.endswith(".py")) {
                continue;
            }
            fpath = os.path.join(dirpath, fname);
            with open(fpath, "r", encoding="utf-8", errors="replace") as f {
                lines: list[str] = f.readlines();
                for (lineno, line) in enumerate(lines, 1) {
                    for pat in patterns {
                        if pat.search(line) {
                            rel = os.path.relpath(fpath, passes_dir);
                            offenders.append(f"{rel}:{lineno}: {line.strip()}");
                        }
                    }
                }
            }
        }
    }
    assert not offenders , (
        "environment reads found under compiler/passes (options must enter "
        "through CompileOptions at the program boundary):\n"
        + "\n".join(offenders)
    );
}

test "no cycle counter or stack validity channel in the type system" {
    import jaclang;
    compiler_dir = os.path.join(
        os.path.dirname(os.path.abspath(jaclang.__file__)), "compiler"
    );
    scan_dirs = [
        os.path.join(compiler_dir, "types"),
        os.path.join(compiler_dir, "passes")
    ];
    tokens = ["_cyclic_resolution_depth", "is_result_valid"];
    offenders: list[str] = [];
    for scan_dir in scan_dirs {
        assert os.path.isdir(scan_dir) , f"scan dir missing: {scan_dir}";
        for (dirpath, _dirs, files) in os.walk(scan_dir) {
            for fname in files {
                if not (fname.endswith(".jac") or fname.endswith(".py")) {
                    continue;
                }
                fpath = os.path.join(dirpath, fname);
                with open(fpath, "r", encoding="utf-8", errors="replace") as f {
                    lines: list[str] = f.readlines();
                    for (lineno, line) in enumerate(lines, 1) {
                        for token in tokens {
                            if token in line {
                                rel = os.path.relpath(fpath, compiler_dir);
                                offenders.append(f"{rel}:{lineno}: {line.strip()}");
                            }
                        }
                    }
                }
            }
        }
    }
    assert not offenders , (
        "cycle-window counter or stack validity channel found (completeness "
        "must travel on the type value via UnknownType.is_incomplete):\n"
        + "\n".join(offenders)
    );
}

test "no numeric header offsets outside the HDR_* constants" {
    import jaclang;
    native_dir = os.path.join(
        os.path.dirname(os.path.abspath(jaclang.__file__)),
        "compiler",
        "backends",
        "native"
    );
    hdr_pat = re.compile(r"Constant\([^,()]*i64[^,()]*,\s*-(8|16|24|32)\)\s*\]");
    offenders: list[str] = [];
    for (dirpath, _dirs, files) in os.walk(native_dir) {
        for fname in files {
            if not fname.endswith(".jac") {
                continue;
            }
            fpath = os.path.join(dirpath, fname);
            with open(fpath, "r", encoding="utf-8", errors="replace") as f {
                lines: list[str] = f.readlines();
                for (lineno, line) in enumerate(lines, 1) {
                    if hdr_pat.search(line) {
                        rel = os.path.relpath(fpath, native_dir);
                        offenders.append(f"{rel}:{lineno}: {line.strip()}");
                    }
                }
            }
        }
    }
    assert not offenders , (
        "numeric RC-header offset used as a gep index (header geometry is "
        "defined once by the HDR_* constants):\n"
        + "\n".join(offenders)
    );
}

test "hetero container band-aids are deleted" {
    import jaclang;
    pkg_root = os.path.dirname(os.path.abspath(jaclang.__file__));
    banned = [
        "_list_box_ptr_into_i64",
        "_is_container_element_store",
        "list_init_box",
        "list_set_box"
    ];
    offenders: list[str] = [];
    for (dirpath, _dirs, files) in os.walk(pkg_root) {
        for fname in files {
            if not fname.endswith(".jac") {
                continue;
            }
            fpath = os.path.join(dirpath, fname);
            with open(fpath, "r", encoding="utf-8", errors="replace") as f {
                lines: list[str] = f.readlines();
                for (lineno, line) in enumerate(lines, 1) {
                    for token in banned {
                        if token in line {
                            rel = os.path.relpath(fpath, pkg_root);
                            offenders.append(f"{rel}:{lineno}: {line.strip()}");
                        }
                    }
                }
            }
        }
    }
    assert not offenders , (
        "a deleted hetero-container band-aid symbol survives (pointers boxed "
        "into integer container slots were replaced by tagged jacval storage):\n"
        + "\n".join(offenders)
    );
}

test "no consumer-site NULL guards on string operands" {
    import jaclang;
    native_dir = os.path.join(
        os.path.dirname(os.path.abspath(jaclang.__file__)),
        "compiler",
        "backends",
        "native"
    );
    assert os.path.isdir(native_dir) , f"native dir missing: {native_dir}";
    banned = [
        "strcmp.lnull",
        "strcmp.rnull",
        "strcmp.anynull",
        "strcmp.lsafe",
        "strcmp.rsafe",
        "tobool.str.null"
    ];
    offenders: list[str] = [];
    for (dirpath, _dirs, files) in os.walk(native_dir) {
        if os.path.sep + "wasm_rt" in dirpath or os.path.sep + "llvm" in dirpath {
            continue;
        }
        for fname in files {
            if not fname.endswith(".jac") {
                continue;
            }
            fpath = os.path.join(dirpath, fname);
            rel = os.path.relpath(fpath, native_dir);
            with open(fpath, "r", encoding="utf-8", errors="replace") as f {
                lines: list[str] = f.readlines();
                for (lineno, line) in enumerate(lines, 1) {
                    for token in banned {
                        if token in line {
                            offenders.append(f"{rel}:{lineno}: {line.strip()}");
                        }
                    }
                }
            }
        }
    }
    assert not offenders , (
        "a consumer-site NULL guard on a string operand survives (nullable "
        "pointers were replaced by tagged JacOptional values; a raw NULL str "
        "is impossible by construction):\n"
        + "\n".join(offenders)
    );
}


test "native import handoff preserves memory policy and generated thread defaults" {
    parent = CompileOptions(
        memory_profile="nogc",
        memory_enforce=["app.*"],
        memory_exempt=["app.legacy"],
        native_threads=7,
        native_link_mode="bitcode",
        native_target="aarch64-unknown-linux-gnu"
    );
    for child in [parent.clone_for_native_import()] {
        assert child.codegen_identity() == parent.codegen_identity();
        assert child.analysis_identity() == parent.analysis_identity();
        assert child.memory_profile == "nogc" and child.nogc_enforce_all;
        assert child.native_threads == 7;
        assert child.native_link_mode == "bitcode";
        assert child.memory_enforce == ["app.*"];
        assert child.memory_exempt == ["app.legacy"];
    }
}

test "native link mode uses project configuration without changing unit codegen" {
    import from unittest.mock { patch }
    import from jaclang.project.config { JacConfig }
    import from jaclang.project.compiler_host { ProjectHost, project_defaults_of }
    cfg = JacConfig.from_toml_str('[native]\nlink_mode = "bitcode"\n');
    with patch.object(
        ProjectHost, "project_defaults", return_value=project_defaults_of(cfg)
    ) {
        configured = CompileOptions();
        explicit = CompileOptions(native_link_mode="objects");
        assert configured.native_link_mode == "bitcode";
        assert explicit.native_link_mode == "objects";
        assert configured.codegen_identity() == explicit.codegen_identity();
    }
}

test "symbol requests preserve their app and native target context" {
    parent = CompileOptions(
        aot_mode=True,
        default_codespace='native',
        target_app='cli',
        entry_point='/project/main.jac',
        project_root='/project',
        native_target='wasm32-unknown-unknown'
    );
    child = parent.for_symbols(need_tree=True);
    assert child is not parent;
    assert child.no_cgen and child.symtab_ir_only and child.need_full_ast;
    assert child.aot_mode and child.default_codespace == 'native';
    assert child.entry_point == parent.entry_point;
    assert child.project_root == parent.project_root;
    assert child.codegen_identity() == parent.codegen_identity();
    assert not parent.no_cgen and not parent.symtab_ir_only;
}

test "native-only policy is retained in dependency and cache identities" {
    ordinary = _pinned_opts(native_require=[]);
    strict = _pinned_opts(native_required=True, native_require=[]);
    scoped = _pinned_opts(native_require=["jaclang.runtime.python.*"]);
    import from jaclang.compiler.driver.program { JacProgram }
    registry = JacProgram().iface_registry();
    for options in (strict, scoped) {
        assert registry.analysis_profile(options)
            != registry.analysis_profile(ordinary);
        assert options.codegen_fingerprint() != ordinary.codegen_fingerprint();
        assert options.analysis_fingerprint() != ordinary.analysis_fingerprint();
        for inherited in (options.for_symbols(), options.clone_for_native_import()) {
            assert inherited.native_required == options.native_required;
            assert inherited.native_require == options.native_require;
        }
    }
    assert scoped.native_required_for(
        "/checkout/jaclang/runtime/python/bindings/module.jac"
    );
    assert not scoped.native_required_for("/checkout/jaclang/runtime/runtime.jac");
}

test "native dependency caches use the running compiler identity" {
    import from unittest.mock { patch }
    import from jaclang.compiler.driver.jir { current_native_stamp }
    options = _pinned_opts();
    with patch(
        "jaclang.compiler.driver.jir.running_compiler_digest", return_value="compiler-a"
    ) {
        first = current_native_stamp(options.codegen_identity(), "").key();
        assert first == current_native_stamp(options.codegen_identity(), "").key();
        assert first
            != current_native_stamp(
                _pinned_opts(native_required=True).codegen_identity(), ""
            ).key();
    }
    with patch(
        "jaclang.compiler.driver.jir.running_compiler_digest", return_value="compiler-b"
    ) {
        assert first != current_native_stamp(options.codegen_identity(), "").key();
    }
}
