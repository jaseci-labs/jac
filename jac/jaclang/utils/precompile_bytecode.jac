import hashlib;
import json;
import marshal;
import os;
import shutil;
import sys;
import zlib;

import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.jac0core { ext_registry }
import from jaclang.jac0core.compiler { patch_co_filenames_bytes }
import from jaclang.jac0core.jir {
    write_precompiled_jir,
    FLAG_PRECOMPILED,
    FLAG_BOOTSTRAP,
    HEADER_SIZE,
    SECTIONS_MAGIC,
    SEC_BYTECODE,
    SEC_DEBUG_SRC,
    FORMAT_VERSION,
    compute_precompile_module_key,
    precompiled_jir_matches_source,
    running_compiler_digest,
    PRECOMPILE_SENTINEL
}
import from jaclang.jac0core.sealed {
    MANIFEST_NAME,
    MANIFEST_FORMAT,
    JIR_FORMAT_VERSION as SEALED_JIR_FORMAT_VERSION,
    PRECOMPILE_SENTINEL as SEALED_SENTINEL,
    _HEADER_SIZE as SEALED_HEADER_SIZE,
    _SECTIONS_MAGIC as SEALED_SECTIONS_MAGIC,
    _SEC_BYTECODE as SEALED_SEC_BYTECODE,
    _SEC_DEBUG_SRC as SEALED_SEC_DEBUG_SRC
}

glob RESULT_NAME: str = "PRECOMPILE_RESULT.json";

def compiler_identity -> str {
    digest = running_compiler_digest();
    if digest.startswith("0:") {
        raise RuntimeError(
            "Precompile aborted: no compiler sources found under the running "
            "jaclang package, so this build cannot state which compiler it is. "
            "Every seeded .jir would then be reusable by any other compiler at "
            "this version -- the #8178 failure mode. Check that jac0core/ and "
            "compiler/ ship with the running jaclang."
        );
    }
    return digest;
}

def find_package_dir(source_dir: str) -> str | None {
    src = Path(source_dir).resolve();
    if not src.is_dir() {
        console.error(f"Error: {source_dir} is not a directory");
        return None;
    }
    excluded: list[str] = [
        "tests",
        "test",
        "scripts",
        "docs",
        ".git",
        ".github",
        "node_modules"
    ];

    for child in sorted(src.iterdir()) {
        if child.is_dir() and child.name not in excluded {
            init_py = child / "__init__.py";
            init_jac = child / "__init__.jac";
            if init_py.is_file() or init_jac.is_file() {
                return str(child);
            }
        }
    }
    return None;
}

def _nested_project_dirs(package_dir: str) -> list[str] {
    pkg = Path(package_dir);
    roots: list[str] = [];
    for toml in pkg.rglob("jac.toml") {
        d = toml.parent;
        if d != pkg {
            roots.append(str(d) + os.sep);
        }
    }
    return roots;
}

def find_jac_files(package_dir: str) -> list[str] {
    result: list[str] = [];
    pkg = Path(package_dir);
    for jac_file in sorted(pkg.rglob("*.jac")) {
        if not jac_file.is_file() {
            continue;
        }
        rel_path = jac_file.relative_to(pkg);
        rel = str(rel_path);

        if any(
            part.startswith(".") or part == "__pycache__" for part in rel_path.parts
        ) {
            continue;
        }

        if (
            ".test." in rel
            or "/test/" in rel
            or "/tests/" in rel
            or rel.startswith("test/")
            or rel.startswith("tests/")
            or rel.startswith(".")
            or ".impl." in jac_file.name
        ) {
            continue;
        }
        result.append(str(jac_file));
    }
    return result;
}

glob _sealable_cache: dict[str, list[str]] = {},
     _placement_cache: dict[str, dict[str, set[str]]] = {};

def sealable_sources(package_dir: str) -> list[str] {
    key = os.path.abspath(package_dir);
    cached = _sealable_cache.get(key);
    if cached is not None {
        return cached;
    }
    boot_prefix = str(Path(package_dir) / "jac0core") + os.sep;
    nested = _nested_project_dirs(package_dir);
    candidates = [
        p
        for p in find_jac_files(package_dir)
        if not p.startswith(boot_prefix) and not any(p.startswith(n) for n in nested)
    ];
    if Path(package_dir).name == "jaclang" {
        import from jaclang.jac0core.placement_facts { toolchain_native_by_policy }
        result = [
            p
            for p in candidates
            if not toolchain_native_by_policy(package_dir, p)
        ];
    } else {
        import from jaclang.jac0core.placement_facts {
            discover_spaces,
            spaces_are_client_only
        }
        import from jaclang.jac0core.program { JacProgram }
        discovery = JacProgram();
        facts = discover_spaces(candidates, discovery);
        _placement_cache[key] = facts;
        if discovery.errors_had {
            console.print(
                f"  Placement discovery hit {len(discovery.errors_had)} "
                "error(s); sealing every candidate so each failure surfaces "
                "per-file instead of being skipped."
            );
            result = candidates;
        } else {
            skipped = [
                p
                for p in candidates
                if spaces_are_client_only(facts[os.path.abspath(p)])
            ];
            result = [
                p
                for p in candidates
                if p not in skipped
            ];
            if skipped {
                names = ", ".join(
                    str(Path(p).relative_to(Path(key))) for p in skipped[:8]
                );
                console.print(
                    f"  Skipping {len(skipped)} client-only module(s): {names}"
                );
            }
        }
        discovery.release_compile_closure();
    }
    _sealable_cache[key] = result;
    return result;
}

def placement_facts_map(package_dir: str) -> dict[str, list[str]] {
    key = os.path.abspath(package_dir);
    sealable_sources(package_dir);
    facts = _placement_cache.get(key);
    if not facts {
        return {};
    }
    out: dict[str, list[str]] = {};
    for (ap, spaces) in facts.items() {
        rel = Path(ap).relative_to(Path(key)).as_posix();
        out[rel] = sorted(spaces);
    }
    return out;
}

def precompile_unit(
    jac_path: str, pkg_root: str, embed_src: bool = False
) -> bytes | None {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from jaclang.jac0core.program { JacProgram }

    compiler = Jac.get_compiler();

    program = JacProgram();
    code = compiler.get_bytecode(full_target=jac_path, target_program=program);
    compiler.internal_program.release_compile_closure();
    program.release_compile_closure();
    if code is None {
        return None;
    }
    patched = patch_co_filenames_bytes(
        marshal.dumps(code), pkg_root, PRECOMPILE_SENTINEL
    );
    extra: dict[int, bytes] | None = None;
    if embed_src {
        extra = {SEC_DEBUG_SRC: zlib.compress(Path(jac_path).read_bytes(), 9)};
    }
    return write_precompiled_jir(
        patched, compute_precompile_module_key(jac_path), FLAG_PRECOMPILED, extra
    );
}

def seal_bootstrap(pkg_dir: Path, out_dir: Path, embed_src: bool) -> int {
    import from jaclang.jac0 {
        compile_jac as jac0_compile,
        discover_impl_files as jac0_impls
    }
    boot_dir = pkg_dir / "jac0core";
    failed = 0;
    if not boot_dir.is_dir() {
        return failed;
    }
    for jac_file in sorted(boot_dir.rglob("*.jac")) {
        if ext_registry.is_annex(str(jac_file)) {
            continue;
        }
        if any(
            part.startswith(".") or part == "__pycache__"
            for part in jac_file.relative_to(boot_dir).parts
        ) {
            continue;
        }
        try {
            impl_paths = jac0_impls(str(jac_file));
            impl_sources: list[tuple[str, str]] = [];
            for impl_path in impl_paths {
                impl_sources.append(
                    (Path(impl_path).read_text(encoding="utf-8"), impl_path)
                );
            }
            py_source = jac0_compile(
                jac_file.read_text(encoding="utf-8"),
                str(jac_file),
                impl_sources=impl_sources or None
            );
            code = compile(py_source, str(jac_file), "exec");
            bc = patch_co_filenames_bytes(
                marshal.dumps(code), str(pkg_dir), PRECOMPILE_SENTINEL
            );
            extra: dict[int, bytes] | None = None;
            if embed_src {
                extra = {SEC_DEBUG_SRC: zlib.compress(jac_file.read_bytes(), 9)};
            }
            jir_rel = jac_file.relative_to(pkg_dir).with_suffix(".jir");
            jir_path = out_dir / jir_rel;
            jir_path.parent.mkdir(parents=True, exist_ok=True);
            jir_path.write_bytes(write_precompiled_jir(bc, "", FLAG_BOOTSTRAP, extra));
        } except Exception as e {
            console.error(f"BOOTSTRAP FAIL: {jac_file.name} - {e}");
            failed += 1;
        }
    }
    return failed;
}

glob NATIVE_SEAL_ROOTS: tuple[str, ...] = (
         "jac0core/unitree.jac",
         "jac0core/passes/annex_pass.jac",
         "jac0core/passes/ast_validation_pass.jac",
         "jac0core/passes/module_codegen_pass.jac",
         "jac0core/passes/semantic_analysis_pass.jac",
         "jac0core/passes/sym_tab_build_pass.jac",
         "jac0core/passes/decl_impl_match_pass.jac",
         "jac0core/passes/uni_pass.jac",
         "jac0core/passes/endpoint_effect_pass.jac",
         "compiler/passes/main/sem_def_match_pass.jac",
         "compiler/passes/main/access_check_pass.jac",
         "compiler/passes/main/jsx_intrinsic_guard_pass.jac",
         "compiler/passes/main/cfg_build_pass.jac",
         "compiler/passes/main/rc_facts_pass.jac",
         "jac0core/passes/jcir_gen_pass.jac",
         "compiler/native_materialize.jac",

     ),
     NATIVE_SEAL_REFUSED_ROOTS: dict[str, str] = {
         "compiler/passes/main/capability_check_pass.jac": (
             "one own seam left (native_capability_violations, the "
             "pass-tier crossing into ModuleCodegenPass.iter_context_stmts) "
             "and it cannot be waived: the seal's abort-stub linkage check "
             "reads the IR that ships and NativeCapabilityCheckPass."
             "transform -- the root's live entry point -- links the stub "
             "directly, so the artifact would abort on its first native "
             "run. Seals when the pass-tier crossing links artifacts "
             "instead of stubbing, or when transform stops calling the "
             "demoted function natively."
         )
     },
     NATIVE_SEAL_CLOSURE: tuple[str, ...] = (
         "jac0core/codegen_ir.jac",
         "jac0core/codeinfo.jac",
         "jac0core/constant.jac",
         "jac0core/diagnostic_utils.jac",
         "jac0core/diagnostics.jac",
         "jac0core/helpers.jac",
         "jac0core/jcir_facts.jac",
         "jac0core/parser/lexer.jac",
         "jac0core/parser/parser.jac",
         "jac0core/parser/tokens.jac",
         "jac0core/passes/annex_pass.jac",
         "jac0core/passes/annex_weave.jac",
         "jac0core/passes/ast_validation_pass.jac",
         "jac0core/passes/decl_impl_match_pass.jac",
         "jac0core/passes/endpoint_effect_pass.jac",
         "jac0core/passes/jcir_gen_pass.jac",
         "jac0core/passes/module_codegen_pass.jac",
         "jac0core/passes/prefix_drive.jac",
         "jac0core/passes/semantic_analysis_pass.jac",
         "jac0core/passes/sym_tab_build_pass.jac",
         "jac0core/passes/transform.jac",
         "jac0core/passes/uni_pass.jac",
         "jac0core/srcloc.jac",
         "jac0core/unitree.jac",
         "compiler/expr_keys.jac",
         "compiler/native_materialize.jac",
         "compiler/passes/main/access_check_pass.jac",
         "compiler/passes/main/cfg_build_pass.jac",
         "compiler/passes/main/dataflow.jac",
         "compiler/passes/main/jsx_intrinsic_guard_pass.jac",
         "compiler/passes/main/rc_facts_pass.jac",
         "compiler/passes/main/sem_def_match_pass.jac",
         "compiler/type_registry.jac",
         "compiler/type_system/type_utils.jac",
         "compiler/type_system/types.jac",
         "project/client_kind_paths.jac",
         "runtimelib/client/targets/react_native/html_tag_map.jac",
         "runtimelib/na_stdlib/_hashlib_native.jac",
         "runtimelib/na_stdlib/contextvars.jac",
         "runtimelib/na_stdlib/fnmatch.jac",
         "runtimelib/na_stdlib/hashlib.jac",
         "runtimelib/na_stdlib/keyword.jac",
         "runtimelib/na_stdlib/logging.jac",
         "runtimelib/na_stdlib/pathlib.jac",
         "runtimelib/na_stdlib/textwrap.jac",

     );

glob NATIVE_SEAL_UNITREE_ROOT: str = "jac0core/unitree.jac",
     NATIVE_SEAL_MATERIALIZE_ROOT: str = "compiler/native_materialize.jac",
     NATIVE_SEAL_JCIR_ROOT: str = "jac0core/passes/jcir_gen_pass.jac";

