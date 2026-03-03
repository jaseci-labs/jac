"""Jac Compiler - handles all compilation operations separate from program state."""
import ast as py_ast;
import atexit;
import marshal;
import os;
import sys;
import types;
import from threading { Event }
import from typing { TYPE_CHECKING, Any }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.jir {
    SEC_BYTECODE,
    SEC_MTIR,
    SEC_LLVM_IR,
    SEC_INTEROP,
    FLAG_PRECOMPILED,
    get_module_cache_path,
    is_module_cache_valid,
    read_bytecode_only,
    read_sections,
    SECTIONS_MAGIC,
    HEADER_SIZE,
    write_sections
}
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.helpers { read_file_with_encoding }
import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
import from jaclang.jac0core.passes {
    DeclImplMatchPass,
    InteropAnalysisPass,
    JacAnnexPass,
    PyastGenPass,
    PyBytecodeGenPass,
    SemanticAnalysisPass,
    SymTabBuildPass,
    Transform
}

with entry {
    if TYPE_CHECKING {
        import from jaclang.jac0core.program { JacProgram }
    }
}

"""Symbol table build schedule."""
def get_symtab_ir_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    return [SymTabBuildPass, DeclImplMatchPass];
}

glob _ir_sched_loading = False,
     _codegen_sched_loading = False;

"""Full IR generation schedule.

    Uses a re-entrancy guard: when compiling the pass modules that this
    schedule depends on (CFGBuildPass, etc.), importing them would
    trigger recursive compilation. The guard detects this and falls back
    to the basic schedule (symtab + semantic analysis only), which uses
    only jac0core passes.
    """
def get_ir_gen_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    global _ir_sched_loading;
    if _ir_sched_loading {
        return [SymTabBuildPass, DeclImplMatchPass, SemanticAnalysisPass];
    }
    _ir_sched_loading = True;
    try {
        import from jaclang.compiler.passes.main.cfg_build_pass { CFGBuildPass }
        import from jaclang.compiler.passes.main.mtir_gen_pass { MTIRGenPass }
        import from jaclang.compiler.passes.main.sem_def_match_pass { SemDefMatchPass }
        return [
            SymTabBuildPass,
            DeclImplMatchPass,
            SemanticAnalysisPass,
            SemDefMatchPass,
            CFGBuildPass,
            MTIRGenPass
        ];
    } except ImportError {
        return [SymTabBuildPass, DeclImplMatchPass, SemanticAnalysisPass];
    } finally {
        _ir_sched_loading = False;
    }
}

"""Type checking schedule."""
def get_type_check_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
    import from jaclang.compiler.passes.main.static_analysis_pass { StaticAnalysisPass }
    return [TypeCheckPass, StaticAnalysisPass];
}

"""Full Python code generation schedule.

    Same re-entrancy guard as get_ir_gen_sched: when compiling the
    pass modules this depends on, falls back to bytecode-only generation.
    """
def get_py_code_gen -> list[type[Transform[uni.Module, uni.Module]]] {
    global _codegen_sched_loading;
    if _codegen_sched_loading or _ir_sched_loading {
        return [PyastGenPass, PyBytecodeGenPass];
    }
    _codegen_sched_loading = True;
    try {
        import from jaclang.compiler.passes.ecmascript { EsastGenPass }
        import from jaclang.compiler.passes.main.pyjac_ast_link_pass { PyJacAstLinkPass }
        passes: list[type[Transform[uni.Module, uni.Module]]] = [
            InteropAnalysisPass,
            EsastGenPass
        ];
        import from jaclang.compiler.passes.native {
            NativeCompatCheckPass,
            NaIRGenPass,
            NativeCompilePass
        }
        passes.extend([NativeCompatCheckPass, NaIRGenPass, NativeCompilePass]);
        passes.extend([PyastGenPass, PyJacAstLinkPass, PyBytecodeGenPass]);
        return passes;
    } except ImportError {
        return [PyastGenPass, PyBytecodeGenPass];
    } finally {
        _codegen_sched_loading = False;
    }
}

"""Format schedule. If auto_lint=True, includes auto-linting pass.

    Note: Annex modules (.impl.jac, .test.jac) are loaded by the caller
    (jac_file_formatter) via parse-only, NOT through JacAnnexPass which
    triggers cascading compilation of the entire import graph.
    """
