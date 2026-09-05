"""Compile-options identity and boundary tests (#7871 workstream G).

CompileOptions is the single authority for codegen-affecting build options:
env vars are read once at options construction, the codegen fingerprint is
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
    base: dict = {
        "na_gc_mode": "cycles",
        "nogc_enforce_all": False,
        "nogc_cli_target": "",
        "nogc_enforce_modules": [],
        "nogc_grandfathered": [],
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

test "every codegen option flip changes the fingerprint" {
    base_fp = _pinned_opts().codegen_fingerprint();
    flips: list = [
        _pinned_opts(na_gc_mode="none"),
        _pinned_opts(na_gc_mode="rc"),
        _pinned_opts(nogc_enforce_all=True),
        _pinned_opts(nogc_cli_target="mainmod"),
        _pinned_opts(nogc_enforce_modules=["svc*"]),
        _pinned_opts(nogc_grandfathered=["legacy*"]),
        _pinned_opts(rc_debug_codegen=True),
        _pinned_opts(native_target="wasm32-unknown-unknown"),
        _pinned_opts(native_debug=True),
        _pinned_opts(opt_level=0)
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
        na_gc_mode="rc",
        rc_debug_codegen=True,
        native_target="x86_64-unknown-linux-gnu",
        native_debug=True,
        opt_level=1,
        nogc_enforce_modules=["svc*"],
        nogc_grandfathered=["legacy*"]
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
    other = _pinned_opts(na_gc_mode="none").codegen_fingerprint();
    got = link_fingerprint_mismatches(
        [("a.jac", current), ("b.jac", other), ("c.jac", "")], current
    );
    assert got == ["b.jac", "c.jac"];
    assert link_fingerprint_mismatches([("a.jac", current)], current) == [];
}

test "env overrides enter the options object at construction" {
    saved = os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
    try {
        assert CompileOptions().rc_debug_codegen == False;
        os.environ["JAC_RC_DEBUG_CODEGEN"] = "1";
        assert CompileOptions().rc_debug_codegen == True;
        assert CompileOptions(rc_debug_codegen=False).rc_debug_codegen == False;
    } finally {
        if saved is None {
            os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
        } else {
            os.environ["JAC_RC_DEBUG_CODEGEN"] = saved;
        }
    }
}

test "JIR module key follows analysis env flags, not native-only codegen flags" {
    saved_rc = os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
    saved_tgt = os.environ.pop("JAC_NATIVE_TARGET", None);
    try {
        with tempfile.TemporaryDirectory() as tmp {
            src = os.path.join(tmp, "modkey_probe.jac");
            with open(src, "w") as f {
                f.write("with entry { print(1); }\n");
            }
            base_key = compute_module_key(src);
            assert base_key == compute_module_key(src);
            os.environ["JAC_RC_DEBUG_CODEGEN"] = "1";
            rc_key = compute_module_key(src);
            os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
            os.environ["JAC_NATIVE_TARGET"] = "wasm32-unknown-unknown";
            tgt_key = compute_module_key(src);
            os.environ.pop("JAC_NATIVE_TARGET", None);
            assert rc_key == base_key , (
                "JAC_RC_DEBUG_CODEGEN is a native-only codegen knob and must "
                "not change a bytecode module key"
            );
            assert tgt_key != base_key , "JAC_NATIVE_TARGET flip kept the key";
            assert compute_module_key(src) == base_key;
        }
    } finally {
        if saved_rc is not None {
            os.environ["JAC_RC_DEBUG_CODEGEN"] = saved_rc;
        }
        if saved_tgt is not None {
            os.environ["JAC_NATIVE_TARGET"] = saved_tgt;
        }
    }
}

test "effective fingerprint tracks the process env" {
    saved = os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
    try {
        base = effective_codegen_fingerprint();
        os.environ["JAC_RC_DEBUG_CODEGEN"] = "1";
        assert effective_codegen_fingerprint() != base;
    } finally {
        if saved is None {
            os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
        } else {
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

test "no positional intrinsic name matching inside _codegen_call" {
    import jaclang;
    calls_impl = os.path.join(
        os.path.dirname(os.path.abspath(jaclang.__file__)),
        "compiler",
        "backends",
        "native",
        "na_ir_gen",
        "calls.impl.jac"
    );
    assert os.path.isfile(calls_impl) , f"calls impl missing: {calls_impl}";
    with open(calls_impl, "r", encoding="utf-8") as f {
        source = f.read();
    }
    assert "RC_INTRINSIC_NAMES" not in source , (
        "the RC intrinsic pre-classification name set must stay deleted; "
        "INTRINSIC_REGISTRY is the sole authority"
    );
    marker = "impl NaIRGenCalls._codegen_call(";
    start = source.find(marker);
    assert start >= 0 , "_codegen_call impl not found";
    nxt = source.find("\nimpl ", start + len(marker));
    block = source[start:nxt] if nxt >= 0 else source[start:];
    assert block.count("INTRINSIC_REGISTRY.get(") == 1 , (
        "_codegen_call must consult the intrinsic registry through exactly "
        "one lookup"
    );
    cmp_pats = [
        re.compile(r"(==|!=|\bnot\s+in\b|\bin\b)\s*\(?\s*[\"']__"),
        re.compile(r"[\"']__\w+[\"']\s*(==|!=|\bnot\s+in\b|\bin\b)")
    ];
    offenders: list[str] = [];
    for (lineno, line) in enumerate(block.splitlines(), 1) {
        for pat in cmp_pats {
            if pat.search(line) {
                offenders.append(f"_codegen_call+{lineno}: {line.strip()}");
            }
        }
    }
    assert not offenders , (
        "string comparison against a reserved __ intrinsic name inside "
        "_codegen_call (intrinsics must dispatch through "
        "INTRINSIC_REGISTRY):\n"
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

test "native type identity never reads walk-time registration maps" {
    import jaclang;
    native_dir = os.path.join(
        os.path.dirname(os.path.abspath(jaclang.__file__)),
        "compiler",
        "backends",
        "native"
    );
    assert os.path.isdir(native_dir) , f"native dir missing: {native_dir}";
    impl_dir = os.path.join(native_dir, "na_ir_gen");
    dead_tokens = ["_try_resolve_field_type"];
    write_pat = re.compile(r"self\.type_map\s*\[[^\]]*\]\s*=");
    # `struct_field_opaque` is a live name again, and it means the opposite of
    # what it meant when this test banned it outright. The old table was a
    # `set[str]` of fields the constructor, the defaults loop and the arena
    # skipped without saying so -- the silent i8* rescue #7871 deleted. The
    # table now maps field -> refusal reason and exists so that
    # `_refuse_opaque_field` can raise E5092 at every read, write and
    # constructor keyword that names an erased slot.
    #
    # Banning the name would only push the mechanism to a synonym, so what is
    # pinned instead is the property the ban was protecting: the table stays
    # confined to the declaration and to the one impl that erases and refuses,
    # so no third site can quietly consume an erased slot. The behavioural half
    # -- that a touch really does refuse and demote -- is in
    # `test_native_walk_order.jac`.
    opaque_ok = [
        os.path.join("na_ir_gen", "state.jac"),
        os.path.join("na_ir_gen", "objects.impl.jac")
    ];
    offenders: list[str] = [];
    for (dirpath, _dirs, files) in os.walk(native_dir) {
        for fname in files {
            if not fname.endswith(".jac") {
                continue;
            }
            fpath = os.path.join(dirpath, fname);
            rel = os.path.relpath(fpath, native_dir);
            with open(fpath, "r", encoding="utf-8", errors="replace") as f {
                lines: list[str] = f.readlines();
                for (lineno, line) in enumerate(lines, 1) {
                    for token in dead_tokens {
                        if token in line {
                            offenders.append(f"{rel}:{lineno}: {line.strip()}");
                        }
                    }
                    if "struct_field_opaque" in line and rel not in opaque_ok {
                        offenders.append(f"{rel}:{lineno}: {line.strip()}");
                    }
                    if write_pat.search(line)
                        and rel != os.path.join("na_ir_gen", "core.impl.jac") {
                        offenders.append(f"{rel}:{lineno}: {line.strip()}");
                    }
                }
            }
        }
    }
    assert not offenders , (
        "walk-time type registration found in the native pass (type identity "
        "and layout must resolve through the layout authority; type_map is a "
        "static primitive table seeded once in postinit; an erased-field table "
        "is only honest where it is refused):\n"
        + "\n".join(offenders)
    );
    objects_impl = os.path.join(impl_dir, "objects.impl.jac");
    with open(objects_impl, "r", encoding="utf-8") as f {
        objects_src = f.read();
    }
    refuse_marker = "impl NaIRGenObjects._refuse_opaque_field(";
    r_start = objects_src.find(refuse_marker);
    assert r_start >= 0 , (
        "_refuse_opaque_field impl not found; the erased-field table has no "
        "refusal to pair with and the silent i8* rescue is back"
    );
    r_nxt = objects_src.find("\nimpl ", r_start + len(refuse_marker));
    refuse_block = objects_src[r_start:r_nxt] if r_nxt >= 0 else objects_src[r_start:];
    assert "E5092" in refuse_block , (
        "the reader of struct_field_opaque must refuse loudly (E5092); an "
        "erased slot answered from its own uninitialised bits is the "
        "miscompile this gate exists to prevent"
    );
    enums_impl = os.path.join(impl_dir, "enums.impl.jac");
    with open(enums_impl, "r", encoding="utf-8") as f {
        enums_src = f.read();
    }
    assert "type_map" not in enums_src , (
        "enum codegen must not register into type_map; enum identity comes "
        "from the layout authority (is_enum_class_type / enum_decl_of)"
    );
    types_impl = os.path.join(impl_dir, "types.impl.jac");
    with open(types_impl, "r", encoding="utf-8") as f {
        types_src = f.read();
    }
    marker = "impl NaIRGenTypes._lower_class_type(";
    start = types_src.find(marker);
    assert start >= 0 , "_lower_class_type impl not found";
    nxt = types_src.find("\nimpl ", start + len(marker));
    block = types_src[start:nxt] if nxt >= 0 else types_src[start:];
    assert block.count("_ensure_enum_lowered") == 1 , (
        "_lower_class_type must resolve enum identity through exactly one "
        "authority-backed path"
    );
    assert "_is_enum_class_type" not in types_src , (
        "the enum predicate lives in the layout authority module "
        "(layout_pass.is_enum_class_type), not in the native pass"
    );
}

test "container lifecycle emission lives only in the shared emitters" {
    import jaclang;
    impl_dir = os.path.join(
        os.path.dirname(os.path.abspath(jaclang.__file__)),
        "compiler",
        "backends",
        "native",
        "na_ir_gen"
    );
    per_container = [
        "dicts.impl.jac",
        "sets.impl.jac",
        "lists.impl.jac",
        "hash_core.impl.jac",
        "tuples.impl.jac",
        "comprehensions.impl.jac"
    ];
    forbidden = [
        "__rc_trace_",
        "_register_trace_pair",
        "_require_trace_fn",
        "rc_collecting",
        "_emit_rc_destructor_preamble",
        "_emit_release_header_free",
        "_emit_container_trace_fn"
    ];
    offenders: list[str] = [];
    for fname in per_container {
        fpath = os.path.join(impl_dir, fname);
        assert os.path.isfile(fpath) , f"expected impl file missing: {fpath}";
        with open(fpath, "r", encoding="utf-8") as f {
            lines: list[str] = f.readlines();
            for (lineno, line) in enumerate(lines, 1) {
                for token in forbidden {
                    if token in line {
                        offenders.append(f"{fname}:{lineno}: {line.strip()}");
                    }
                }
            }
        }
    }
    assert not offenders , (
        "container lifecycle machinery found in a per-container emitter file "
        "(trace registration, the rc_collecting guard, and release/drop "
        "emission live only in the shared slot-iteration emitters):\n"
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

test "one static-string constructor" {
    import jaclang;
    native_dir = os.path.join(
        os.path.dirname(os.path.abspath(jaclang.__file__)),
        "compiler",
        "backends",
        "native"
    );
    marker = "LiteralStructType([i64,i64,arr_type])";
    hits: list[str] = [];
    for (dirpath, _dirs, files) in os.walk(native_dir) {
        for fname in files {
            if not fname.endswith(".jac") {
                continue;
            }
            fpath = os.path.join(dirpath, fname);
            with open(fpath, "r", encoding="utf-8", errors="replace") as f {
                lines: list[str] = f.readlines();
                for (lineno, line) in enumerate(lines, 1) {
                    if marker in line.replace(" ", "") {
                        rel = os.path.relpath(fpath, native_dir);
                        hits.append(f"{rel}:{lineno}");
                    }
                }
            }
        }
    }
    assert len(hits) == 1 , (
        "the static-string struct {i64 sentinel, i64 tagged_len, [N x i8]} "
        "must be built by exactly one constructor "
        "(_static_str_struct_const in builtins.impl.jac); found: "
        + ", ".join(hits)
    );
    assert hits[0].startswith(os.path.join("na_ir_gen", "builtins.impl.jac")) , f"static-string constructor moved: {hits[
        0
    ]}";
}

test "set shares the dict hash core with no linear-scan sibling" {
    import jaclang;
    native_dir = os.path.join(
        os.path.dirname(os.path.abspath(jaclang.__file__)),
        "compiler",
        "backends",
        "native"
    );
    impl_dir = os.path.join(native_dir, "na_ir_gen");
    core_callers: list[str] = [];
    for (dirpath, _dirs, files) in os.walk(native_dir) {
        for fname in files {
            if not fname.endswith(".jac") {
                continue;
            }
            fpath = os.path.join(dirpath, fname);
            with open(fpath, "r", encoding="utf-8", errors="replace") as f {
                src = f.read();
            }
            rel = os.path.relpath(fpath, native_dir);
            assert "_emit_linear_search_loop" not in src , (
                f"linear-scan container search survives in {rel}"
            );
            if "self._emit_hash_core_helpers(" in src {
                core_callers.append(os.path.basename(fpath));
            }
        }
    }
    assert sorted(core_callers) == ["dicts.impl.jac", "sets.impl.jac"] , (
        "the hash core must be consumed by exactly the dict and set emitters; "
        f"found callers: {sorted(core_callers)}"
    );
    with open(os.path.join(impl_dir, "sets.impl.jac"), "r", encoding="utf-8") as f {
        sets_src = f.read();
    }
    for token in ["TOMBSTONE", "probe", "rehash", "strcmp", "FNV"] {
        assert token not in sets_src , (
            f"hash-table machinery ('{token}') found in sets.impl.jac; the "
            "set emitter must be (layout facts + hash core) only"
        );
    }
}

test "hetero container band-aids are deleted; one element-storage authority" {
    import jaclang;
    pkg_root = os.path.dirname(os.path.abspath(jaclang.__file__));
    banned = [
        "_list_box_ptr_into_i64",
        "_is_container_element_store",
        "list_init_box",
        "list_set_box"
    ];
    offenders: list[str] = [];
    authority_defs: list[str] = [];
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
                    if "impl NaIRGenTypes._elem_storage_llvm(" in line {
                        authority_defs.append(os.path.relpath(fpath, pkg_root));
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
    assert authority_defs
        == [
            os.path.join(
                "compiler", "backends", "native", "na_ir_gen", "types.impl.jac"
            )
        ] , (
        "container element storage must be decided by exactly one authority "
        f"(_elem_storage_llvm in types.impl.jac); found: {authority_defs}"
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
    unwrap_msg = "value is None where a value is required";
    offenders: list[str] = [];
    unwrap_sites: list[str] = [];
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
                    if unwrap_msg in line {
                        unwrap_sites.append(f"{rel}:{lineno}");
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
    assert len(unwrap_sites) == 1
        and unwrap_sites[0].startswith(os.path.join("na_ir_gen", "types.impl.jac")) , (
        "optional unwrap must be emitted by exactly one site "
        f"(_coerce_type_inner in types.impl.jac); found: {unwrap_sites}"
    );
}