glob _UNITREE_SEAM_WAIVERS: tuple[str, ...] = (
         "jac0core/unitree.jac::ModulePath.resolve_relative_path",
         "jac0core/unitree.jac::ModulePath.native_bundled_path",
         "jac0core/unitree.jac::Module.annexable_by.__get__",
         "jac0core/unitree.jac::Import.__jac_detected.__get__",
         "jac0core/unitree.jac::Import.is_service_import.__get__",
         "jac0core/unitree.jac::BuiltinType.lit_value.__get__",
         "jac0core/unitree.jac::Ellipsis.lit_value.__get__",

     ),
     _TYPES_SEAM_WAIVERS: tuple[str, ...] = (
         "compiler/type_system/types.jac::ClassType.lookup_member_symbol",
         "compiler/type_system/types.jac::FunctionType.specialize",

     ),
     _TYPE_UTILS_SEAM_WAIVERS: tuple[str, ...] = (
         "compiler/type_system/type_utils.jac::expr_primitive_name",
         "compiler/type_system/type_utils.jac::class_implements_protocol",
         "compiler/type_system/type_utils.jac::collect_member_syms",
         "compiler/type_system/type_utils.jac::doc_of_sym",
         "compiler/type_system/type_utils.jac::completion_item_from_sym",
         "compiler/type_system/type_utils.jac::get_completion_items",
         "compiler/type_system/type_utils.jac::completion_kind_from_sym",
         "compiler/type_system/type_utils.jac::compute_mro_linearization",
         "compiler/type_system/type_utils.jac::build_type_var_solution",
         "compiler/type_system/type_utils.jac::shadowed_type_var_names",
         "compiler/type_system/type_utils.jac::build_solution_from_specialized_class",

     ),
     _HELPERS_SEAM_WAIVERS: tuple[str, ...] = (
         "jac0core/helpers.jac::read_file_with_encoding",
         "jac0core/helpers.jac::normalize_exclude_patterns",
         "jac0core/helpers.jac::read_jacignore_patterns",
         "jac0core/helpers.jac::_is_version_info_access",
         "jac0core/helpers.jac::_is_type_checking_ref",
         "jac0core/helpers.jac::_extract_version_tuple",
         "jac0core/helpers.jac::evaluate_version_condition",

     ),
     _CODEINFO_SEAM_WAIVERS: tuple[str, ...] = (
         "jac0core/codeinfo.jac::CodeGenTarget.doc_ir.__get__",
         "jac0core/codeinfo.jac::_func_layout_to_dict",
         "jac0core/codeinfo.jac::_inferred_native_path",
         "jac0core/codeinfo.jac::effective_default_codespace",
         "jac0core/codeinfo.jac::effective_native_closure_cap",
         "jac0core/codeinfo.jac::install_native_static_init",
         "jac0core/codeinfo.jac::is_bundled_native_module",
         "jac0core/codeinfo.jac::is_client_by_location",
         "jac0core/codeinfo.jac::is_native_by_location",
         "jac0core/codeinfo.jac::native_layout_to_dict",
         "jac0core/codeinfo.jac::native_stdlib_root",
         "jac0core/codeinfo.jac::native_wasm_stem",
         "jac0core/codeinfo.jac::resolve_native_module",

     ),
     _CLOSURE_SEAM_WAIVERS: tuple[str, ...] = (
         _UNITREE_SEAM_WAIVERS
         + _TYPES_SEAM_WAIVERS
         + _TYPE_UTILS_SEAM_WAIVERS
         + _HELPERS_SEAM_WAIVERS
         + _CODEINFO_SEAM_WAIVERS
     ),
     _MCP_PASSENGER_SEAM_WAIVERS: tuple[str, ...] = (
         (
             "jac0core/passes/module_codegen_pass.jac::"
             "ModuleCodegenPass.has_native_context_stmts"
         ),
         (
             "jac0core/passes/module_codegen_pass.jac::"
             "ModuleCodegenPass.iter_context_stmts"
         ),
         (
             "jac0core/passes/module_codegen_pass.jac::"
             "ModuleCodegenPass.iter_module_imports"
         ),
         (
             "jac0core/passes/module_codegen_pass.jac::"
             "ModuleCodegenPass.iter_nested_imports"
         ),
         (
             "jac0core/passes/module_codegen_pass.jac::"
             "ModuleCodegenPass.shared_archetypes_for_context"
         ),
         "jac0core/passes/module_codegen_pass.jac::client_capability_violations",

     ),
     _CAPABILITY_SEAM_WAIVERS: tuple[str, ...] = (
         (
             "compiler/passes/main/capability_check_pass.jac::"
             "native_capability_violations"
         ),

     ),
     _CFG_BUILD_SEAM_WAIVERS: tuple[str, ...] = (
         "compiler/passes/main/cfg_build_pass.jac::cfg_dot_from_file",
         "compiler/passes/main/cfg_build_pass.jac::CoalesceBBPass.enter_node",
         "compiler/passes/main/cfg_build_pass.jac::CoalesceBBPass._node_label",

     ),
     _JCIR_INTEROP_SEAM_WAIVERS: tuple[str, ...] = (
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass._gen_native_interop_stubs",
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass._generate_sv_to_sv_stubs",
         (
             "jac0core/passes/jcir_gen_pass.jac::"
             "JcirGenPass._native_import_registration_map"
         ),
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass.exit_test",
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass.exit_import",

     ),
     _JCIR_LOWERING_SEAM_WAIVERS: tuple[str, ...] = (
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass._get_sem_decorator",
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass.exit_ability",
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass.exit_archetype",
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass.exit_enum",
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass.exit_ctrl_stmt",
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass.exit_module",
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass.exit_multi_string",
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass.exit_jsx_element",

     ),
     _JCIR_ENTITY_SEAM_WAIVERS: tuple[str, ...] = (
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass.exit_jsx_normal_attribute",
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass.exit_jsx_text",

     ),
     _JCIR_EMITTER_ICE_SEAM_WAIVERS: tuple[str, ...] = (
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass._query_filter_kws",
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass.exit_atom_trailer",
         "jac0core/passes/jcir_gen_pass.jac::JcirGenPass.exit_edge_ref_trailer",

     ),
     NATIVE_SEAL_DEMOTION_WAIVERS: dict[str, tuple[str, ...]] = {
         "compiler/native_materialize.jac": (
             _CLOSURE_SEAM_WAIVERS + _CFG_BUILD_SEAM_WAIVERS
         ),
         "jac0core/unitree.jac": _CLOSURE_SEAM_WAIVERS,
         "jac0core/passes/annex_pass.jac": _CLOSURE_SEAM_WAIVERS,
         "jac0core/passes/module_codegen_pass.jac": _CLOSURE_SEAM_WAIVERS,
         "jac0core/passes/uni_pass.jac": (
             _CLOSURE_SEAM_WAIVERS + _MCP_PASSENGER_SEAM_WAIVERS
         ),
         "jac0core/passes/transform.jac": _CLOSURE_SEAM_WAIVERS,
         "jac0core/passes/endpoint_effect_pass.jac": _CLOSURE_SEAM_WAIVERS,
         "jac0core/passes/ast_validation_pass.jac": _CLOSURE_SEAM_WAIVERS,
         "jac0core/passes/semantic_analysis_pass.jac": _CLOSURE_SEAM_WAIVERS,
         "jac0core/passes/sym_tab_build_pass.jac": _CLOSURE_SEAM_WAIVERS,
         "jac0core/passes/decl_impl_match_pass.jac": _CLOSURE_SEAM_WAIVERS,
         "compiler/passes/main/sem_def_match_pass.jac": _CLOSURE_SEAM_WAIVERS,
         "compiler/passes/main/access_check_pass.jac": _CLOSURE_SEAM_WAIVERS,
         "compiler/passes/main/jsx_intrinsic_guard_pass.jac": _CLOSURE_SEAM_WAIVERS,
         "compiler/passes/main/cfg_build_pass.jac": (
             _CLOSURE_SEAM_WAIVERS + _CFG_BUILD_SEAM_WAIVERS
         ),
         "compiler/passes/main/rc_facts_pass.jac": _CLOSURE_SEAM_WAIVERS,
         "compiler/passes/main/capability_check_pass.jac": (
             _CLOSURE_SEAM_WAIVERS + _CAPABILITY_SEAM_WAIVERS
         ),
         "jac0core/passes/jcir_gen_pass.jac": (
             _CLOSURE_SEAM_WAIVERS
             + _JCIR_INTEROP_SEAM_WAIVERS
             + _JCIR_LOWERING_SEAM_WAIVERS
             + _JCIR_ENTITY_SEAM_WAIVERS
             + _JCIR_EMITTER_ICE_SEAM_WAIVERS
         )
     };

glob NATIVE_SEAL_WAIVER_FAMILIES: tuple[tuple[str, tuple[str, ...], str], ...] = (
         (
             "unitree Python-only surface",
             _UNITREE_SEAM_WAIVERS,
             "Import resolution, filesystem and jac.toml reads, the "
             "CPython ast bridge, the `type`-object literal map and the `...` "
             "value. Each is infrastructure no native unit can host. "
             "They clear as the driver hands the tree data instead of "
             "handles: import detection stamped onto the node (the #8242 "
             "`absorbed_mod` pattern), codegen state crossing as records, "
             "and a native value for `Ellipsis`. `UniNode.gen.__get__` sat "
             "here until `codeinfo` joined the closure; with the module in "
             "the unit the lazy `CodeGenTarget` construction lowers and the "
             "waiver is gone."
         ),
         (
             "type system cross-module cascades",
             _TYPES_SEAM_WAIVERS,
             "`lookup_member_symbol` and `specialize` are cascades of the "
             "`type_utils` waivers below -- `collect_member_syms` and "
             "`build_type_var_solution` -- and clear with their callees. "
             "`create_callable_type` used to sit here for reading "
             "`ParameterCategory.Positional`, whose `auto()` value no "
             "constant fold reached; generated enum values gave it one and "
             "the read lowers."
         ),
         (
             "type utils erased operands and unreachable layouts",
             _TYPE_UTILS_SEAM_WAIVERS,
             "Three named backend gaps and their cascades: `isinstance` "
             "against a layout not reachable from the root "
             "(`class_implements_protocol`, `doc_of_sym`), `enumerate(...)` "
             "as a for-loop iterable (`build_type_var_solution`, "
             "`build_solution_from_specialized_class`), and comprehensions or "
             "matches over element-erased collections "
             "(`shadowed_type_var_names`, `completion_kind_from_sym`). "
             "`expr_primitive_name` is the one Python-only member: it reaches "
             "`get_type_evaluator`, and `type_evaluator.jac` cannot join this "
             "closure. Each clears with the named gap; "
             "`expr_primitive_name` clears when the evaluator query crosses "
             "as data."
         ),
         (
             "helpers file reads and the unitree cycle",
             _HELPERS_SEAM_WAIVERS,
             "Two groups. `read_file_with_encoding` passes an encoding "
             "keyword to `open()`, which the native lane refuses out loud "
             "since #8255; `normalize_exclude_patterns` and "
             "`read_jacignore_patterns` are string methods on "
             "element-erased list members. The `sys.version_info` family "
             "reads unitree through a function-local import that keeps "
             "`helpers` out of a module-level cycle with `unitree`; "
             "hoisting it is the clearing mechanism and it needs the cycle "
             "broken first. `pretty_print_source_location` and "
             "`format_related_spans` sat here until their old-style `%` "
             "formatting (the `MOD on i8*` gap) became plain padding; the "
             "console gutter lowers now and `Alert.pretty_print` with it."
         ),
         (
             "codeinfo Python-only machinery and named backend gaps",
             _CODEINFO_SEAM_WAIVERS,
             "The module the emptied `PLACEMENT_INFERENCE_HELD` entry was "
             "holding out of every unit (#8323 B4). Its data model lowers "
             "whole; every seam is filesystem, config or Python-codegen "
             "machinery no native unit can host, or a named backend gap. "
             "Python-only: `native_stdlib_root`, `is_native_by_location`, "
             "`is_client_by_location` (a `jaclang.__file__` read), "
             "`effective_default_codespace` and `effective_native_closure_"
             "cap` (`project.config` reads), `_inferred_native_path` and "
             "`resolve_native_module` (the placement scan, the driver's "
             "ground), `is_bundled_native_module` (cascade), "
             "`CodeGenTarget.doc_ir.__get__` (lazy `doc_ir` import), "
             "`install_native_static_init` (writes an `any`-typed engine "
             "handle). Backend gaps: `native_layout_to_dict` and "
             "`_func_layout_to_dict` (`any` box of an optional), "
             "`native_wasm_stem` (`os.path.splitext`). None is reachable "
             "from a parse; each Python-only entry clears when its answer "
             "crosses as driver-stamped data, the #8274 pattern."
         ),
         (
             "module_codegen passengers in the uni_pass artifact",
             _MCP_PASSENGER_SEAM_WAIVERS,
             "In `uni_pass.jac`'s own unit the seat class is an ancestor "
             "rather than the root, and `iter_context_stmts`'s "
             "`isinstance` against `ElementStmt` loses the root-relative "
             "layout reachability it has in every other unit; the other "
             "five are cascades of it. The copies are dead passengers -- "
             "the serving binder answers `module_codegen_pass` calls from "
             "that root's own artifact -- and they clear when imported "
             "isinstance stops being root-relative. The base-chain field "
             "wall that once ran the other way is gone: every measured "
             "root lowers `__post_init__`/`transform`/`traverse` now, so "
             "uni_pass contributes no waiver of its own anywhere."
         ),
         (
             "capability pass-tier crossing",
             _CAPABILITY_SEAM_WAIVERS,
             "`native_capability_violations` calls "
             "`ModuleCodegenPass.iter_context_stmts`, a method on another "
             "sealed root's class, and the crossing clears when sealed "
             "artifacts link each other rather than when the callee is "
             "fixed -- the callee reached zero seams in wave 6. The waiver "
             "does NOT make the root sealable: the seal's abort-stub "
             "linkage check measured `NativeCapabilityCheckPass.transform` "
             "-- the live entry point -- linking this stub directly, which "
             "is why the root sits in `NATIVE_SEAL_REFUSED_ROOTS` with "
             "that finding as its blocker. The accounting stays so the "
             "audit keeps measuring the refused root; "
             "`test_pass_seal_wave6_census.jac` carries the census."
         ),
         (
             "cfg_build graph tooling and erased basic-block storage",
             _CFG_BUILD_SEAM_WAIVERS,
             "`cfg_dot_from_file` opens a file and drives a whole "
             "`JacProgram` -- the `jac dot` tool, never the compile "
             "schedule -- and `CoalesceBBPass` exists only to serve it. "
             "`enter_node` and `_node_label` are that pass's own surface: "
             "the first subscripts `basic_blocks`, a "
             "`dict[int, dict[str, list[UniCFGNode]]]` whose inner entry "
             "reaches the emitter as a bare pointer, and the second "
             "cascades on `unparse_node`. They clear together when a "
             "container stored inside a container keeps its layout. "
             "`_find_next_cfg_stmt_after` was here until it learned to "
             "read the body through the classes that own one; it lowers "
             "now and its waiver is gone."
         ),
         (
             "jcir interop manifest and driver reads",
             _JCIR_INTEROP_SEAM_WAIVERS,
             "The native-export and sv-to-sv stub surface reads "
             "`gen.interop_manifest` and the `InteropBinding` / "
             "`BoundaryTypeInfo` codeinfo objects, which are Python "
             "codegen state. The driver read that used to sit beside "
             "them is gone: `exit_import` consumes "
             "`Import.native_only_drop` instead of asking the driver for "
             "`native_only_import_target`, so this root names no driver "
             "entry point at all. Four entries cleared when `codeinfo` "
             "joined the closure -- the py-sv stub builders and "
             "`_native_test_shim_stmts` read manifest state whose types "
             "now have in-unit layouts. Clears the rest of the way when "
             "the manifest crosses as a native-clean record instead of a "
             "Python object."
         ),
         (
             "jcir named backend gaps",
             _JCIR_LOWERING_SEAM_WAIVERS,
             "Named constructs the backend does not yet lower: reads and "
             "assignments of element-erased list elements, comprehensions "
             "over element-erased collections, and `_merge_module_bodies` "
             "on the generic base pass. `exit_archetype`, `exit_enum` and "
             "`exit_ability` are cascades of `_get_sem_decorator`. Each "
             "clears when the named construct lowers; the generic-base one "
             "also clears by the monomorphic-override route that already "
             "cleared `_flatten_ast_list` on this pass."
         ),
         (
             "jcir html entity decoding",
             _JCIR_ENTITY_SEAM_WAIVERS,
             "Jsx text and string attributes decode html entities through "
             "the Python `html` module. Clears with an na_stdlib `html` "
             "shim carrying the full html5 entity table, pinned against "
             "`html.unescape` the way `test_jcir_facts_sync.jac` pins the "
             "other baked facts. A reduced table is not acceptable: the "
             "two lanes must agree byte for byte, so a missing entity is "
             "a silent divergence rather than a missing feature."
         ),
         (
             "jcir emitter-internal refusal",
             _JCIR_EMITTER_ICE_SEAM_WAIVERS,
             "`_query_filter_kws` refuses with an emitter-internal error "
             "rather than a named gap, and takes its two callers with it. "
             "Restructuring away union locals, `any` locals, conditional "
             "expressions and continue-guards does not move it, which "
             "places the fault in the native emitter rather than in the "
             "shape of the source. Its sibling `exit_delete_stmt` was in "
             "the same state and cleared when its nested function became "
             "a method, so nested-function lowering is the first place to "
             "look. Clears when that emitter fault is fixed."
         )
     );