def get_format_sched(
    auto_lint: bool = False
) -> list[type[Transform[uni.Module, uni.Module]]] {
    import from jaclang.compiler.passes.tool.comment_injection_pass {
        CommentInjectionPass
    }
    import from jaclang.compiler.passes.tool.doc_ir_gen_pass { DocIRGenPass }
    import from jaclang.compiler.passes.tool.jac_auto_lint_pass { JacAutoLintPass }
    import from jaclang.compiler.passes.tool.jac_formatter_pass { JacFormatPass }
    if auto_lint {
        return [JacAutoLintPass, DocIRGenPass, CommentInjectionPass, JacFormatPass];
    } else {
        return [DocIRGenPass, CommentInjectionPass, JacFormatPass];
    }
}

"""Lint-only schedule. Runs lint rules for error reporting without formatting.

    Note: Annex modules are loaded by the caller (jac_file_linter) via
    parse-only to avoid cascading compilation through the import graph.
    """
def get_lint_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    import from jaclang.compiler.passes.tool.jac_auto_lint_pass { JacAutoLintPass }
    return [JacAutoLintPass];
}

"""Recursively replace a string in all co_filename fields of marshal bytes.

Used for precompiled bundles: call with (bc, sentinel, real_root) to expand
sentinel paths at load time, or with (bc, real_root, sentinel) to embed
sentinel paths at build time.  Returns raw_bc unchanged on any error.
"""
def patch_co_filenames_bytes(raw_bc: bytes, find: str, replace: str) -> bytes {
    try {
        import types as _types;
        code = marshal.loads(raw_bc);
        def _patch(c: _types.CodeType) -> _types.CodeType {
            new_filename = c.co_filename.replace(find, replace);
            new_consts = tuple(
                _patch(x) if isinstance(x, _types.CodeType) else x for x in c.co_consts
            );
            return c.replace(co_filename=new_filename, co_consts=new_consts);
        }
        return marshal.dumps(_patch(code));
    } except Exception {
        return raw_bc;
    }
}