def _seal_module_label(path: str, pkg_path: (Path | None)) -> str {
    if pkg_path is not None {
        try {
            return Path(path).resolve().relative_to(
                Path(pkg_path).resolve()
            ).as_posix();
        } except ValueError { }
    }
    return os.path.basename(path);
}

def _seal_demotions(
    coverage: dict[str, dict[str, any]], pkg_path: (Path | None) = None
) -> list[tuple[str, str, str]] {
    found: list[tuple[str, str, str]] = [];
    for (path, rec) in sorted(coverage.items()) {
        where = _seal_module_label(path, pkg_path);
        for seam in (rec.get("seams") or []) {
            text = str(seam);
            (name, sep, why) = text.partition(": ");
            bare = name if sep else text;
            reason = why if sep else text;
            found.append((f"{where}::{bare}", bare, f"{where}: {reason}"));
        }
        if rec.get("outcome") == "demoted" {
            code = rec.get("code") or "?";
            detail = rec.get("detail") or "";
            found.append(
                (
                    f"{where}::<module>",
                    "<module>",
                    f"{where}: whole module demoted [{code}] {detail}"
                )
            );
        }
    }
    return found;
}

def seal_waiver_names(
    rel: str, waivers: (dict[str, tuple[str, ...]] | None) = None
) -> tuple[set[str], set[str]] {
    table = NATIVE_SEAL_DEMOTION_WAIVERS if waivers is None else waivers;
    qualified = set(table.get(rel, ()));
    bare = {q.split("::")[-1] for q in qualified};
    return (qualified, bare);
}

def seal_demotion_report(
    rel: str,
    coverage: dict[str, dict[str, any]],
    waivers: (dict[str, tuple[str, ...]] | None) = None,
    pkg_path: (Path | None) = None
) -> tuple[str, list[str], list[str]] {
    (allowed, _bare) = seal_waiver_names(rel, waivers);
    found = _seal_demotions(coverage, pkg_path);
    names = {q for (q, _b, _why) in found};
    offending = [
        (q, why)
        for (q, _b, why) in found
        if q not in allowed
    ];
    waived = sorted(
        n
        for n in names
        if n in allowed
    );
    stale = sorted(
        a
        for a in allowed
        if a not in names
    );
    if not offending {
        return ("", waived, stale);
    }
    lines = [
        f"NATIVE SEAL: {rel} demoted {len(offending)} method(s) the native "
        "backend could not lower. A sealed artifact has no Python left to fall "
        "back to, so every demotion ships as an abort stub that kills the "
        "process at the first call with no diagnostic."
    ];
    for (n, why) in offending {
        lines.append(f"    {n}  <-  {why}");
    }
    lines.append(
        "  Fix the native lowering, or waive a knowingly-unreachable method by "
        "adding its exact <module>::<Type>.<method> name above to "
        "NATIVE_SEAL_DEMOTION_WAIVERS[\""
            + rel
            + "\"] in jaclang/utils/precompile_bytecode.jac. The module half is "
            + "required: a bare method name would also waive a same-named "
            + "method demoting in a different module of the closure. Set "
            + "JAC_NA_DEBUG=1 to print the full diagnostic behind each demotion."
    );
    return ("\n".join(lines), waived, stale);
}

def seal_abort_stubs(llvm_ir_text: str) -> list[str] {
    import re;
    name_re = re.compile(r'@(?:"([^"]+)"|([A-Za-z0-9_.$\-]+))\s*\(');
    abort_re = re.compile(
        r'^(?:tail\s+|musttail\s+|notail\s+)?call\s+void\s+@"?abort"?\s*\(\s*\)'
    );
    stubs: list[str] = [];
    lines = llvm_ir_text.splitlines();
    total = len(lines);
    i = 0;
    while i < total {
        head = lines[i].strip();
        i += 1;
        if not head.startswith("define") {
            continue;
        }
        matched = name_re.search(head);
        if matched is None {
            continue;
        }
        body: list[str] = [];
        while i < total {
            cur = lines[i].strip();
            i += 1;
            if cur == "}" {
                break;
            }
            if cur and cur != "{" {
                body.append(cur);
            }
        }
        if (
            len(body) == 3
            and body[0].endswith(":")
            and abort_re.`match(body[1]) is not None
            and body[2] == "unreachable"
        ) {
            stub_name = matched.group(1) or matched.group(2);
            if stub_name.endswith(".__jac_demoted") {
                stub_name = stub_name[:-len(".__jac_demoted")];
            }
            stubs.append(stub_name);
        }
    }
    return sorted(set(stubs));
}

def purge_native_ir_cache(root_src: str, deps: (list[str] | None) = None) -> int {
    import glob as _glob;
    import from jaclang.jac0core.jir { get_native_cache_dir }
    base = os.path.dirname(os.path.abspath(root_src));
    dirs: list[str] = [];
    stems: list[str] = [];
    for raw in [root_src] + list(deps or []) {
        if not raw {
            continue;
        }
        resolved = raw if os.path.isabs(raw) else os.path.join(base, raw);
        stems.append(os.path.splitext(os.path.basename(resolved))[0]);
        try {
            cache_dir = str(get_native_cache_dir(resolved));
            if cache_dir not in dirs {
                dirs.append(cache_dir);
            }
        } except Exception { }
    }
    removed = 0;
    for cache_dir in dirs {
        for stem in sorted(set(stems)) {
            for suffix in ("ir_cache", "ir_meta") {
                for stale in _glob.`glob(
                    os.path.join(cache_dir, f"{stem}.*.{suffix}")
                ) {
                    try {
                        os.remove(stale);
                        removed += 1;
                    } except OSError { }
                }
            }
        }
    }
    return removed;
}

def seal_native_canary(lib_path: str, exports: list[str]) -> str {
    import ctypes;
    import traceback;
    import from jaclang.jac0core.compile_options { env_na_debug }
    import from jaclang.jac0core.native_dylib { DylibEngine }

    debug = env_na_debug();
    name = os.path.basename(lib_path);
    sys.stderr.write(f"    canary: dlopen {name}\n");
    sys.stderr.flush();
    try {
        eng = DylibEngine(lib_path);
    } except Exception as _open_exc {
        if debug {
            traceback.print_exc(file=sys.stderr);
        }
        return f"dlopen failed: {type(_open_exc).__name__}: {_open_exc}";
    }
    missing = sorted(
        {
            s
            for s in (list(exports) + ["__jac_shared_init"])
            if eng.get_function_address(s) == 0
        }
    );
    if missing {
        shown = ", ".join(missing[:8]);
        return (
            f"{len(missing)} advertised export(s) are not in the linked "
            f"artifact: {shown}"
        );
    }
    sys.stderr.write(f"    canary: __jac_shared_init in {name}\n");
    sys.stderr.flush();
    try {
        eng.initialize();
    } except Exception as _init_exc {
        if debug {
            traceback.print_exc(file=sys.stderr);
        }
        return f"__jac_shared_init raised {type(_init_exc).__name__}: {_init_exc}";
    }
    probe = eng.get_function_address("jac_str_new");
    if not probe {
        return "";
    }
    sys.stderr.write(f"    canary: jac_str_new in {name}\n");
    sys.stderr.flush();
    try {
        made = ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64)(
            probe
        )(
            b"jac", 3
        );
    } except Exception as _call_exc {
        if debug {
            traceback.print_exc(file=sys.stderr);
        }
        return f"jac_str_new raised {type(_call_exc).__name__}: {_call_exc}";
    }
    if not made {
        return (
            "jac_str_new returned NULL: the artifact loaded but its runtime is "
            "not live"
        );
    }
    return "";
}

glob _PARITY_CANARY_LINES: tuple[str, ...] = (
         "import os;",
         "glob G: int = 42, H: str = 'control-flow harness (Branch 4)';",
         "enum E { A = 1, B = 2 }",
         "obj Canary {",
         "    has a: int = 0, b: (str | None) = None, c: list[int] = [];",
         "    def m(p: int = 3) -> int;",
         "}",
         "impl Canary.m(p: int = 3) -> int {",
         "    if p > 1 and p < 10 or not p {",
         "        for i in range(p) {",
         "            self.a += i * 2 - 1;",
         "        }",
         "    } elif p == 0 {",
         "        while self.a {",
         "            self.a -= 1;",
         "        }",
         "    } else {",
         "        try {",
         "            self.b = f'v={p} w={self.a}';",
         "        } except Exception as e {",
         "            raise;",
         "        }",
         "    }",
         "    return self.a if self.a else -1;",
         "}",
         "test \"canary t\" { assert Canary(a=5).m(2) >= -1; }",
         "test { assert Canary(a=1).m() >= -1; }",
         "test box_holds { assert Canary(a=2).m() >= -1; }",
         "with entry { print({'k': [1, 2.5, True, None]}); }",

     ),
     _PARITY_CORPUS_LINES: tuple[str, ...] = (
         "# leading comment: crossing envelopes must carry comments, and a",
         "# prior parse's envelope objects must never bleed into this tree",
         "import os;",
         "import from dataclasses { dataclass }",
         "glob G: int = 42, H: (str | None) = None;",
         "enum Hue { RED = 1, GREEN = 2 }",
         "node Spot { has label: str = ''; }",
         "edge Road { has miles: int = 0; }",
         "walker Tour {",
         "    can step with Spot entry;",
         "}",
         "impl Tour.step with Spot entry {",
         "    visit [-->];",
         "}",
         "obj Box { has x: int = 0, y: list[int] = [], z: dict[str, int] = {}; ",
         "    def m(p: int = 1) -> int; }",
         "impl Box.m(p: int = 1) -> int {",
         "    if p > 1 and p < 9 or not p { for i in range(p) { self.x += i; } }",
         "    elif p == 0 { while self.x { self.x -= 1; } }",
         "    else { try { raise ValueError('v'); } except ValueError as e { } }",
         "    return self.x if self.x else -1;",
         "}",
         "enum Mood;",
         "impl Mood {",
         "    UP = 1,",
         "    DOWN: int = 2,",
         "    FLAT = 3",
         "}",
         "def pick(v: any) -> int {",
         "    match v {",
         "        case [1, 2]: return 1;",
         "        case {'k': 2}: return 2;",
         "        case _: return 0;",
         "    }",
         "}",
         "def:pub View(t: str) -> JsxElement {",
         "    return <div id='a'>{t}</div>;",
         "}",
         "async def later -> None {}",
         "def guess(t: str) -> int by fake_llm();",
         "enum Tone: int {",
         "    LOW = 3,",
         "    HIGH = 4,",
         "}",
         "def imp_scope -> int {",
         "    import from math { floor };",
         "    return floor(1.5);",
         "}",
         "@dataclass",
         "class _PyStyle {",
         "    label: str = '';",
         "    count: int = 0;",
         "    def bump(self: _PyStyle) -> int {",
         "        self.count += 1;",
         "        return self.count;",
         "    }",
         "}",
         "test \"box holds\" { assert Box(x=1).m() >= -1; }",
         "test { assert Box(x=2).m() >= -1; }",
         "test \"...\" { assert Box(x=3).m() >= -1; }",
         "with entry { b = Box(x=5); print(f'v={b.m(2)}', {'s': [1, 2.5, True, None]}); }  # trailing",

     );

glob _PARITY_IDENT_PROBES: tuple[str, ...] = (
         '"abc"',
         '"ABC"',
         '"a1"',
         '"a b"',
         '" ab"',
         '"ab "',
         "'abc'",
         '"a-b"',
         '"..."'
     );

def _parity_test_names(mod: any) -> list[str] {
    import jaclang.jac0core.unitree as uni;
    out: list[str] = [];
    for nd in mod._in_mod_nodes {
        if isinstance(nd, uni.Test) {
            out.append(str(getattr(nd.__dict__.get("name"), "value", "<none>")));
        }
    }
    return out;
}


def _parity_ident_probe(np: any) -> str {
    import from jaclang.jac0core.parser.lexer { tokenize_full }
    import from jaclang.jac0core.parser.parser { Parser }

    nl = chr(10);
    rows: list[str] = [
        "    ident-derivation probe: a described test whose ident derives "
        "must not consume a generated ordinal, so the trailing bare test "
        "must be _jac_gen_1 on both tiers"
    ];
    for pi in range(len(_PARITY_IDENT_PROBES)) {
        desc = _PARITY_IDENT_PROBES[pi];
        path = f"__seal_parity_probe_{pi}__.jac";
        src = nl.join(["test " + desc + " { assert 1; }", "test { assert 1; }"]);
        n_names: list[str] = [];
        try {
            (n_mod, _ne, _npd, _nc, _nld, _nle) = np.parse(src, path);
            n_names = _parity_test_names(n_mod);
        } except Exception as probe_exc {
            n_names = [f"<{type(probe_exc).__name__}: {probe_exc}>"];
        }
        (toks, _pc, _pld, _ple) = tokenize_full(src, path);
        p_names = _parity_test_names(
            Parser(tokens=toks, file_path=path, source_code=src).parse()
        );
        verdict = "ok" if n_names == p_names else "DIVERGED";
        rows.append(
            f"      test {desc:<8} native {n_names} vs bytecode {p_names}"
            f"  {verdict}"
        );
    }
    return nl.join(rows);
}


def _parity_diff_at(left: any, right: any) -> int {
    limit = min(len(left), len(right));
    for i in range(limit) {
        if left[i] != right[i] {
            return i;
        }
    }
    return limit;
}


def _parity_window(items: list[str], at: int, span: int, sep: str = " ") -> str {
    lo = max(0, at - span);
    hi = min(len(items), at + span + 1);
    out = sep.join([str(x) for x in items[lo:hi]]);
    if lo > 0 {
        out = f"...{out}";
    }
    if hi < len(items) {
        out = f"{out}...";
    }
    return out;
}


def _parity_pairwise(
    left: list[str], right: list[str], cap: int
) -> tuple[(list[str], int)] {
    shown: list[str] = [];
    total = 0;
    for i in range(max(len(left), len(right))) {
        l_at = str(left[i]) if i < len(left) else "<end>";
        r_at = str(right[i]) if i < len(right) else "<end>";
        if l_at == r_at {
            continue;
        }
        total += 1;
        if len(shown) < cap {
            shown.append(f"[{i + 1}] native {l_at!r} vs bytecode {r_at!r}");
        }
    }
    return (shown, total, );
}


def _parity_text_report(canary_path: str, native_up: str, py_up: str) -> str {
    nl = chr(10);
    off = _parity_diff_at(native_up, py_up);
    line = native_up.count(nl, 0, off) + 1;
    col = off - native_up.rfind(nl, 0, off);
    n_toks = native_up.split();
    p_toks = py_up.split();
    at = _parity_diff_at(n_toks, p_toks);
    (shown, total) = _parity_pairwise(n_toks, p_toks, 6);
    out = [
        f"{canary_path}: unparse diverged at line {line}, col {col} "
        f"(char {off} of {len(native_up)} native / {len(py_up)} bytecode)",
        f"    {total} differing token(s) of {len(n_toks)} native / "
        f"{len(p_toks)} bytecode",
        f"    native   {_parity_window(n_toks, at, 8)}",
        f"    bytecode {_parity_window(p_toks, at, 8)}"
    ];
    for `entry in shown {
        out.append(f"    {`entry}");
    }
    if total > len(shown) {
        out.append(f"    ... and {total - len(shown)} more");
    }
    return nl.join(out);
}


def _parity_sym_report(canary_path: str, n_syms: list[str], p_syms: list[str]) -> str {
    nl = chr(10);
    at = _parity_diff_at(n_syms, p_syms);
    n_show = n_syms[at] if at < len(n_syms) else "<end>";
    p_show = p_syms[at] if at < len(p_syms) else "<end>";
    return nl.join(
        [
            f"{canary_path}: symbol names diverged at entry {at + 1} of "
            f"{len(n_syms)} native / {len(p_syms)} bytecode: "
            f"native {n_show!r} vs bytecode {p_show!r}",
            f"    native   {_parity_window(n_syms, at, 3, sep=', ')}",
            f"    bytecode {_parity_window(p_syms, at, 3, sep=', ')}"
        ]
    );
}


def seal_parse_parity_canary(lib_path: str, layout_dict: dict[str, any]) -> str {
    import traceback;
    import from jaclang.compiler.passes.tool.unparse_pass { unparse_node }
    import from jaclang.jac0core.compile_options { env_na_debug }
    import from jaclang.jac0core.parser.lexer { tokenize_full }
    import from jaclang.jac0core.parser.materialize { bind_native_parser }
    import from jaclang.jac0core.parser.parser { Parser }

    nl = chr(10);
    sys.stderr.write(f"    canary: parse parity in {os.path.basename(lib_path)}\n");
    sys.stderr.flush();
    try {
        np = bind_native_parser(lib_path, layout_dict);
    } except Exception as bind_exc {
        if env_na_debug() {
            traceback.print_exc(file=sys.stderr);
        }
        return f"binding failed: {type(bind_exc).__name__}: {bind_exc}";
    }
    corpora = [
        (nl.join(list(_PARITY_CANARY_LINES)), "__seal_parity_harness__.jac", ),
        (nl.join(list(_PARITY_CORPUS_LINES)), "__seal_parity_corpus__.jac", ),

    ];

    corpora = corpora
        + [(src, p.replace(".jac", "_round2_.jac"), ) for (src, p) in corpora];
    for (canary_src, canary_path) in corpora {
        try {
            (native_mod, n_errs, _pd, _cm, _ld, n_lex_errs) = np.parse(
                canary_src, canary_path
            );
        } except Exception as parse_exc {
            if env_na_debug() {
                traceback.print_exc(file=sys.stderr);
            }
            return (
                f"native parse of {canary_path} raised "
                f"{type(parse_exc).__name__}: {parse_exc}"
            );
        }
        (tokens, _c, _lex_d, lex_errs) = tokenize_full(canary_src, canary_path);
        pyp = Parser(tokens=tokens, file_path=canary_path, source_code=canary_src);
        py_mod = pyp.parse();
        if n_errs != pyp.error_count or n_lex_errs != lex_errs {
            return (
                f"{canary_path}: error counts diverged "
                f"(native {n_errs}/{n_lex_errs}, bytecode "
                f"{pyp.error_count}/{lex_errs})"
            );
        }
        if len(native_mod._in_mod_nodes) != len(py_mod._in_mod_nodes) {
            return (
                f"{canary_path}: node counts diverged "
                f"({len(native_mod._in_mod_nodes)} != "
                f"{len(py_mod._in_mod_nodes)})"
            );
        }
        native_up = unparse_node(native_mod);
        py_up = unparse_node(py_mod);
        n_syms: list[str] = [];
        p_syms: list[str] = [];
        try {
            n_syms = _sym_name_fingerprint(native_mod);
            p_syms = _sym_name_fingerprint(py_mod);
        } except Exception as sym_exc {
            return (
                f"{canary_path}: symbol fingerprint raised "
                f"{type(sym_exc).__name__}: {sym_exc}"
            );
        }
        if native_up != py_up or n_syms != p_syms {
            if env_na_debug() {
                sys.stderr.write(
                    f"--- {canary_path}: native unparse ---{nl}{native_up}{nl}"
                    f"--- {canary_path}: bytecode unparse ---{nl}{py_up}{nl}"
                );
                sys.stderr.flush();
            }
            detail: list[str] = [];
            if native_up != py_up {
                detail.append(_parity_text_report(canary_path, native_up, py_up));
            }
            if n_syms != p_syms {
                detail.append(_parity_sym_report(canary_path, n_syms, p_syms));
            }
            try {
                detail.append(_parity_ident_probe(np));
            } except Exception as probe_exc {
                detail.append(
                    f"    ident-derivation probe unavailable: "
                    f"{type(probe_exc).__name__}: {probe_exc}"
                );
            }
            return nl.join(detail);
        }
    }
    return _merge_probe_parity(np);
}

def seal_prefix_parity_canary(lib_path: str, layout_dict: dict[str, any]) -> str {
    import traceback;
    import from jaclang.compiler.passes.tool.unparse_pass { unparse_node }
    import from jaclang.jac0core.compile_options { env_na_debug }
    import from jaclang.jac0core.parser.lexer { tokenize_full }
    import from jaclang.jac0core.parser.materialize { bind_native_parser }
    import from jaclang.jac0core.parser.parser { Parser }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.passes.ast_validation_pass { ASTValidationPass }
    import from jaclang.jac0core.passes.sym_tab_build_pass { SymTabBuildPass }
    import from jaclang.jac0core.passes.decl_impl_match_pass { DeclImplMatchPass }
    import from jaclang.jac0core.passes.semantic_analysis_pass { SemanticAnalysisPass }
    import from jaclang.compiler.passes.main.sem_def_match_pass { SemDefMatchPass }
    import from jaclang.compiler.passes.main.cfg_build_pass { CFGBuildPass }

    nl = chr(10);
    sys.stderr.write(f"    canary: prefix parity in {os.path.basename(lib_path)}\n");
    sys.stderr.flush();
    try {
        np = bind_native_parser(lib_path, layout_dict);
    } except Exception as bind_exc {
        if env_na_debug() {
            traceback.print_exc(file=sys.stderr);
        }
        return f"binding failed: {type(bind_exc).__name__}: {bind_exc}";
    }
    if not np.serves_prefix() {
        return "the artifact exports no mat_parse_and_run_prefix entry";
    }
    _pfx_harness_lines = [
        (
            'test "box holds" { assert Canary(a=2).m() >= -1; }'
                if ln.startswith("test box_holds")
                else ln
        ) for ln in _PARITY_CANARY_LINES
    ];
    _pfx_alerting_lines = [
        "def m(p: int) -> int {",
        "    break;",
        "    return p;",
        "}",

    ];
    corpora = [
        (nl.join(_pfx_harness_lines), "__seal_prefix_harness__.jac", 0, ),
        (nl.join(list(_PARITY_CORPUS_LINES)), "__seal_prefix_corpus__.jac", 0, ),
        (nl.join(_pfx_alerting_lines), "__seal_prefix_alerting__.jac", 1, ),

    ];
    import from jaclang.jac0core.passes.prefix_drive {
        PREFIX_NATIVE_FRONTIER as _pfx_frontier
    }
    for (canary_src, canary_path, min_rows) in corpora {
        try {
            r = np.parse_and_run_prefix(canary_src, canary_path, 6, "", 0, 0);
        } except Exception as run_exc {
            if env_na_debug() {
                traceback.print_exc(file=sys.stderr);
            }
            return (
                f"prefix crossing of {canary_path} raised "
                f"{type(run_exc).__name__}: {run_exc}"
            );
        }
        (native_mod, n_errs, _pd, _cm, _ld, n_lex) = (
            r[0],
            r[1],
            r[2],
            r[3],
            r[4],
            r[5],

        );
        (executed, clause, detail, rows) = (r[6], r[7], r[8], r[9], );
        if n_errs or n_lex {
            _pd_head: list[str] = [];
            try {
                for _pd_row in (list(_pd) + list(_ld))[:3] {
                    _pd_head.append(
                        f"{_pd_row.loc.line}:{_pd_row.loc.col_start} "
                        f"{str(_pd_row.message)[:90]}"
                    );
                }
            } except Exception as _pd_exc {
                _pd_head.append(f"<diag rows unreadable: {_pd_exc}>");
            }
            return (
                f"{canary_path}: the seal corpus did not parse "
                f"({n_errs}/{n_lex}): {'; '.join(_pd_head)}"
            );
        }
        if executed != _pfx_frontier {
            return (
                f"{canary_path}: the crossing executed {executed}, but the "
                f"native frontier claims {_pfx_frontier} ({clause}: {detail})"
            );
        }
        if len(rows) < min_rows {
            return (
                f"{canary_path}: the alerting corpus produced {len(rows)} "
                f"row(s); a canary that cannot see an alert is decoration"
            );
        }
        (tokens, _c, _lx, lex_errs) = tokenize_full(canary_src, canary_path);
        pyp = Parser(tokens=tokens, file_path=canary_path, source_code=canary_src);
        py_mod = pyp.parse();
        if pyp.error_count or lex_errs {
            return f"{canary_path}: the staged parse of the corpus errored";
        }
        prog = JacProgram();
        staged_rows: list[tuple] = [];
        _pfx_all_passes = (
            ASTValidationPass,
            SymTabBuildPass,
            DeclImplMatchPass,
            SemanticAnalysisPass,
            SemDefMatchPass,
            CFGBuildPass,

        );
        for (pass_ord, cls) in enumerate(_pfx_all_passes[:_pfx_frontier]) {
            inst: any = cls(ir_in=py_mod, prog=prog);
            for e in inst.errors_had {
                staged_rows.append(
                    (
                        1,
                        e.code.code if e.code is not None else "",
                        e.msg,
                        e.loc.first_line,
                        e.loc.col_start,
                        e.loc.pos_start,
                        e.loc.pos_end,
                        pass_ord,

                    )
                );
            }
            for w in inst.warnings_had {
                staged_rows.append(
                    (
                        0,
                        w.code.code if w.code is not None else "",
                        w.msg,
                        w.loc.first_line,
                        w.loc.col_start,
                        w.loc.pos_start,
                        w.loc.pos_end,
                        pass_ord,

                    )
                );
            }
        }
        native_rows = [
            (rr[0], rr[1], rr[2], rr[4], rr[5], rr[6], rr[7], rr[8], ) for rr in rows
        ];
        if native_rows != staged_rows {
            return (
                f"{canary_path}: the alert streams diverged "
                f"(prefix {len(native_rows)} row(s), staged "
                f"{len(staged_rows)}): {native_rows[:3]} != {staged_rows[:3]}"
            );
        }
        native_up = unparse_node(native_mod);
        py_up = unparse_node(py_mod);
        if native_up != py_up {
            return _parity_text_report(canary_path, native_up, py_up);
        }
        n_syms: list[str] = [];
        p_syms: list[str] = [];
        try {
            n_syms = _sym_name_fingerprint(native_mod);
            p_syms = _sym_name_fingerprint(py_mod);
        } except Exception as sym_exc {
            return (
                f"{canary_path}: post-pass symbol fingerprint raised "
                f"{type(sym_exc).__name__}: {sym_exc}"
            );
        }
        if n_syms != p_syms {
            return _parity_sym_report(canary_path, n_syms, p_syms);
        }
    }
    return "";
}

glob _MERGE_PROBE_MAIN: tuple[str, ...] = (
         "obj Widget {",
         "    has size: int = 1;",
         "    def grow(n: int) -> int;",
         "}",
         "with entry { print(Widget(size=2)); }",

     ),
     _MERGE_PROBE_ANNEX: tuple[str, ...] = (
         "impl Widget.grow(n: int) -> int {",
         "    self.size += n;",
         "    return self.size;",
         "}",
         "test \"widget grows\" { assert Widget().grow(2) == 3; }",

     );

def _merge_probe_parity(np: any) -> str {
    import from jaclang.jac0core.parser.lexer { tokenize_full }
    import from jaclang.jac0core.parser.parser { Parser }
    import from jaclang.jac0core.passes.annex_pass { JacAnnexPass }
    import from jaclang.compiler.passes.tool.unparse_pass { unparse_node }

    nl = chr(10);
    main_src = nl.join(list(_MERGE_PROBE_MAIN));
    annex_src = nl.join(list(_MERGE_PROBE_ANNEX));
    main_path = "__seal_merge_probe__.jac";
    annex_path = "__seal_merge_probe__.impl.jac";
    sys.stderr.write("    canary: mat_merge_probe (native annex merge)\n");
    sys.stderr.flush();
    (merged, m_errs, a_errs) = np.merge_probe(
        main_src, main_path, annex_src, annex_path
    );
    if m_errs or a_errs {
        return (
            f"merge probe: the probe sources did not parse cleanly "
            f"(main {m_errs}, annex {a_errs} error(s))"
        );
    }
    (mt, _mc, _mld, _mle) = tokenize_full(main_src, main_path);
    py_main = Parser(tokens=mt, file_path=main_path, source_code=main_src).parse();
    (at, _ac, _ald, _ale) = tokenize_full(annex_src, annex_path);
    py_annex = Parser(tokens=at, file_path=annex_path, source_code=annex_src).parse();
    JacAnnexPass._merge_annex(py_main, py_annex);
    if len(merged.body) != len(py_main.body) {
        return (
            f"merge probe: woven body lengths diverged (native "
            f"{len(merged.body)} vs bytecode {len(py_main.body)})"
        );
    }
    native_up = unparse_node(merged);
    py_up = unparse_node(py_main);
    if native_up != py_up {
        return _parity_text_report("mat_merge_probe", native_up, py_up);
    }
    return "";
}

glob _JCIR_PROBE_LINES: tuple[str, ...] = (
         "\"\"\"Container probe.\"\"\"",
         "# a comment the crossing must not move",
         "glob seeded: int = 1;",
         "",
         "def widen(n: int) -> int {",
         "    total = n + seeded;  # a trailing comment",
         "    return total;",
         "}",
         "",
         "test \"a string named probe\" { assert widen(1) == 2; }",
         "",
         "with entry { widened = widen(2); }",

     );