"""Tracks and displays progress during first-run compilation of internal modules."""
class _SetupProgress {
    def init(self: _SetupProgress) -> None {
        self._banner_shown = False;
        self._compile_count = 0;
        self._seen_files: set[str] = `set();
        self._jaclang_root: (str | None) = None;
    }

    def _get_jaclang_root(self: _SetupProgress) -> str {
        if (self._jaclang_root is None) {
            self._jaclang_root = os.path.dirname(os.path.dirname(__file__));
        }
        return self._jaclang_root;
    }

    """Print the completion summary when the process exits."""
    def _atexit_handler(self: _SetupProgress) -> None {
        if (self._banner_shown and (self._compile_count > 0)) {
            sys.stderr.write(
                f"Jac setup complete! ({self._compile_count} modules compiled and cached)\n"
            );
            sys.stderr.flush();
        }
    }

    """Called when an internal jaclang module needs compilation (cache miss)."""
    def on_internal_compile(self: _SetupProgress, file_path: str) -> None {
        normalized = os.path.normpath(file_path);
        if (normalized in self._seen_files) {
            return;
        }
        self._seen_files.add(normalized);
        if not self._banner_shown {
            self._banner_shown = True;
            atexit.register(self._atexit_handler);
            sys.stderr.write(
                '\nSetting up Jac for first use (compiling and caching compiler)...\n'
            );
            sys.stderr.flush();
        }
        jaclang_root = self._get_jaclang_root();
        rel_path = file_path;
        if normalized.startswith((jaclang_root + os.sep)) {
            rel_path = os.path.relpath(normalized, os.path.dirname(jaclang_root));
        }
        self._compile_count += 1;
        sys.stderr.write(f"  Compiling {rel_path}...\n");
        sys.stderr.flush();
    }

    """Whether we're currently in a first-run setup."""
    @property
    def is_active(self: _SetupProgress) -> bool {
        return self._banner_shown;
    }
}

glob setup_progress = _SetupProgress();

"""Recalculate parent pointers after mutating node children."""
def _recalculate_parents(nd: uni.UniNode) -> None {
    for child in nd.kid {
        child.parent = nd;
        _recalculate_parents(child);
    }
}

"""Coerce a .cl.jac module to client context."""
def _coerce_client_module(module: uni.Module) -> None {
    elements: list[uni.ElementStmt] = [];
    for stmt in module.body {
        if isinstance(stmt, uni.ClientBlock) {
            elements.extend(stmt.body);
        } elif isinstance(stmt, uni.ServerBlock) {
            elements.append(stmt);
        } elif isinstance(stmt, uni.ElementStmt) {
            elements.append(stmt);
        }
    }
    for elem in elements {
        if isinstance(elem, uni.ServerBlock) {
            continue;
        }
        if isinstance(elem, uni.ContextAwareNode) {
            context_token = elem._source_context_token();
            if (context_token is not None and context_token.name == Tok.KW_SERVER) {
                continue;
            }
            elem.code_context = CodeContext.CLIENT;
            if (isinstance(elem, uni.ModuleCode) and elem.body) {
                for inner in elem.body {
                    if isinstance(inner, uni.ContextAwareNode) {
                        inner.code_context = CodeContext.CLIENT;
                    }
                }
            }
        }
    }
    module.body = elements;
    new_kid: list[uni.UniNode] = [];
    if module.doc {
        new_kid.append(module.doc);
    }
    new_kid.extend(module.body);
    module.set_kids(nodes=new_kid or [uni.EmptyToken()]);
    _recalculate_parents(module);
}

"""Coerce a .sv.jac module to server context."""
def _coerce_server_module(module: uni.Module) -> None {
    elements: list[uni.ElementStmt] = [];
    for stmt in module.body {
        if isinstance(stmt, uni.ServerBlock) {
            elements.extend(stmt.body);
        } elif isinstance(stmt, uni.ClientBlock) {
            elements.append(stmt);
        } elif isinstance(stmt, uni.ElementStmt) {
            elements.append(stmt);
        }
    }
    for elem in elements {
        if isinstance(elem, uni.ClientBlock) {
            continue;
        }
        if isinstance(elem, uni.ContextAwareNode) {
            elem.code_context = CodeContext.SERVER;
            if (isinstance(elem, uni.ModuleCode) and elem.body) {
                for inner in elem.body {
                    if isinstance(inner, uni.ContextAwareNode) {
                        inner.code_context = CodeContext.SERVER;
                    }
                }
            }
        }
    }
    module.body = elements;
    new_kid: list[uni.UniNode] = [];
    if module.doc {
        new_kid.append(module.doc);
    }
    new_kid.extend(module.body);
    module.set_kids(nodes=new_kid or [uni.EmptyToken()]);
    _recalculate_parents(module);
}

"""Coerce a .na.jac module to native context."""
def _coerce_native_module(module: uni.Module) -> None {
    elements: list[uni.ElementStmt] = [];
    for stmt in module.body {
        if isinstance(stmt, uni.NativeBlock) {
            elements.extend(stmt.body);
        } elif isinstance(stmt, (uni.ServerBlock, uni.ClientBlock)) {
            elements.append(stmt);
        } elif isinstance(stmt, uni.ElementStmt) {
            elements.append(stmt);
        }
    }
    for elem in elements {
        if isinstance(elem, (uni.ServerBlock, uni.ClientBlock)) {
            continue;
        }
        if isinstance(elem, uni.ContextAwareNode) {
            elem.code_context = CodeContext.NATIVE;
            if (isinstance(elem, uni.ModuleCode) and elem.body) {
                for inner in elem.body {
                    if isinstance(inner, uni.ContextAwareNode) {
                        inner.code_context = CodeContext.NATIVE;
                    }
                }
            }
        }
    }
    module.body = elements;
    new_kid: list[uni.UniNode] = [];
    if module.doc {
        new_kid.append(module.doc);
    }
    new_kid.extend(module.body);
    module.set_kids(nodes=new_kid or [uni.EmptyToken()]);
    _recalculate_parents(module);
}

"""Jac Compiler singleton.

    Maintains separate module hub for jaclang.* modules (internal_program)
    vs user modules (target_program passed to methods).
    """
class JacCompiler {
    with entry {
        _jaclang_root: (str | None) = None;
    }

    """Initialize the compiler."""
    def init(self: JacCompiler) -> None {
        self._internal_program: (JacProgram | None) = None;
    }

    """Module hub for jaclang.* modules (lazily initialized)."""
    @property
    def internal_program(self: JacCompiler) -> JacProgram {
        if (self._internal_program is None) {
            import from jaclang.jac0core.program { JacProgram }
            self._internal_program = JacProgram();
        }
        return self._internal_program;
    }

    """Get the jaclang package root path."""
    @classmethod
    def _get_jaclang_root(cls: Any) -> str {
        if (cls._jaclang_root is None) {
            cls._jaclang_root = os.path.dirname(os.path.dirname(__file__));
        }
        return cls._jaclang_root;
    }

    """Route jaclang.* files to internal_program, others to target_program."""
    def _resolve_program(
        self: JacCompiler, file_path: str, target_program: JacProgram
    ) -> JacProgram {
        normalized_path = os.path.normpath(file_path);
        jaclang_root = self._get_jaclang_root();
        if normalized_path.startswith((jaclang_root + os.sep)) {
            return self.internal_program;
        }
        return target_program;
    }

    """Get native interop setup for a module.

        Returns:
            Tuple of (native_engine, interop_py_funcs_dict).
            native_engine is None if no native code.
            interop_py_funcs_dict is None if module not found in hub
            (caller should not inject into module dict in this case).
        """
    def get_native_interop_setup(
        self: JacCompiler, full_target: str, target_program: JacProgram
    ) -> tuple[((object | None), (dict[(str, object)] | None))] {
        actual_program = self._resolve_program(full_target, target_program);
        if (full_target in actual_program.mod.hub) {
            mod = actual_program.mod.hub[full_target];
            native_engine = getattr(mod.gen, 'native_engine', None);
            interop_py_funcs = getattr(mod.gen, 'interop_py_funcs', None);
            if (interop_py_funcs is None) {
                interop_py_funcs = {};
            }
            return (native_engine, interop_py_funcs);
        }
        return (None, None);
    }

    """Get bytecode using 2-tier cache: in-memory -> JIR -> compile.

        Tier 1: in-memory hub (py_bytecode already set).
        Tier 2: JIR cache fast-path (read_bytecode_only, no AST deserialize).
        Tier 2.5: precompiled JIR bundle shipped with the package.
        Tier 3: full compile + atomic JIR write.
        """
    def get_bytecode(
        self: JacCompiler, full_target: str, target_program: JacProgram
    ) -> (types.CodeType | None) {
        actual_program = self._resolve_program(full_target, target_program);

        # Tier 1: in-memory hub
        if (
            (full_target in actual_program.mod.hub)
            and actual_program.mod.hub[full_target].gen.py_bytecode
        ) {
            codeobj = actual_program.mod.hub[full_target].gen.py_bytecode;
            return marshal.loads(codeobj) if isinstance(codeobj, `bytes) else None;
        }

        # Tier 2: JIR cache fast path
        cache_path = get_module_cache_path(full_target);
        if is_module_cache_valid(full_target, cache_path) {
            try {
                jir_data = cache_path.read_bytes();
                bc = read_bytecode_only(jir_data);
                if bc is not None {
                    magic_bytes: Any = SECTIONS_MAGIC;
                    sec_pos = jir_data.find(magic_bytes, HEADER_SIZE);
                    if sec_pos >= 0 {
                        secs = read_sections(jir_data, sec_pos + len(magic_bytes));
                        self._restore_sections(full_target, actual_program, secs);
                    }
                    return marshal.loads(bc);
                }
            } except Exception {
                ;
            }
        }

        # Tier 2.5: precompiled JIR bundle shipped with the package
        precompiled_bc = self._get_precompiled_jir_bytecode(full_target);
        if precompiled_bc is not None {
            try {
                from
                jaclang.jac0core.jir
                import write_precompiled_jir, FLAG_PRECOMPILED;
                jir_bytes = write_precompiled_jir(precompiled_bc, 0, FLAG_PRECOMPILED);
                cache_path.parent.mkdir(parents=True, exist_ok=True);
                tmp_path = cache_path.with_suffix('.tmp');
                tmp_path.write_bytes(jir_bytes);
                tmp_path.rename(cache_path);
            } except Exception {
                ;
            }
            return marshal.loads(precompiled_bc);
        }

        # Tier 3: full compile + JIR write
        is_internal = actual_program is self._internal_program;
        if is_internal {
            setup_progress.on_internal_compile(full_target);
        }
        options = CompileOptions();
        result = self.compile(
            file_path=full_target, target_program=actual_program, options=options
        );
        if result.gen.py_bytecode {
            try {
                import from jaclang.jac0core.jir_passes { JirWriter }
                import pickle;
                import json;
                import zlib;
                sections: dict[int, bytes] = {};
                sections[SEC_BYTECODE] = result.gen.py_bytecode;
                if actual_program.mtir_map {
                    sections[SEC_MTIR] = pickle.dumps(
                        actual_program.mtir_map, int(pickle.HIGHEST_PROTOCOL)
                    );
                }
                llvm_ir = getattr(result.gen, 'llvm_ir', None);
                if llvm_ir is not None {
                    sections[SEC_LLVM_IR] = zlib.compress(
                        str(llvm_ir).encode('utf-8'), 6
                    );
                }
                interop_dict = self._build_interop_dict(result);
                if interop_dict {
                    sections[SEC_INTEROP] = json.dumps(interop_dict).encode('utf-8');
                }
                writer = JirWriter();
                jir_bytes = writer.write_module(result, sections=sections);
                cache_path.parent.mkdir(parents=True, exist_ok=True);
                tmp_path = cache_path.with_suffix('.tmp');
                tmp_path.write_bytes(jir_bytes);
                tmp_path.rename(cache_path);
            } except Exception {
                ;
            }
            return marshal.loads(result.gen.py_bytecode);
        }
        return None;
    }

    """Load native module from cached LLVM IR.

        Creates a fresh MCJIT engine from the cached IR string and sets up
        interop callbacks. This is much faster than full recompilation since
        we skip the JacâASTâLLVM IR pipeline.
        """
    def _load_native_from_cache(
        self: JacCompiler,
        full_target: str,
        target_program: JacProgram,
        cached_ir: str,
        cached_interop: (dict | None)
    ) -> None {
        try {
            import llvmlite.binding as llvm;
            llvm.initialize_native_target();
            llvm.initialize_native_asmprinter();
            import ctypes;
            import ctypes.util;
            libc_name = ctypes.util.find_library('c');
            if libc_name {
                llvm.load_library_permanently(libc_name);
            }
            libgc_name = ctypes.util.find_library('gc');
            if libgc_name {
                llvm.load_library_permanently(libgc_name);
            } else {
                libc = ctypes.CDLL(libc_name);
                malloc_addr = ctypes.cast(libc.malloc, ctypes.c_void_p).value;
                llvm.add_symbol('GC_malloc', malloc_addr);
            }
            llvm_mod = llvm.parse_assembly(cached_ir);
            llvm_mod.verify();
            target = llvm.Target.from_default_triple();
            target_machine = target.create_target_machine();
            engine = llvm.create_mcjit_compiler(llvm_mod, target_machine);
            import from jaclang.jac0core.codeinfo { CodeGenTarget, InteropManifest }
            """Minimal stub to hold native compilation artifacts.""";
            class _NativeModuleStub {
                def init(self: _NativeModuleStub) -> None {
                    self.gen = CodeGenTarget();
                }
            }
            stub_mod = _NativeModuleStub();
            stub_mod.gen.native_engine = engine;
            py_func_table: dict = {};
            callbacks_list: list = [];
            stub_mod.gen.interop_py_funcs = py_func_table;
            stub_mod.gen._interop_callbacks = callbacks_list;
            if cached_interop {
                import from jaclang.jac0core.codeinfo { InteropBinding, InteropContext }
                import from jaclang.jac0core.interop_bridge { register_py_callbacks }
                manifest = InteropManifest();
                for (name, data) in cached_interop.get('bindings', {}).items() {
                    binding = InteropBinding(
                        name=name,
                        source_context=InteropContext(data['source_context']),
                        callers={InteropContext(c) for c in data.get('callers', [])},
                        ret_type=data.get('ret_type', 'int'),
                        param_types=data.get('param_types', []),
                        param_names=data.get('param_names', []),
                        source_module=data.get('source_module')
                    );
                    manifest.bindings[name] = binding;
                }
                stub_mod.gen.interop_manifest = manifest;
                if manifest.native_imports {
                    register_py_callbacks(manifest, py_func_table, callbacks_list);
                }
            }
            target_program.mod.hub[full_target] = stub_mod;
        } except Exception as e {
            import logging;
            logging.getLogger(__name__).debug(
                f"Failed to load native module from cache: {e}"
            );
        }
    }

    """Restore side-effects (MTIR, native) from decoded JIR sections."""
    def _restore_sections(
        self: JacCompiler,
        full_target: str,
        actual_program: JacProgram,
        secs: dict[int, bytes]
    ) -> None {
        import pickle;
        mtir_bytes = secs.get(SEC_MTIR);
        if mtir_bytes is not None {
            try {
                mtir_map = pickle.loads(mtir_bytes);
                actual_program.mtir_map.update(mtir_map);
            } except Exception {
                ;
            }
        }
        llvm_bytes = secs.get(SEC_LLVM_IR);
        if llvm_bytes is not None {
            try {
                import zlib;
                import json;
                cached_ir = zlib.decompress(llvm_bytes).decode('utf-8');
                cached_interop: (dict | None) = None;
                interop_bytes = secs.get(SEC_INTEROP);
                if interop_bytes is not None {
                    cached_interop = json.loads(interop_bytes.decode('utf-8'));
                }
                self._load_native_from_cache(
                    full_target, actual_program, cached_ir, cached_interop
                );
            } except Exception {
                ;
            }
        }
    }

    """Walk up from a .jac file looking for a _precompiled/ JIR bundle."""
    def _get_precompiled_jir_bytecode(
        self: JacCompiler, full_target: str
    ) -> (bytes | None) {
        import hashlib;
        import json;
        from
        pathlib
        import Path as _Path;
        norm_file = os.path.normpath(os.path.abspath(full_target));
        d = os.path.dirname(norm_file);
        pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
        while True {
            manifest_path = os.path.join(d, '_precompiled', 'manifest.json');
            if os.path.isfile(manifest_path) {
                try {
                    with open(manifest_path, encoding='utf-8') as f {
                        manifest = json.load(f);
                    }
                    norm_root = os.path.normpath(d);
                    if not norm_file.startswith(norm_root + os.sep) {
                        break;
                    }
                    rel_path = norm_file[len(norm_root) + 1:];
                    rel_key = rel_path.replace(os.sep, '/');
                    entries = manifest.get('entries', {});
                    entry = entries.get(rel_key);
                    if not isinstance(entry, dict) {
                        break;
                    }
                    expected = entry.get('source_hash');
                    if expected {
                        with open(norm_file, 'rb') as f2 {
                            actual = hashlib.sha256(f2.read()).hexdigest();
                        }
                        if actual != expected {
                            break;
                        }
                    }
                    sentinel = manifest.get('filename_sentinel', '__PKG_ROOT__');
                    # Try .jir bundle first
                    jir_rel = os.path.splitext(rel_path)[0] + '.jir';
                    jir_path = os.path.join(d, '_precompiled', pyver, jir_rel);
                    if os.path.isfile(jir_path) {
                        jir_data = _Path(jir_path).read_bytes();
                        if len(jir_data) >= 32 {
                            import struct;
                            (flags_val, ) = struct.unpack_from('<I', jir_data, 28);
                            if flags_val & FLAG_PRECOMPILED {
                                bc = read_bytecode_only(jir_data);
                                if bc is not None {
                                    return patch_co_filenames_bytes(bc, sentinel, d);
                                }
                            }
                        }
                    }
                    # Fallback: legacy .jbc bundle
                    jbc_rel = os.path.splitext(rel_path)[0] + '.jbc';
                    jbc_path = os.path.join(d, '_precompiled', pyver, jbc_rel);
                    if os.path.isfile(jbc_path) {
                        return patch_co_filenames_bytes(
                            _Path(jbc_path).read_bytes(), sentinel, d
                        );
                    }
                } except Exception {
                    ;
                }
                break;
            }
            parent = os.path.dirname(d);
            if parent == d {
                break;
            }
            d = parent;
        }
        return None;
    }

    """Build a JSON-serializable interop dict from a compiled module."""
    def _build_interop_dict(self: JacCompiler, result: uni.Module) -> dict {
        manifest = getattr(result.gen, 'interop_manifest', None);
        if manifest is None {
            return {};
        }
        interop_data: dict = {'bindings': {}};
        for (name, binding) in manifest.bindings.items() {
            interop_data['bindings'][name] = {
                'source_context': binding.source_context.value,
                'callers': [c.value for c in binding.callers],
                'ret_type': binding.ret_type,
                'param_types': binding.param_types,
                'param_names': binding.param_names,
                'source_module': binding.source_module
            };
        }
        return interop_data;
    }

    """Parse source string into AST module."""
    def parse_str(
        self: JacCompiler,
        source_str: str,
        file_path: str,
        target_program: JacProgram,
        cancel_token: (Event | None) = None
    ) -> uni.Module {
        had_error = False;
        if (file_path.endswith('.py') or file_path.endswith('.pyi')) {
            import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
            parsed_ast = py_ast.parse(source_str);
            py_ast_ret = PyastBuildPass(
                ir_in=uni.PythonModuleAst(
                    parsed_ast, orig_src=uni.Source(source_str, mod_path=file_path)
                ),
                prog=target_program,
                cancel_token=cancel_token
            );
            had_error = len(py_ast_ret.errors_had) > 0;
            mod = py_ast_ret.ir_out;
        } else {
            import from jaclang.jac0core.parser { parse as rd_parse }
            (mod, parse_errors, lex_errors) = rd_parse(
                source_str, file_path, prog=target_program
            );
            _recalculate_parents(mod);
            had_error = len(parse_errors) > 0 or len(lex_errors) > 0;
            if file_path.endswith('.cl.jac') {
                _coerce_client_module(mod);
            } elif file_path.endswith('.sv.jac') {
                _coerce_server_module(mod);
            } elif file_path.endswith('.na.jac') {
                _coerce_native_module(mod);
            }
        }
        if had_error {
            return mod;
        }
        if target_program.mod.main.stub_only {
            target_program.mod = uni.ProgramModule(main_mod=mod);
        }
        target_program.mod.hub[mod.loc.mod_path] = mod;
        JacAnnexPass(ir_in=mod, prog=target_program);
        return mod;
    }

    """Compile a Jac file into module AST.

        Args:
            file_path: Path to the Jac file to compile.
            target_program: JacProgram to store compiled module in.
            use_str: Optional source string instead of reading from file.
            options: CompileOptions controlling compilation behavior.
        """
    def compile(
        self: JacCompiler,
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None) = None,
        options: (CompileOptions | None) = None
    ) -> uni.Module {
        if (options is None) {
            options = CompileOptions();
        }
        actual_program = self._resolve_program(file_path, target_program);
        actual_program._compile_options = options;
        keep_str = use_str or read_file_with_encoding(file_path);
        had_parse_errors = len(actual_program.errors_had);
        mod_targ = self.parse_str(
            keep_str, file_path, actual_program, cancel_token=options.cancel_token
        );
        had_parse_errors = len(actual_program.errors_had) > had_parse_errors;
        if options.symtab_ir_only {
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_symtab_ir_sched(),
                cancel_token=options.cancel_token
            );
        } else {
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_ir_gen_sched(),
                cancel_token=options.cancel_token
            );
        }
        if options.type_check {
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_type_check_sched(),
                cancel_token=options.cancel_token
            );
        }
        if (not had_parse_errors and not options.no_cgen) {
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_py_code_gen(),
                cancel_token=options.cancel_token
            );
        }
        return mod_targ;
    }

    """Build a Jac file with import dependency resolution."""
    def build(
        self: JacCompiler,
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None) = None,
        type_check: bool = False
    ) -> uni.Module {
        actual_program = self._resolve_program(file_path, target_program);
        options = CompileOptions(type_check=type_check);
        mod_targ = self.compile(file_path, actual_program, use_str, options=options);
        SemanticAnalysisPass(ir_in=mod_targ, prog=actual_program);
        return mod_targ;
    }

    """Run a list of passes on a module."""
    def run_schedule(
        self: JacCompiler,
        mod: uni.Module,
        target_program: JacProgram,
        passes: list[type[Transform[uni.Module, uni.Module]]],
        cancel_token: (Event | None) = None
    ) -> None {
        for current_pass in passes {
            if (cancel_token and cancel_token.is_set()) {
                break;
            }
            current_pass(ir_in=mod, prog=target_program, cancel_token=cancel_token);
        }
    }

    """Format a Jac file."""
    static def jac_file_formatter(
        file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        import from jaclang.jac0core.program { JacProgram }
        import from jaclang.jac0core.parser { parse as rd_parse }
        import from jaclang.jac0core.bccache { discover_annex_files }
        prog = JacProgram();
        source_str = read_file_with_encoding(file_path);
        (current_mod, parse_errors, lex_errors) = rd_parse(source_str, file_path);
        _recalculate_parents(current_mod);
        if len(parse_errors) > 0 or len(lex_errors) > 0 {
            prog.errors_had.extend(parse_errors);
            prog.errors_had.extend(lex_errors);
            prog.mod = uni.ProgramModule(main_mod=current_mod);
            return prog;
        }
        # Parse-only annex loading: just parse .impl.jac/.test.jac files
        # without running SymTabBuildPass or any compilation passes.
        # This avoids cascading import resolution that would compile the
        # entire dependency graph for each formatted file.
        if auto_lint {
            for annex_path in discover_annex_files(file_path, '.impl.jac') {
                try {
                    annex_src = read_file_with_encoding(annex_path);
                    (annex_mod, _, _) = rd_parse(annex_src, annex_path);
                    _recalculate_parents(annex_mod);
                    current_mod.impl_mod.append(annex_mod);
                } except Exception {
                    ;
                }
            }
            for annex_path in discover_annex_files(file_path, '.test.jac') {
                try {
                    annex_src = read_file_with_encoding(annex_path);
                    (annex_mod, _, _) = rd_parse(annex_src, annex_path);
                    _recalculate_parents(annex_mod);
                    current_mod.test_mod.append(annex_mod);
                } except Exception {
                    ;
                }
            }
        }
        for pass_cls in get_format_sched(auto_lint=auto_lint) {
            current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out;
        }
        prog.mod = uni.ProgramModule(main_mod=current_mod);
        return prog;
    }

    """Format a Jac source string."""
    static def jac_str_formatter(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        import from jaclang.jac0core.program { JacProgram }
        import from jaclang.jac0core.parser { parse as rd_parse }
        prog = JacProgram();
        (current_mod, parse_errors, lex_errors) = rd_parse(source_str, file_path);
        _recalculate_parents(current_mod);
        if len(parse_errors) > 0 or len(lex_errors) > 0 {
            prog.errors_had.extend(parse_errors);
            prog.errors_had.extend(lex_errors);
            prog.mod = uni.ProgramModule(main_mod=current_mod);
            return prog;
        }
        for pass_cls in get_format_sched(auto_lint=auto_lint) {
            current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out;
        }
        prog.mod = uni.ProgramModule(main_mod=current_mod);
        return prog;
    }

    """Lint a Jac file (report only, no formatting or output generation)."""
    static def jac_file_linter(file_path: str) -> JacProgram {
        import from jaclang.jac0core.program { JacProgram }
        import from jaclang.jac0core.parser { parse as rd_parse }
        import from jaclang.jac0core.bccache { discover_annex_files }
        prog = JacProgram();
        source_str = read_file_with_encoding(file_path);
        (current_mod, parse_errors, lex_errors) = rd_parse(source_str, file_path);
        _recalculate_parents(current_mod);
        # Parse-only annex loading (same as jac_file_formatter)
        for annex_path in discover_annex_files(file_path, '.impl.jac') {
            try {
                annex_src = read_file_with_encoding(annex_path);
                (annex_mod, _, _) = rd_parse(annex_src, annex_path);
                _recalculate_parents(annex_mod);
                current_mod.impl_mod.append(annex_mod);
            } except Exception {
                ;
            }
        }
        for pass_cls in get_lint_sched() {
            current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out;
        }
        prog.mod = uni.ProgramModule(main_mod=current_mod);
        return prog;
    }
}