def _jcir_code_field_diffs(a: any, b: any, at: str, out: list[str]) -> list[str] {
    import types;
    for attr in (
        "co_name",
        "co_qualname",
        "co_filename",
        "co_firstlineno",
        "co_argcount",
        "co_posonlyargcount",
        "co_kwonlyargcount",
        "co_nlocals",
        "co_stacksize",
        "co_flags",
        "co_code",
        "co_names",
        "co_varnames",
        "co_freevars",
        "co_cellvars",
        "co_linetable",
        "co_exceptiontable"
    ) {
        av = getattr(a, attr, None);
        bv = getattr(b, attr, None);
        if av != bv {
            out.append(f"{at}.{attr}: reference {av!r} vs crossing {bv!r}");
        }
    }
    if len(a.co_consts) != len(b.co_consts) {
        out.append(f"{at}.co_consts length {len(a.co_consts)} vs {len(b.co_consts)}");
        return out;
    }
    for (i, (x, y)) in enumerate(zip(a.co_consts, b.co_consts)) {
        if (isinstance(x, types.CodeType) and isinstance(y, types.CodeType)) {
            _jcir_code_field_diffs(x, y, f"{at}.consts[{i}]", out);
        } elif (x != y or type(x) is not type(y)) {
            out.append(f"{at}.consts[{i}]: reference {x!r} vs crossing {y!r}");
        }
    }
    return out;
}

def seal_jcir_container_canary(lib_path: str) -> str {
    import ast as pyast;
    import traceback;
    import from jaclang.jac0core.codegen_shim { transcribe }
    import from jaclang.jac0core.compile_options { CompileOptions, env_na_debug }
    import from jaclang.jac0core.passes.jcir_gen_pass { JcirGenPass }
    import from jaclang.jac0core.program { JacProgram }

    nl = chr(10);
    probe_path = "__seal_jcir_probe__.jac";
    probe_src = nl.join(list(_JCIR_PROBE_LINES));
    sys.stderr.write(
        f"    canary: jcir container crossing in {os.path.basename(lib_path)}{nl}"
    );
    sys.stderr.flush();
    blobs: list[bytes] = [];
    trees: list[any] = [];
    for _round in (0, 1) {
        prog = JacProgram();
        try {
            mod = prog.compile(
                use_str=probe_src,
                file_path=probe_path,
                options=CompileOptions(
                    force_codespace="server",
                    skip_native_engine=True,
                    no_ir_cache=True,
                    suppress_codes=["E5092"]
                )
            );
        } except Exception as probe_exc {
            if env_na_debug() {
                traceback.print_exc(file=sys.stderr);
            }
            return (
                f"the probe did not compile: "
                f"{type(probe_exc).__name__}: {probe_exc}"
            );
        }
        if prog.errors_had {
            return (
                f"the probe did not compile cleanly: "
                f"{[str(e) for e in prog.errors_had][:3]}"
            );
        }
        blobs.append(JcirGenPass(ir_in=mod, prog=prog).ir_bytes());
        trees.append(mod.gen.py_ast[0]);
    }
    if blobs[0] != blobs[1] {
        return (
            f"the container is not byte stable: two emissions of the probe "
            f"produced {len(blobs[0])} and {len(blobs[1])} bytes that differ. "
            "The container is what crosses the boundary and what a cache keys "
            "on, so an unstable encoding cannot ship."
        );
    }
    (mods, diags) = transcribe(blobs[0]);
    if diags {
        return f"the probe container carried unexpected diagnostics: {diags}";
    }
    if len(mods) != 1 or mods[0][0] != probe_path {
        return f"the probe container carried {len(mods)} module(s), not the probe";
    }
    want = pyast.dump(trees[0], include_attributes=True);
    got = pyast.dump(mods[0][1], include_attributes=True);
    if want != got {
        i = 0;
        n = min(len(want), len(got));
        while (i < n and want[i] == got[i]) {
            i += 1;
        }
        lo = max(0, i - 120);
        return (
            f"the crossing lost fidelity at offset {i}{nl}"
            f"want: ...{want[lo:i + 200]}{nl}"
            f"got:  ...{got[lo:i + 200]}"
        );
    }
    ref_code = compile(trees[0], probe_path, "exec");
    got_code = compile(mods[0][1], probe_path, "exec");
    code_diffs = _jcir_code_field_diffs(ref_code, got_code, "<module>", []);
    if code_diffs {
        return (
            f"{len(code_diffs)} code object field(s) diverged across the "
            f"crossing:{nl}"
            + nl.join(f"    {d}" for d in code_diffs[:10])
        );
    }
    return "";
}

def _sym_name_fingerprint(mod: any) -> list[str] {
    import jaclang.jac0core.unitree as uni;
    out: list[str] = [];
    for nd in mod._in_mod_nodes {
        `entry = "";
        if isinstance(nd, uni.AstSymbolNode) {
            try {
                `entry = f"{type(nd).__name__}:{nd.sym_name}";
            } except Exception as sym_exc {
                `entry = f"{type(nd).__name__}:<{type(sym_exc).__name__}>";
            }
        }
        if "body" in nd.__dict__ {
            nd_body = nd.__dict__.get("body");
            body_shape = f"list:{len(nd_body)}"
                if isinstance(nd_body, (list, tuple))
                else ("none" if nd_body is None else f"node:{type(nd_body).__name__}");
            `entry = f"{`entry or type(nd).__name__}|body={body_shape}";
        }
        if isinstance(nd, uni.NameAtom) {
            nd_spec = nd.__dict__.get("name_spec");
            spec_shape = "self"
                if nd_spec is nd
                else (
                    "none"
                        if nd_spec is None
                        else f"{type(nd_spec).__name__}:{getattr(nd_spec, 'value', '')}"
                );
            `entry = f"{`entry or type(nd).__name__}|spec={spec_shape}";
        }
        if `entry {
            out.append(`entry);
        }
    }
    return out;
}

def _native_lib_filename(stem: str) -> str {
    if sys.platform.startswith("win") {
        return f"jac_{stem}.dll";
    }
    if sys.platform == "darwin" {
        return f"libjac_{stem}.dylib";
    }
    return f"libjac_{stem}.so";
}

glob NATIVE_SEAL_INDEX_NAME: str = "SEAL_INDEX.json",
     NATIVE_SEAL_INDEX_FORMAT: int = 1;

def seal_index_path(precompiled_dir: Path, triple: str) -> Path {
    return precompiled_dir / "native" / triple / NATIVE_SEAL_INDEX_NAME;
}

def read_seal_index(precompiled_dir: Path, triple: str) -> dict[str, dict[str, any]] {
    try {
        doc = json.loads(
            seal_index_path(precompiled_dir, triple).read_text(encoding="utf-8")
        );
    } except Exception {
        return {};
    }
    if not isinstance(doc, dict)
        or doc.get("format") != NATIVE_SEAL_INDEX_FORMAT
        or doc.get("triple") != triple {
        return {};
    }
    recorded = doc.get("artifacts");
    if not isinstance(recorded, dict) {
        return {};
    }
    return {
        k: v
        for (k, v) in recorded.items()
        if isinstance(v, dict)
    };
}

def write_seal_index(
    precompiled_dir: Path, triple: str, records: dict[str, dict[str, any]]
) {
    path = seal_index_path(precompiled_dir, triple);
    path.parent.mkdir(parents=True, exist_ok=True);
    path.write_text(
        json.dumps(
            {
                "format": NATIVE_SEAL_INDEX_FORMAT,
                "triple": triple,
                "artifacts": records
            },
            sort_keys=True,
            indent=1
        )
            + "\n",
        encoding="utf-8"
    );
}

def seal_closure_sources(root_src: Path, deps: (list[str] | None) = None) -> list[str] {
    base = root_src.resolve().parent;
    found: list[str] = [str(root_src.resolve())];
    for raw in (deps or []) {
        if not raw {
            continue;
        }
        dep = Path(raw);
        if not dep.is_absolute() {
            dep = base / raw;
        }
        if dep.is_file() {
            found.append(str(dep.resolve()));
        }
    }
    return sorted(set(found));
}

def seal_source_label(pkg_path: Path, path: Path) -> str {
    try {
        return path.resolve().relative_to(Path(pkg_path).resolve()).as_posix();
    } except ValueError {
        return path.resolve().as_posix();
    }
}

def seal_source_keys(pkg_path: Path, paths: list[str]) -> (dict[str, str] | None) {
    import from jaclang.jac0core.jir { module_cache_key }
    pkg_root = Path(pkg_path).resolve();
    keys: dict[str, str] = {};
    for raw in sorted(set(paths)) {
        if not raw {
            continue;
        }
        src = Path(raw);
        if not src.is_absolute() {
            src = pkg_root / raw;
        }
        if not src.is_file() {
            return None;
        }
        try {
            keys[seal_source_label(pkg_path, src)] = module_cache_key(str(src));
        } except Exception {
            return None;
        }
    }
    return keys or None;
}

def seal_artifact_key(rel: str, triple: str, source_keys: dict[str, str]) -> str {
    h = hashlib.sha256();
    h.update(f"{NATIVE_SEAL_INDEX_FORMAT}|{rel}|{triple}".encode());
    for (label, key) in sorted(source_keys.items()) {
        h.update(f"|{label}={key}".encode());
    }
    return h.hexdigest();
}

def seal_waiver_digest(
    rel: str, waivers: (dict[str, tuple[str, ...]] | None) = None
) -> str {
    (qualified, _bare) = seal_waiver_names(rel, waivers);
    h = hashlib.sha256();
    for name in sorted(qualified) {
        h.update(f"{name}|".encode());
    }
    return h.hexdigest();
}

def seal_reuse_decision(
    record: (dict[str, any] | None),
    precompiled_dir: Path,
    rel: str,
    triple: str,
    identity: str,
    waiver_digest: str,
    source_keys: (dict[str, str] | None)
) -> str {
    if not record {
        return "no artifact for it is recorded in the seal index";
    }
    if record.get("triple") != triple {
        return f"it was built for {record.get('triple')!r}, not {triple!r}";
    }
    if record.get("compiler") != identity {
        return "the compiler that built it is not the one running now";
    }
    if record.get("waivers") != waiver_digest {
        return "its demotion waiver table changed, so the seal gate must re-run";
    }
    recorded = record.get("sources");
    if not isinstance(recorded, dict) or not recorded {
        return "the index records no source closure for it";
    }
    if source_keys is None {
        return "a source in its recorded closure is gone or unreadable";
    }
    changed = sorted(
        label
        for label in recorded
        if recorded.get(label) != source_keys.get(label)
    );
    if changed {
        shown = ", ".join(changed[:4]);
        more = f" and {len(changed) - 4} more" if len(changed) > 4 else "";
        return f"{len(changed)} closure source(s) changed: {shown}{more}";
    }
    if record.get("key") != seal_artifact_key(rel, triple, source_keys) {
        return "its recorded input key does not match the closure on disk";
    }
    for (path_field, sha_field) in (
        ("lib", "lib_sha256"),
        ("layout", "layout_sha256")
    ) {
        rel_out = record.get(path_field);
        if not rel_out {
            return f"the index records no {path_field} path for it";
        }
        out_file = precompiled_dir / str(rel_out);
        if not out_file.is_file() {
            return f"its {path_field} is missing from the output tree";
        }
        if hashlib.sha256(out_file.read_bytes()).hexdigest() != record.get(sha_field) {
            return f"its {path_field} on disk does not match the recorded sha256";
        }
    }
    return "";
}

def seal_export_symbols(
    layout_dict: dict[str, any], clib_symbols: any = None
) -> list[str] {
    clib = set(clib_symbols or ());
    names = {
        fn_name
        for fn_name in (layout_dict.get("functions") or {})
        if fn_name not in clib
    };
    for struct_def in (layout_dict.get("structs") or {}).values() {
        for kinds in (struct_def.get("accessors") or {}).values() {
            names.update(kinds.values());
        }
    }
    return sorted(names);
}

glob PRECOMPILED_KEEP_DIRS: tuple[str, ...] = ("native", );

def prune_stale_precompiled_dirs(precompiled_dir: Path, pyver: str) -> int {
    removed = 0;
    for stale_dir in sorted(precompiled_dir.iterdir()) {
        if not stale_dir.is_dir()
            or stale_dir.name == pyver
            or stale_dir.name in PRECOMPILED_KEEP_DIRS {
            continue;
        }
        shutil.rmtree(stale_dir, ignore_errors=True);
        removed += 1;
    }
    return removed;
}

def prune_native_outputs(precompiled_dir: Path, triple: str, keep: set[str]) -> int {
    native_root = precompiled_dir / "native";
    if not native_root.is_dir() {
        return 0;
    }
    index_rel = seal_index_path(precompiled_dir, triple).relative_to(
        precompiled_dir
    ).as_posix();
    removed = 0;
    for found in sorted(native_root.rglob("*")) {
        if not found.is_file() {
            continue;
        }
        rel_out = found.relative_to(precompiled_dir).as_posix();
        if rel_out in keep or rel_out == index_rel {
            continue;
        }
        found.unlink(missing_ok=True);
        removed += 1;
    }
    for found in sorted(native_root.rglob("*"), reverse=True) {
        if found.is_dir() and not any(found.iterdir()) {
            found.rmdir();
        }
    }
    return removed;
}

def seal_native_roots(
    pkg_path: Path,
    precompiled_dir: Path,
    modules: (tuple[str, ...] | None) = None,
    waivers: (dict[str, tuple[str, ...]] | None) = None,
    canary_reused: bool = True,
    unitree_layout: (dict[str, any] | None) = None,
    index_out: (dict[str, dict[str, any]] | None) = None
) -> (dict[str, dict[str, any]] | None) {
    artifacts: dict[str, dict[str, any]] = {};
    if sys.platform.startswith("win") {
        stale_native = precompiled_dir / "native";
        if stale_native.is_dir() {
            shutil.rmtree(stale_native, ignore_errors=True);
        }
        return artifacts;
    }
    import from jaclang.jac0core.jir { cache_mode }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.jac0core.codeinfo { native_layout_to_dict }
    import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
    import from jaclang.compiler.passes.native.shared_emit { emit_shared_library }
    import jaclang.compiler.passes.native.llvm.binding as llvm;

    pkg_name = pkg_path.name;
    triple = llvm.get_default_triple();
    out_dir = precompiled_dir / "native" / triple;
    identity = compiler_identity();
    (forced_rebuild, _no_precompile) = cache_mode();
    index = {} if forced_rebuild else read_seal_index(precompiled_dir, triple);
    fresh_index: dict[str, dict[str, any]] = dict(index);
    kept: dict[str, dict[str, any]] = {};
    _seal_layouts: dict[str, dict[str, any]] = {};
    if unitree_layout is not None {
        _seal_layouts[NATIVE_SEAL_UNITREE_ROOT] = unitree_layout;
    }
    _mat_manifest: (dict[str, any] | None) = None;
    _gen_root_src: (Path | None) = None;
    for rel in (NATIVE_SEAL_ROOTS if modules is None else modules) {
        src: Path = pkg_path / str(rel);
        if rel == NATIVE_SEAL_MATERIALIZE_ROOT {
            unitree_layout = _seal_layouts.get(NATIVE_SEAL_UNITREE_ROOT);
            if unitree_layout is None {
                console.error(
                    "NATIVE SEAL: the materializer root is generated from "
                    "the unitree layout; seal jac0core/unitree.jac first "
                    "(NATIVE_SEAL_ROOTS order, or include it in the "
                    "modules argument)."
                );
                return None;
            }
            import from jaclang.utils.gen_native_materialize {
                generate as generate_materialize_root
            }

            _mat_manifest = generate_materialize_root(
                unitree_layout, src, _UNITREE_SEAM_WAIVERS
            );
            for _mat_warn in (_mat_manifest.pop("warnings", None) or []) {
                console.warning(
                    f"NATIVE SEAL: the materializer erased a slot: {_mat_warn}. "
                    "The Python side must reconstruct it (postinit or a lazy "
                    "accessor) or the materialized tree loses that value."
                );
            }
            _gen_root_src = src;
        }
        if not src.is_file() {
            console.error(f"NATIVE SEAL: missing source {src}");
            return None;
        }
        stem = ext_registry.base_stem(os.path.basename(rel));
        parts = [
            p
            for p in os.path.dirname(rel).split("/")
            if p
        ];
        fullname = ".".join([pkg_name] + parts + [stem]);
        lib_path = out_dir / _native_lib_filename(stem);
        layout_path = out_dir / f"{stem}.layout.json";
        waiver_digest = seal_waiver_digest(rel, waivers);
        record = index.get(rel);
        why = "a full rebuild was requested (JAC_REBUILD)";
        if not forced_rebuild {
            why = seal_reuse_decision(
                record,
                precompiled_dir,
                rel,
                triple,
                identity,
                waiver_digest,
                seal_source_keys(pkg_path, sorted((record or {}).get("sources") or {}))
            );
        }
        if not why and record is not None {
            reuse_lib = precompiled_dir / str(record["lib"]);
            reuse_layout = precompiled_dir / str(record["layout"]);
            reused_layout: (dict[str, any] | None) = None;
            try {
                reused_layout = json.loads(reuse_layout.read_text(encoding="utf-8"));
            } except Exception as _layout_exc {
                why = f"its layout could not be read back: {_layout_exc}";
            }
            if reused_layout is not None {
                reused_exports = seal_export_symbols(
                    reused_layout, record.get("clib_symbols")
                );
                canary = "";
                if canary_reused {
                    canary = seal_native_canary(str(reuse_lib), reused_exports);
                    if not canary and rel == NATIVE_SEAL_MATERIALIZE_ROOT {
                        canary = seal_parse_parity_canary(
                            str(reuse_lib), reused_layout
                        );
                    }
                    if not canary and rel == NATIVE_SEAL_MATERIALIZE_ROOT {
                        canary = seal_prefix_parity_canary(
                            str(reuse_lib), reused_layout
                        );
                    }
                }
                if canary {
                    why = f"its canary no longer passes: {canary}";
                } else {
                    _seal_layouts[rel] = reused_layout;
                    artifacts[fullname] = {
                        "lib": record["lib"],
                        "layout": record["layout"],
                        "triple": triple,
                        "lib_sha256": record["lib_sha256"],
                        "layout_sha256": record["layout_sha256"]
                    };
                    kept[rel] = record;
                    fresh_index[rel] = record;
                    if _gen_root_src is not None
                        and rel == NATIVE_SEAL_MATERIALIZE_ROOT {
                        _gen_root_src.unlink(missing_ok=True);
                        _gen_root_src = None;
                    }
                    console.print(
                        f"  Native artifact: {fullname} -> {reuse_lib.name} "
                        f"reused ({reuse_lib.stat().st_size:,} bytes, "
                        f"{len(reused_exports)} exports)"
                    );
                    continue;
                }
            }
        }
        console.print(f"  Building {rel}: {why}.");
        prog = JacProgram();
        na_coverage_begin();
        try {
            ir = prog.compile(
                file_path=str(src),
                options=CompileOptions(
                    aot_mode=True,
                    type_check=False,
                    force_codespace='native',
                    force_target_program=True,
                    na_gc_mode='cycles',
                    no_ir_cache=True
                )
            );
        } finally {
            coverage = na_coverage_end();
        }
        closure_deps: list[str] = [];
        if ir is not None and ir.gen.interop_manifest is not None {
            closure_deps = list(ir.gen.interop_manifest.native_transitive_sources);
        }
        if prog.errors_had {
            for _err in prog.errors_had {
                console.error(f"NATIVE SEAL: {_err.pretty_print()}");
            }
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        if ir is None or ir.gen.llvm_ir is None or ir.gen.native_layout is None {
            console.error(f"NATIVE SEAL: no native IR/layout for {rel}");
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        manifest = ir.gen.interop_manifest;
        if manifest is not None and manifest.native_imports {
            console.error(
                f"NATIVE SEAL: {rel} has Python-side imports; artifact would "
                "need in-process callbacks and cannot be sealed AOT."
            );
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        (demotion_error, waived, stale_waivers) = seal_demotion_report(
            rel, coverage, waivers, pkg_path
        );
        if demotion_error {
            console.error(demotion_error);
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        for name in waived {
            console.warning(
                f"NATIVE SEAL: {rel} ships {name} as an abort stub -- waived by "
                "NATIVE_SEAL_DEMOTION_WAIVERS. Calling it in a sealed build "
                "aborts the process."
            );
        }
        for name in stale_waivers {
            console.warning(
                f"NATIVE SEAL: {rel} waives {name}, which did not demote; drop "
                "the stale entry from NATIVE_SEAL_DEMOTION_WAIVERS."
            );
        }
        llvm_ir_text = str(ir.gen.llvm_ir);

        (_qualified, allowed_bare) = seal_waiver_names(rel, waivers);

        allowed_stub_names: set[str] = set(allowed_bare);
        reg = ir.gen.layout_registry;
        if reg is not None {
            for bare in allowed_bare {
                (owner, dot, meth) = bare.partition(".");
                if not dot {
                    continue;
                }
                for (cls, mro) in reg.mro_order.items() {
                    if owner in mro {
                        allowed_stub_names.add(f"{cls}.{meth}");
                    }
                }
            }
        }
        shipped_stubs = [
            s
            for s in seal_abort_stubs(llvm_ir_text)
            if s not in allowed_stub_names
        ];
        if shipped_stubs {
            console.error(
                f"NATIVE SEAL: {rel} would link {len(shipped_stubs)} abort "
                f"stub(s) into its artifact: {', '.join(shipped_stubs)}. This is "
                "read off the IR that actually ships, so it holds even when the "
                "native coverage recorded nothing (a stale native IR cache serves "
                "a demoted dependency without re-running codegen). The cached IR "
                "for this closure has been purged; re-run the seal to recompile "
                "it and get the per-method diagnostic."
            );
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        layout = ir.gen.native_layout;

        _clib_syms = set((ir.gen._clib_symbol_lib or {}).keys());
        exports = sorted(
            fn_name
            for fn_name in layout.functions.keys()
            if fn_name not in _clib_syms
        );
        if not exports {
            console.error(f"NATIVE SEAL: {rel} exports no module functions");
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }

        layout_dict = native_layout_to_dict(layout);
        _seal_layouts[rel] = layout_dict;
        if rel == NATIVE_SEAL_MATERIALIZE_ROOT and _mat_manifest is not None {
            layout_dict["materialize_manifest"] = _mat_manifest;
        }
        _stub_syms = set(seal_abort_stubs(llvm_ir_text));
        for _sd in layout_dict["structs"].values() {
            _live = {
                _fname: {
                    _kind: _sym
                    for (_kind, _sym) in _kinds.items()
                    if _sym not in _stub_syms
                } for (_fname, _kinds) in (_sd.get("accessors") or {}).items()
            };
            _sd["accessors"] = {
                _fname: _kinds
                for (_fname, _kinds) in _live.items()
                if _kinds
            };
        }
        exports = seal_export_symbols(layout_dict, _clib_syms);
        out_dir.mkdir(parents=True, exist_ok=True);
        lib_path.unlink(missing_ok=True);
        layout_path.unlink(missing_ok=True);
        (ok, err) = emit_shared_library(
            str(ir.gen.llvm_ir),
            manifest,
            exports,
            str(lib_path),
            clib_paths=list(ir.gen._clib_paths or []),
            clib_symbol_lib=dict(ir.gen._clib_symbol_lib or {})
        );
        if not ok {
            console.error(f"NATIVE SEAL: {rel}: {err}");
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        canary = seal_native_canary(str(lib_path), exports);
        if canary {
            console.error(
                f"NATIVE SEAL: {rel}: the emitted artifact "
                f"{lib_path.name} failed its load canary: {canary}. The seal "
                "refuses artifacts it cannot load and call; set JAC_NA_DEBUG=1 "
                "for the traceback."
            );
            lib_path.unlink(missing_ok=True);
            purge_native_ir_cache(str(src), closure_deps);
            return None;
        }
        layout_path.write_text(
            json.dumps(layout_dict, sort_keys=True) + "\n", encoding="utf-8"
        );
        if rel == NATIVE_SEAL_JCIR_ROOT {
            crossing = seal_jcir_container_canary(str(lib_path));
            if crossing {
                console.error(
                    f"NATIVE SEAL: {rel}: the emitted artifact "
                    f"{lib_path.name} failed its container crossing canary. "
                    "The seal refuses a JCIR producer whose container is not "
                    "byte stable or whose crossing is lossy; set "
                    f"JAC_NA_DEBUG=1 for the traceback.{chr(10)}{crossing}"
                );
                lib_path.unlink(missing_ok=True);
                layout_path.unlink(missing_ok=True);
                purge_native_ir_cache(str(src), closure_deps);
                return None;
            }
        }
        if rel == NATIVE_SEAL_MATERIALIZE_ROOT {
            parity = seal_parse_parity_canary(str(lib_path), layout_dict);
            if not parity {
                parity = seal_prefix_parity_canary(str(lib_path), layout_dict);
            }
            if parity {
                console.error(
                    f"NATIVE SEAL: {rel}: the emitted artifact "
                    f"{lib_path.name} failed its parity canaries. The seal "
                    "refuses artifacts whose parse or prefix does not match "
                    "the staged route; set JAC_NA_DEBUG=1 for the full "
                    f"unparsed texts and the traceback.{chr(10)}{parity}"
                );
                lib_path.unlink(missing_ok=True);
                layout_path.unlink(missing_ok=True);
                purge_native_ir_cache(str(src), closure_deps);
                return None;
            }
        }
        artifacts[fullname] = {
            "lib": lib_path.relative_to(precompiled_dir).as_posix(),
            "layout": layout_path.relative_to(precompiled_dir).as_posix(),
            "triple": triple,
            "lib_sha256": hashlib.sha256(lib_path.read_bytes()).hexdigest(),
            "layout_sha256": hashlib.sha256(layout_path.read_bytes()).hexdigest()
        };
        built_keys = seal_source_keys(
            pkg_path, seal_closure_sources(src, closure_deps)
        );
        if built_keys is not None {
            new_record = dict(artifacts[fullname]);
            new_record["key"] = seal_artifact_key(rel, triple, built_keys);
            new_record["compiler"] = identity;
            new_record["waivers"] = waiver_digest;
            new_record["module"] = fullname;
            new_record["clib_symbols"] = sorted(_clib_syms);
            new_record["sources"] = built_keys;
            fresh_index[rel] = new_record;
            kept[rel] = new_record;
        } else {
            fresh_index.pop(rel, None);
        }
        if index_out is None {
            write_seal_index(precompiled_dir, triple, fresh_index);
        }
        if _gen_root_src is not None and rel == NATIVE_SEAL_MATERIALIZE_ROOT {
            _gen_root_src.unlink(missing_ok=True);
            _gen_root_src = None;
        }
        console.print(
            f"  Native artifact: {fullname} -> {lib_path.name} "
            f"({lib_path.stat().st_size:,} bytes, {len(exports)} exports)"
        );
    }
    if index_out is not None {
        index_out.update(kept);
        return artifacts;
    }
    write_seal_index(precompiled_dir, triple, kept);
    live: set[str] = set();
    for rec in kept.values() {
        live.add(str(rec["lib"]));
        live.add(str(rec["layout"]));
    }
    prune_native_outputs(precompiled_dir, triple, live);
    return artifacts;
}

glob NATIVE_SEAL_JOBS_ENV: str = "JAC_SEAL_JOBS",
     NATIVE_SEAL_WORKER_ENV: str = "JAC_SEAL_WORKER_REQUEST",
     NATIVE_SEAL_WORKER_PATH_ENV: str = "JAC_SEAL_WORKER_SYS_PATH";

glob NATIVE_SEAL_ROOT_BUDGET_GIB: float = 4.5;

glob NATIVE_SEAL_DARWIN_RESERVE_GIB: float = 2.0;

def seal_mem_available_gib -> float {
    try {
        for line in Path("/proc/meminfo").read_text(encoding="utf-8").splitlines() {
            if line.startswith("MemAvailable:") {
                return float(line.split()[1]) / 1048576.0;
            }
        }
    } except Exception { }
    try {
        return float(os.sysconf("SC_AVPHYS_PAGES") * os.sysconf("SC_PAGE_SIZE"))
            / 1073741824.0;
    } except Exception { }
    if sys.platform == "darwin" {
        try {
            total = float(os.sysconf("SC_PHYS_PAGES") * os.sysconf("SC_PAGE_SIZE"))
                / 1073741824.0;
            return max(0.0, total - NATIVE_SEAL_DARWIN_RESERVE_GIB);
        } except Exception { }
    }
    return 0.0;
}

def seal_jobs_override -> (int | None) {
    raw = os.environ.get(NATIVE_SEAL_JOBS_ENV, "").strip();
    if raw {
        try {
            return max(1, int(raw));
        } except ValueError { }
    }
    return None;
}

def seal_jobs(requested: (int | None) = None) -> int {
    if requested is not None {
        return max(1, int(requested));
    }
    `override = seal_jobs_override();
    if `override is not None {
        return `override;
    }
    avail = seal_mem_available_gib();
    if avail <= 0.0 {
        return 1;
    }
    return max(1, min(os.cpu_count() or 1, int(avail / NATIVE_SEAL_ROOT_BUDGET_GIB)));
}

glob _SEAL_WORKER_BOOT: str = "\n".join(
         (
             "import json, os, sys",
             f"_pp = [p for p in json.loads(os.environ['{NATIVE_SEAL_WORKER_PATH_ENV}']) if p]",
             "sys.path[:] = _pp + [p for p in sys.path if p and p not in _pp]",
             "try:",
             "    import _jac_finder",
             "    _jac_finder.install()",
             "except Exception:",
             "    pass",
             "import jaclang.utils.precompile_bytecode as _pb",
             "sys.argv = ['precompile_bytecode']",
             "_pb.main()"
         )
     );

def seal_jaclang_root -> str {
    try {
        pkg_root = Path(str(__file__)).resolve().parent.parent;
        return str(pkg_root) if (pkg_root / "jac0core").is_dir() else "";
    } except Exception {
        return "";
    }
}

def seal_worker_spec(
    pkg_path: Path,
    precompiled_dir: Path,
    waivers: (dict[str, tuple[str, ...]] | None),
    canary_reused: bool,
    identity: str
) -> dict[str, any] {
    return {
        "pkg_path": str(pkg_path),
        "precompiled_dir": str(precompiled_dir),
        "canary_reused": bool(canary_reused),
        "waivers": (
            None if waivers is None else {k: list(v) for (k, v) in waivers.items()}
        ),
        "compiler": identity,
        "jaclang_root": seal_jaclang_root()
    };
}

def _seal_worker_job(
    spec: dict[str, any], work_dir: str, rel: str, unitree_layout: (str | None)
) -> dict[str, str] {
    slug = rel.replace("/", "__").replace(".", "_");
    request = os.path.join(work_dir, f"{slug}.request.json");
    result = os.path.join(work_dir, f"{slug}.result.json");
    payload = dict(spec);
    payload["rel"] = rel;
    payload["unitree_layout"] = unitree_layout;
    payload["result"] = result;
    Path(request).write_text(json.dumps(payload), encoding="utf-8");
    return {"rel": rel, "request": request, "result": result};
}

def seal_worker_env(request_path: str) -> dict[str, str] {
    env = dict(os.environ);
    env[NATIVE_SEAL_WORKER_ENV] = request_path;
    env[NATIVE_SEAL_JOBS_ENV] = "1";
    paths = [p or os.getcwd() for p in sys.path];
    jac_root = seal_jaclang_root();
    if jac_root {
        home = os.path.dirname(jac_root);
        paths = [home]
            + [
                p
                for p in paths
                if p != home
            ];
        if os.environ.get("JAC_DEV_SOURCE") != home {
            env["JAC_NO_DEV_SOURCE"] = "1";
        }
    }
    env[NATIVE_SEAL_WORKER_PATH_ENV] = json.dumps(paths);
    return env;
}

def seal_worker_argv -> list[str] {
    argv = [sys.executable];
    if sys.flags.no_site {
        argv.append("-S");
    }
    return argv + ["-c", _SEAL_WORKER_BOOT];
}

def _seal_worker_exec(job: dict[str, str]) -> dict[str, any] {
    import subprocess;
    import time;

    rel = str(job["rel"]);
    env = seal_worker_env(str(job["request"]));
    argv = seal_worker_argv();
    started = time.monotonic();
    proc = subprocess.run(
        argv, env=env, capture_output=True, text=True, errors="replace"
    );
    out: dict[str, any] = {
        "rel": rel,
        "ok": False,
        "skipped": False,
        "artifacts": {},
        "records": {},
        "error": "",
        "stdout": proc.stdout or "",
        "stderr": proc.stderr or "",
        "seconds": time.monotonic() - started
    };
    landed: (dict[str, any] | None) = None;
    try {
        landed = json.loads(Path(str(job["result"])).read_text(encoding="utf-8"));
    } except Exception { }
    if isinstance(landed, dict) {
        out["ok"] = bool(landed.get("ok"));
        out["artifacts"] = landed.get("artifacts") or {};
        out["records"] = landed.get("records") or {};
        out["error"] = str(landed.get("error") or "");
    }
    if not out["ok"] and not out["error"] {
        out["error"] = (
            f"NATIVE SEAL: the worker sealing {rel} exited "
            f"{_seal_exit_reason(proc.returncode)} without writing a result. "
            "The result file is written after every caught failure, so the "
            "worker died in native code -- inside __jac_shared_init or the "
            "load canary, not in the seal's Python."
        );
    }
    return out;
}

def _seal_exit_reason(code: int) -> str {
    if code >= 0 {
        return f"with status {code}";
    }
    import signal;
    try {
        return f"on {signal.Signals(-code).name}";
    } except Exception {
        return f"on signal {-code}";
    }
}

def _seal_worker_run(
    job: dict[str, str], gate: any, state: dict[str, bool]
) -> dict[str, any] {
    gate.acquire();
    try {
        if state.get("failed") {
            return {
                "rel": str(job["rel"]),
                "ok": False,
                "skipped": True,
                "artifacts": {},
                "records": {},
                "error": "",
                "stdout": "",
                "stderr": "",
                "seconds": 0.0
            };
        }
        result = _seal_worker_exec(job);
    } except Exception as exc {
        result = {
            "rel": str(job["rel"]),
            "ok": False,
            "skipped": False,
            "artifacts": {},
            "records": {},
            "error": (
                f"NATIVE SEAL: the worker sealing {job['rel']} could not be "
                f"supervised: {type(exc).__name__}: {exc}"
            ),
            "stdout": "",
            "stderr": "",
            "seconds": 0.0
        };
    } finally {
        gate.release();
    }
    if not result["ok"] {
        state["failed"] = True;
    }
    return result;
}

def _seal_dispatch(job: dict[str, str], gate: any, state: dict[str, bool]) -> any {
    return flow _seal_worker_run(job, gate, state) ;
}

def _seal_replay(result: dict[str, any]) {
    out = str(result.get("stdout") or "");
    err = str(result.get("stderr") or "");
    sink = sys.stdout if result.get("ok") else sys.stderr;
    if out {
        sink.write(out);
        sink.flush();
    }
    if err {
        sys.stderr.write(err);
        sys.stderr.flush();
    }
}

def seal_native_pool(
    pkg_path: Path,
    precompiled_dir: Path,
    roots: list[str],
    waivers: (dict[str, tuple[str, ...]] | None),
    canary_reused: bool,
    jobs: int
) -> (dict[str, dict[str, any]] | None) {
    import tempfile;
    import threading;
    import from jaclang.jac0core.jir { cache_mode }
    import jaclang.compiler.passes.native.llvm.binding as llvm;

    triple = llvm.get_default_triple();
    identity = compiler_identity();
    (forced_rebuild, _no_precompile) = cache_mode();
    fresh_index: dict[str, dict[str, any]] = (
        {} if forced_rebuild else dict(read_seal_index(precompiled_dir, triple))
    );
    spec = seal_worker_spec(
        pkg_path, precompiled_dir, waivers, canary_reused, identity
    );
    work_dir = tempfile.mkdtemp(prefix="jac-seal-pool-");
    gate = threading.Semaphore(max(1, jobs));
    state: dict[str, bool] = {"failed": False};
    results: dict[str, dict[str, any]] = {};
    try {
        phase_a = [
            r
            for r in roots
            if r == NATIVE_SEAL_UNITREE_ROOT
        ];
        phase_b = [
            r
            for r in roots
            if r != NATIVE_SEAL_UNITREE_ROOT
        ];
        for rel in phase_a {
            console.print(
                f"  Seal phase 1/2: {rel} (the layout the materializer is "
                "generated from)"
            );
            results[rel] = _seal_worker_run(
                _seal_worker_job(spec, work_dir, rel, None), gate, state
            );
            landed = results[rel];
            _seal_replay(landed);
            fresh_index.update(landed.get("records") or {});
            write_seal_index(precompiled_dir, triple, fresh_index);
            if landed["ok"] {
                took = float(landed["seconds"]);
                console.print(f"  Sealed {rel} in {took:.1f}s");
            }
        }
        unitree_record = fresh_index.get(NATIVE_SEAL_UNITREE_ROOT);
        unitree_layout: (str | None) = None;
        if unitree_record is not None and unitree_record.get("layout") {
            candidate = precompiled_dir / str(unitree_record["layout"]);
            if candidate.is_file() {
                unitree_layout = str(candidate);
            }
        }
        if phase_b and not state["failed"] {
            console.print(
                f"  Seal phase 2/2: {len(phase_b)} root(s), {jobs} worker "
                "process(es) in flight"
            );
            handles: list[any] = [];
            for rel in phase_b {
                handles.append(
                    _seal_dispatch(
                        _seal_worker_job(
                            spec,
                            work_dir,
                            rel,
                            unitree_layout
                                if rel == NATIVE_SEAL_MATERIALIZE_ROOT
                                else None
                        ),
                        gate,
                        state
                    )
                );
            }
            for (rel, handle) in zip(phase_b, handles) {
                landed = wait handle ;
                results[rel] = landed;
                _seal_replay(landed);
                if landed.get("records") {
                    fresh_index.update(landed["records"]);
                    write_seal_index(precompiled_dir, triple, fresh_index);
                }
                if landed["ok"] {
                    took = float(landed["seconds"]);
                    console.print(f"  Sealed {rel} in {took:.1f}s");
                }
            }
        }
    } finally {
        shutil.rmtree(work_dir, ignore_errors=True);
    }

    artifacts: dict[str, dict[str, any]] = {};
    kept: dict[str, dict[str, any]] = {};
    refused: list[str] = [];
    drained: list[str] = [];
    for rel in roots {
        landed = results.get(rel);
        if landed is None or landed.get("skipped") {
            drained.append(rel);
            continue;
        }
        if not landed["ok"] {
            refused.append(rel);
            continue;
        }
        artifacts.update(landed["artifacts"]);
        kept.update(landed["records"]);
    }
    if refused or drained {
        for rel in refused {
            if results[rel].get("error") {
                console.error(str(results[rel]["error"]));
            }
        }
        if drained {
            console.error(
                f"NATIVE SEAL: {len(drained)} root(s) went unsealed because the "
                f"worker pool drained after the refusal above: "
                    + ", ".join(drained)
            );
        }
        return None;
    }
    write_seal_index(precompiled_dir, triple, kept);
    live: set[str] = set();
    for rec in kept.values() {
        live.add(str(rec["lib"]));
        live.add(str(rec["layout"]));
    }
    prune_native_outputs(precompiled_dir, triple, live);
    return artifacts;
}

def seal_native_artifacts(
    pkg_path: Path,
    precompiled_dir: Path,
    modules: (tuple[str, ...] | None) = None,
    waivers: (dict[str, tuple[str, ...]] | None) = None,
    canary_reused: bool = True,
    jobs: (int | None) = None
) -> (dict[str, dict[str, any]] | None) {
    if sys.platform.startswith("win") {
        return seal_native_roots(
            pkg_path, precompiled_dir, modules, waivers, canary_reused
        );
    }
    roots = [str(r) for r in (NATIVE_SEAL_ROOTS if modules is None else modules)];
    pooled = modules is None or jobs is not None;
    resolved = seal_jobs(jobs) if pooled else 1;
    asked_for_one = jobs is not None or seal_jobs_override() is not None;
    if not roots or not pooled or (resolved <= 1 and asked_for_one) {
        return seal_native_roots(
            pkg_path, precompiled_dir, modules, waivers, canary_reused
        );
    }
    console.print(
        f"  Native seal: {len(roots)} root(s) over up to {resolved} worker "
        f"process(es) (set {NATIVE_SEAL_JOBS_ENV}=1 for the sequential seal)"
    );
    return seal_native_pool(
        pkg_path, precompiled_dir, roots, waivers, canary_reused, resolved
    );
}

def seal_worker_main -> int {
    request_path = os.environ.get(NATIVE_SEAL_WORKER_ENV, "");

    os.environ.pop(NATIVE_SEAL_WORKER_ENV, None);
    request = json.loads(Path(request_path).read_text(encoding="utf-8"));
    rel = str(request["rel"]);
    payload: dict[str, any] = {
        "rel": rel,
        "ok": False,
        "artifacts": {},
        "records": {},
        "error": ""
    };
    try {
        wanted_root = str(request.get("jaclang_root") or "");
        running_root = seal_jaclang_root();
        if wanted_root and running_root and wanted_root != running_root {
            raise RuntimeError(
                f"the seal worker for {rel} imported jaclang from "
                f"{running_root}, not the {wanted_root} its parent is running. "
                "A worker that resolves a different tree brands every type in "
                "the closure differently from the sources it is sealing, which "
                "surfaces as same-name type mismatches rather than as this."
            );
        }
        wanted = str(request.get("compiler") or "");
        running = compiler_identity();
        if wanted and wanted != running {
            raise RuntimeError(
                f"the seal worker for {rel} is running compiler {running}, not "
                f"the {wanted} that dispatched it -- the worker resolved a "
                "different jaclang tree or compiler tier than its parent."
            );
        }
        raw_waivers = request.get("waivers");
        table = (
            None
                if raw_waivers is None
                else {k: tuple(v) for (k, v) in raw_waivers.items()}
        );
        layout: (dict[str, any] | None) = None;
        if request.get("unitree_layout") {
            layout = json.loads(
                Path(str(request["unitree_layout"])).read_text(encoding="utf-8")
            );
        }
        records: dict[str, dict[str, any]] = {};
        arts = seal_native_roots(
            Path(str(request["pkg_path"])),
            Path(str(request["precompiled_dir"])),
            modules=(rel, ),
            waivers=table,
            canary_reused=bool(request.get("canary_reused", True)),
            unitree_layout=layout,
            index_out=records
        );
        if arts is None {
            payload["error"] = (
                f"NATIVE SEAL: the worker sealing {rel} refused it; its "
                "diagnostic is printed above."
            );
        } else {
            payload["ok"] = True;
            payload["artifacts"] = arts;
            payload["records"] = records;
        }
    } except Exception as exc {
        import traceback;
        console.error(
            f"NATIVE SEAL: the worker sealing {rel} raised "
            f"{type(exc).__name__}: {exc}\n{traceback.format_exc()}"
        );
        payload["error"] = (
            f"NATIVE SEAL: the worker sealing {rel} raised "
            f"{type(exc).__name__}: {exc}"
        );
    }
    Path(str(request["result"])).write_text(
        json.dumps(payload) + "\n", encoding="utf-8"
    );
    sys.stdout.flush();
    sys.stderr.flush();
    return 0 if payload["ok"] else 1;
}

def jir_to_module(pkg_name: str, rel_jir: str) -> tuple[str, str, bool] {
    source_rel = rel_jir[:-4] + ".jac";
    name = os.path.basename(source_rel);
    parts = [
        p
        for p in os.path.dirname(source_rel).split("/")
        if p
    ];
    is_pkg = name in ext_registry.INIT_FILES;
    if is_pkg {
        fullname = ".".join([pkg_name] + parts);
    } else {
        fullname = ".".join([pkg_name] + parts + [ext_registry.base_stem(name)]);
    }
    return (source_rel, fullname, is_pkg);
}

def app_metadata(pkg_path: Path, pkg_name: str) -> dict[str, any] {
    if not (pkg_path / "jac.toml").is_file() {
        return {};
    }
    import from jaclang.project.config { get_config_for_path }
    import from jaclang.project.kinds { resolve_project_kind, resolve_entry }
    import from jaclang.runtimelib.sealed_serve { CLIENT_DIST_REL, NATIVE_DIR_REL }

    config = get_config_for_path(pkg_path);
    if config is None {
        return {};
    }
    entry_path = resolve_entry(config, str(pkg_path));
    kind = resolve_project_kind(config, entry_path);

    `entry: dict[str, str] = {};
    if entry_path and Path(entry_path).is_file() {
        rel = Path(entry_path).resolve().relative_to(pkg_path.resolve()).as_posix();
        stem = ext_registry.base_stem(os.path.basename(entry_path));
        `entry = {"module": f"{pkg_name}.{stem}", "path": rel};
    }

    caps: list[str] = [];
    if kind in ["service", "service-mesh", "web-app", "desktop", "mobile"] {
        caps.append("has-server");
    }
    if `entry {
        caps.append("has-entry");
    }
    if (pkg_path / CLIENT_DIST_REL).is_dir()
        or kind in ["web-app", "desktop", "mobile"] {
        caps.append("has-client");
    }
    if (pkg_path / NATIVE_DIR_REL).is_dir() {
        caps.append("has-native");
    }
    if kind in ["py-package", "js-package"] or not `entry {
        caps.append("attachable");
    }

    meta = {"kind": kind, "capabilities": caps, "entry": `entry};
    native_dir = pkg_path / NATIVE_DIR_REL;
    if native_dir.is_dir() {
        triples = sorted(
            [
                d.name
                for d in native_dir.iterdir()
                if d.is_dir()
            ]
        );
        if triples {
            caps.append("platform-locked");
            meta["triples"] = triples;
        }
    }
    return meta;
}

def collect_payloads(pkg_path: Path) -> dict[str, str] {
    import from jaclang.runtimelib.sealed_serve {
        SERVE_MANIFEST_REL,
        CLIENT_DIST_REL,
        NATIVE_DIR_REL
    }
    payloads: dict[str, str] = {};
    sm = pkg_path / SERVE_MANIFEST_REL;
    if sm.is_file() {
        payloads[Path(SERVE_MANIFEST_REL).as_posix()] = hashlib.sha256(
            sm.read_bytes()
        ).hexdigest();
    }
    for payload_dir in [pkg_path / CLIENT_DIST_REL, pkg_path / NATIVE_DIR_REL] {
        if not payload_dir.is_dir() {
            continue;
        }
        for f in sorted(payload_dir.rglob("*")) {
            if f.is_file() {
                payloads[f.relative_to(pkg_path).as_posix()] = hashlib.sha256(
                    f.read_bytes()
                ).hexdigest();
            }
        }
    }
    return payloads;
}

def seal_finalize(
    pkg_path: Path,
    precompiled_dir: Path,
    pkg_name: str,
    pyver: str,
    embed_src: bool,
    canary_reused: bool = True
) -> int {
    writes = (
        FORMAT_VERSION,
        HEADER_SIZE,
        SECTIONS_MAGIC,
        SEC_BYTECODE,
        SEC_DEBUG_SRC,
        PRECOMPILE_SENTINEL
    );
    reads = (
        SEALED_JIR_FORMAT_VERSION,
        SEALED_HEADER_SIZE,
        SEALED_SECTIONS_MAGIC,
        SEALED_SEC_BYTECODE,
        SEALED_SEC_DEBUG_SRC,
        SEALED_SENTINEL
    );
    if reads != writes {
        console.error(
            f"JIR format drift: jir.jac writes {writes} but sealed.py "
            f"reads {reads}. Update jaclang/jac0core/sealed.py."
        );
        return 1;
    }

    missing = [
        str(Path(p).relative_to(pkg_path))
        for p in sealable_sources(str(pkg_path))
        if not (
            precompiled_dir / pyver / Path(p).relative_to(pkg_path).with_suffix(".jir")
        ).is_file()
    ];
    if missing {
        console.error(
            f"Seal incomplete: {len(missing)} sealable module(s) have no JIR "
            f"(first: {missing[:5]}). The compile pass failed or was skipped."
        );
        return 1;
    }

    identity = compiler_identity();
    foreign: list[str] = [];
    for p in sealable_sources(str(pkg_path)) {
        rel = Path(p).relative_to(pkg_path);
        jir = precompiled_dir / pyver / rel.with_suffix(".jir");
        if not precompiled_jir_matches_source(jir.read_bytes(), p, identity) {
            foreign.append(str(rel));
        }
    }
    if foreign {
        console.error(
            f"Seal aborted: {len(foreign)} module(s) carry a JIR this compiler "
            f"did not produce (first: {foreign[:5]}). Their module keys name a "
            "different compiler content digest, so the seed served bytecode "
            "built by another compiler at this same version (#8178). Delete "
            f"{precompiled_dir} and re-run the precompile."
        );
        return 1;
    }
    console.print(f"  Compiler identity: {identity} (verified over every JIR)");

    out_dir = precompiled_dir / pyver;

    stale_boot = precompiled_dir / "bootstrap";
    if stale_boot.is_dir() {
        shutil.rmtree(stale_boot, ignore_errors=True);
    }

    console.print("  Freezing jac0core bootstrap layer...");
    boot_failed = seal_bootstrap(pkg_path, out_dir, embed_src);
    if boot_failed > 0 {
        console.error(f"Seal aborted: {boot_failed} bootstrap module(s) failed.");
        return 1;
    }

    native_seal: (dict[str, any] | None) = None;
    if pkg_name == "jaclang" {
        console.print("  Sealing AOT native artifacts...");
        native_artifacts = seal_native_artifacts(
            pkg_path, precompiled_dir, canary_reused=canary_reused
        );
        if native_artifacts is None {
            console.error("Seal aborted: native artifact build failed.");
            return 1;
        }
        if sys.platform.startswith("win") {
            native_seal = {"artifacts": {}, "roots": [], "skip_reason": "platform:win"};
        } else {
            native_seal = {
                "artifacts": native_artifacts,
                "roots": sorted(native_artifacts.keys()),
                "skip_reason": None
            };
        }
    }

    manifest_modules: dict[str, dict[str, any]] = {};
    n_boot = 0;
    for jir in sorted(out_dir.rglob("*.jir")) {
        rel_jir = jir.relative_to(out_dir).as_posix();
        (source_rel, fullname, is_pkg) = jir_to_module(pkg_name, rel_jir);
        `entry = {
            "module": fullname,
            "jir": rel_jir,
            "package": is_pkg,
            "sha256": hashlib.sha256(jir.read_bytes()).hexdigest()
        };
        if rel_jir.startswith("jac0core/") {
            `entry["bootstrap"] = True;
            n_boot += 1;
        }
        manifest_modules[source_rel] = `entry;
    }
    console.print(f"  Manifest modules: {len(manifest_modules)} ({n_boot} bootstrap)");

    payloads = collect_payloads(pkg_path);
    if payloads {
        console.print(f"  Payload files: {len(payloads)}");
    }
    app_meta = app_metadata(pkg_path, pkg_name);
    if app_meta {
        console.print(
            f"  App: kind={app_meta.get('kind')} caps={app_meta.get('capabilities')}"
        );
    }
    placement = placement_facts_map(str(pkg_path)) if pkg_name != "jaclang" else {};
    if placement {
        console.print(f"  Placement facts: {len(placement)} modules");
        app_meta = dict(app_meta);
        app_meta["placement"] = placement;
    }
    write_manifest(
        precompiled_dir,
        pkg_name,
        pyver,
        manifest_modules,
        payloads,
        app_meta,
        native_seal
    );
    console.print(f"  Manifest: {precompiled_dir / MANIFEST_NAME}");
    return 0;
}

def write_manifest(
    precompiled_dir: Path,
    pkg_name: str,
    pyver: str,
    modules: dict[str, dict[str, any]],
    payloads: (dict[str, str] | None) = None,
    app_meta: (dict[str, any] | None) = None,
    native_seal: (dict[str, any] | None) = None
) {
    import from importlib.metadata { version as pkg_version }
    try {
        jac_ver = pkg_version("jaclang");
    } except Exception {
        jac_ver = "0.0.0";
    }
    manifest: dict[str, any] = {
        "format": MANIFEST_FORMAT,
        "package": pkg_name,
        "python_tag": pyver,
        "jir_format_version": FORMAT_VERSION,
        "jaclang_version": jac_ver,
        "compiler_digest": compiler_identity(),
        "modules": modules
    };
    if payloads {
        manifest["payloads"] = payloads;
    }
    if app_meta {
        manifest.update(app_meta);
    }
    if native_seal is not None {
        if native_seal.get("artifacts") {
            manifest["native_artifacts"] = native_seal["artifacts"];
        }

        manifest["native"] = {
            "roots": native_seal.get("roots") or [],
            "skip_reason": native_seal.get("skip_reason")
        };
    }
    (precompiled_dir / MANIFEST_NAME).write_text(
        json.dumps(manifest, sort_keys=True, indent=1) + "\n", encoding="utf-8"
    );
}

def precompile_exit(code: int) {
    sys.stdout.flush();
    sys.stderr.flush();
    os._exit(code);
}

def main {
    if os.environ.get(NATIVE_SEAL_WORKER_ENV) {
        precompile_exit(seal_worker_main());
    }
    args = sys.argv[1:];
    seal = "--seal" in args;
    seal_compile = "--seal-compile" in args;
    finalize_only = "--seal-finalize" in args;
    embed_src = "--debug-src" in args;
    canary_reused = "--seal-skip-reused-canary" not in args;
    exclude_jac0core = seal or seal_compile;
    args = [
        a
        for a in args
        if not a.startswith("--")
    ];
    if not args {
        console.print(
            "Usage: jac run utils/precompile_bytecode.jac<package-source-dir> [--seal|--seal-finalize] [--debug-src]"
        );
        console.print("\nExamples:");
        console.print("  jac run utils/precompile_bytecode.jac./jac");
        console.print("  jac run utils/precompile_bytecode.jac./jac/jaclang/scale");
        console.print("\n--seal: precompile, freeze the jac0core bootstrap, and emit");
        console.print("        MANIFEST.json (JIR-authoritative image; .jac sources");
        console.print(
            "        stay on disk for tracebacks, never compiled at runtime)."
        );
        console.print(
            "--seal-compile: compile only (exclude jac0core), no finalize -- the"
        );
        console.print("        payload build's crash-tolerant first pass.");
        console.print(
            "--seal-finalize: run ONLY the seal step over an already-precompiled tree"
        );
        console.print(
            "        (verify completeness, build the manifest, freeze) -- resilient"
        );
        console.print(
            "        to the best-effort compile crashing on a native module."
        );
        console.print(
            "--debug-src: embed zlib source text in each .jir (dev tracebacks)."
        );
        console.print("--seal-skip-reused-canary: do not re-run the load and parity");
        console.print("        canaries on native artifacts the seal reused unchanged");
        console.print(
            "        (tightest dev loop; the canaries still run on rebuilds)."
        );
        sys.`exit(1);
    }

    source_dir = args[0];
    package_dir = find_package_dir(source_dir);
    if package_dir is None {
        console.error(f"Could not find a Python package in {source_dir}");
        sys.`exit(1);
    }

    pkg_name = Path(package_dir).name;
    if (seal or seal_compile or finalize_only)
        and pkg_name != "jaclang"
        and not (Path(package_dir) / "jac.toml").is_file() {
        console.error(
            f"Seal aborted: {package_dir} has no jac.toml. An app seal reads "
            "placement, nested-project scoping, and app metadata from the "
            "project config; sealing without it would compile every module "
            "including client code. Stage a sanitized jac.toml first."
        );
        sys.`exit(1);
    }
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    precompiled_dir = Path(package_dir) / "_precompiled";

    if finalize_only {
        console.print(f"Sealing {pkg_name} for {pyver} (finalize)...");
        precompile_exit(
            seal_finalize(
                Path(package_dir),
                precompiled_dir,
                pkg_name,
                pyver,
                embed_src,
                canary_reused
            )
        );
    }

    console.print(f"Precompiling {pkg_name} for {pyver}...");
    console.print(f"  Package directory: {package_dir}");
    console.print(f"  Compiler identity: {compiler_identity()}");

    jac_files = (
        sealable_sources(package_dir)
            if exclude_jac0core
            else find_jac_files(package_dir)
    );
    console.print(f"  Found {len(jac_files)} .jac files");

    if not jac_files and not exclude_jac0core {
        console.print("  No .jac files to precompile.");
        sys.`exit(0);
    }

    out_dir = precompiled_dir / pyver;
    out_dir.mkdir(parents=True, exist_ok=True);
    (precompiled_dir / RESULT_NAME).unlink(missing_ok=True);

    prune_stale_precompiled_dirs(precompiled_dir, pyver);
    pkg_path = Path(package_dir);
    expected: set[str] = {
        str(Path(p).relative_to(pkg_path).with_suffix(".jir")) for p in jac_files
    };
    for old_jir in sorted(out_dir.rglob("*.jir")) {
        if str(old_jir.relative_to(out_dir)) not in expected {
            old_jir.unlink();
        }
    }

    import from jaclang.jac0core.jir { read_debug_source }

    compiled = 0;
    reused = 0;
    failed = 0;

    for jac_path in jac_files {
        rel = Path(jac_path).relative_to(pkg_path);
        jir_rel = rel.with_suffix(".jir");
        jir_path = out_dir / jir_rel;

        done = compiled + reused + failed;
        label = str(rel)[:60].ljust(60);
        sys.stderr.write(f"\r  [{done + 1}/{len(jac_files)}] {label}");
        sys.stderr.flush();

        try {
            if jir_path.is_file() {
                existing = jir_path.read_bytes();
                if precompiled_jir_matches_source(existing, jac_path)
                    and embed_src == (read_debug_source(existing) is not None) {
                    reused += 1;
                    continue;
                }
            }

            jir_bytes = precompile_unit(jac_path, package_dir, embed_src);
            if jir_bytes is None {
                console.print(f"  SKIP (no bytecode): {rel}");
                jir_path.unlink(missing_ok=True);
                failed += 1;
                continue;
            }

            jir_path.parent.mkdir(parents=True, exist_ok=True);
            jir_path.write_bytes(jir_bytes);
            compiled += 1;
        } except Exception as e {
            console.error(f"FAIL: {rel} - {e}");
            jir_path.unlink(missing_ok=True);
            failed += 1;
        }
    }

    sys.stderr.write("\n");
    sys.stderr.flush();

    console.print(
        f"\nDone! Compiled {compiled}/{len(jac_files)} modules"
            + f" ({reused} reused, {failed} failed)"
    );
    console.print(f"  Output: {precompiled_dir}");
    console.print(f"  Python version: {pyver}");

    (precompiled_dir / RESULT_NAME).write_text(
        json.dumps(
            {
                "total": len(jac_files),
                "compiled": compiled,
                "reused": reused,
                "failed": failed
            }
        )
            + "\n",
        encoding="utf-8"
    );

    if seal {
        precompile_exit(
            seal_finalize(
                pkg_path, precompiled_dir, pkg_name, pyver, embed_src, canary_reused
            )
        );
    }
    precompile_exit(0);
}

with entry:__main__ {
    main();
}
