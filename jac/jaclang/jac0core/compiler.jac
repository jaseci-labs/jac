"""Jac Compiler - handles all compilation operations separate from program state."""
import ast as py_ast;
import atexit;
import marshal;
import os;
import sys;
import types;
import from threading { Event }
import from typing { TYPE_CHECKING }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.bccache {
    BytecodeCache,
    CacheKey,
    DiskBytecodeCache,
    get_bytecode_cache
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
def get_symtab_ir_sched -> list[type[Transform[(uni.Module, uni.Module)]]] {
    return [SymTabBuildPass, DeclImplMatchPass];
}

glob _ir_sched_loading = False,
     _codegen_sched_loading = False;

"""Full IR generation schedule.

    Uses a re-entrancy guard: when compiling the pass modules that this
    schedule depends on (CFGBuildPass, etc.), the lazy imports would
    trigger recursive compilation. The guard detects this and falls back
    to the basic schedule (symtab + semantic analysis only), which uses
    only jac0core passes with no lazy imports.
    """
def get_ir_gen_sched -> list[type[Transform[(uni.Module, uni.Module)]]] {
    global _ir_sched_loading;
    if _ir_sched_loading {
        return [SymTabBuildPass, DeclImplMatchPass, SemanticAnalysisPass];
    }
    _ir_sched_loading = True;
    try {
        import from jaclang.compiler.passes.main {
            CFGBuildPass,
            MTIRGenPass,
            SemDefMatchPass
        }
        return [
            SymTabBuildPass,
            DeclImplMatchPass,
            SemanticAnalysisPass,
            SemDefMatchPass,
            CFGBuildPass,
            MTIRGenPass
        ];
    } finally {
        _ir_sched_loading = False;
    }
}

"""Type checking schedule."""
def get_type_check_sched -> list[type[Transform[(uni.Module, uni.Module)]]] {
    import from jaclang.compiler.passes.main { TypeCheckPass }
    return [TypeCheckPass];
}

"""Full Python code generation schedule.

    Same re-entrancy guard as get_ir_gen_sched: when compiling the pass
    modules this depends on, falls back to bytecode-only generation.
    """
def get_py_code_gen -> list[type[Transform[(uni.Module, uni.Module)]]] {
    global _codegen_sched_loading;
    if _codegen_sched_loading {
        return [PyastGenPass, PyBytecodeGenPass];
    }
    _codegen_sched_loading = True;
    try {
        import from jaclang.compiler.passes.ecmascript { EsastGenPass }
        import from jaclang.compiler.passes.main { PyJacAstLinkPass }
        passes: list[type[Transform[(uni.Module, uni.Module)]]] = [
            InteropAnalysisPass,
            EsastGenPass
        ];
        import from jaclang.compiler.passes.native { NaIRGenPass, NativeCompilePass }
        passes.extend([NaIRGenPass, NativeCompilePass]);
        passes.extend([PyastGenPass, PyJacAstLinkPass, PyBytecodeGenPass]);
        return passes;
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
) -> list[type[Transform[(uni.Module, uni.Module)]]] {
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
def get_lint_sched -> list[type[Transform[(uni.Module, uni.Module)]]] {
    import from jaclang.compiler.passes.tool.jac_auto_lint_pass { JacAutoLintPass }
    return [JacAutoLintPass];
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

    """Initialize with optional custom bytecode cache."""
    def init(self: JacCompiler, bytecode_cache: (BytecodeCache | None) = None) -> None {
        self._bytecode_cache: BytecodeCache = bytecode_cache or get_bytecode_cache();
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

    """Load MTIR map from cache if available."""
    def _load_mtir_cache(
        self: JacCompiler, cache_key: CacheKey, program: JacProgram
    ) -> None {
        try {
            import from jaclang.jac0core.bccache { DiskBytecodeCache }
            if isinstance(self._bytecode_cache, DiskBytecodeCache) {
                cached_mtir = self._bytecode_cache.get_mtir(cache_key);
                if (cached_mtir is not None) {
                    program.mtir_map.update(cached_mtir);
                }
            }
        } except Exception {
            ;
        }
    }

    """Save MTIR map to cache if available."""
    def _save_mtir_cache(
        self: JacCompiler, cache_key: CacheKey, program: JacProgram
    ) -> None {
        try {
            import from jaclang.jac0core.bccache { DiskBytecodeCache }
            if (
                isinstance(self._bytecode_cache, DiskBytecodeCache)
                and program.mtir_map
            ) {
                self._bytecode_cache.put_mtir(cache_key, program.mtir_map);
            }
        } except Exception {
            ;
        }
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

    """Get bytecode using 3-tier cache: in-memory -> disk -> compile.

        For native modules (.na.jac or files with na {} blocks), also handles
        LLVM IR caching to avoid full recompilation while still creating fresh
        JIT engines each process (required since engines can't be serialized).
        """
    def get_bytecode(
        self: JacCompiler, full_target: str, target_program: JacProgram
    ) -> (types.CodeType | None) {
        actual_program = self._resolve_program(full_target, target_program);
        if (
            (full_target in actual_program.mod.hub)
            and actual_program.mod.hub[full_target].gen.py_bytecode
        ) {
            codeobj = actual_program.mod.hub[full_target].gen.py_bytecode;
            return marshal.loads(codeobj) if isinstance(codeobj, `bytes) else None;
        }
        cache_key = CacheKey.for_source(full_target);
        if isinstance(self._bytecode_cache, DiskBytecodeCache) {
            cached_code = self._bytecode_cache.get(cache_key);
            if (cached_code is not None) {
                cached_ir = self._bytecode_cache.get_llvmir(cache_key);
                if (cached_ir is not None and cached_ir != "") {
                    cached_interop = self._bytecode_cache.get_interop(cache_key);
                    self._load_native_from_cache(
                        full_target, actual_program, cached_ir, cached_interop
                    );
                }
                self._load_mtir_cache(cache_key, actual_program);
                return cached_code;
            }
        }
        is_internal = actual_program is self._internal_program;
        if is_internal {
            setup_progress.on_internal_compile(full_target);
        }
        options = CompileOptions();
        result = self.compile(
            file_path=full_target, target_program=actual_program, options=options
        );
        if result.gen.py_bytecode {
            if isinstance(self._bytecode_cache, DiskBytecodeCache) {
                self._bytecode_cache.put(cache_key, result.gen.py_bytecode);
                self._save_mtir_cache(cache_key, actual_program);
                if (result.gen.llvm_ir is not None) {
                    self._bytecode_cache.put_llvmir(cache_key, str(result.gen.llvm_ir));
                    self._cache_interop_manifest(cache_key, result);
                } else {
                    self._bytecode_cache.put_llvmir(cache_key, "");
                }
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

    """Cache interop manifest data for native module.

        Serializes the interop bindings to a pickle-able format.
        """
    def _cache_interop_manifest(
        self: JacCompiler, cache_key: CacheKey, result: uni.Module
    ) -> None {
        if not isinstance(self._bytecode_cache, DiskBytecodeCache) {
            return;
        }
        manifest = getattr(result.gen, 'interop_manifest', None);
        if (manifest is None) {
            return;
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
        self._bytecode_cache.put_interop(cache_key, interop_data);
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
            import from jaclang.compiler.passes.main { PyastBuildPass }
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
            if had_error {
                mod.has_syntax_errors = True;
            }
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
            target_program.mod = uni.ProgramModule(mod);
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
        mod_targ = self.parse_str(
            keep_str, file_path, actual_program, cancel_token=options.cancel_token
        );
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
        if (not mod_targ.has_syntax_errors and not options.no_cgen) {
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
        passes: list[type[Transform[(uni.Module, uni.Module)]]],
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
            current_mod.has_syntax_errors = True;
            prog.mod = uni.ProgramModule(current_mod);
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
        prog.mod = uni.ProgramModule(current_mod);
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
            current_mod.has_syntax_errors = True;
            prog.mod = uni.ProgramModule(current_mod);
            return prog;
        }
        for pass_cls in get_format_sched(auto_lint=auto_lint) {
            current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out;
        }
        prog.mod = uni.ProgramModule(current_mod);
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
        prog.mod = uni.ProgramModule(current_mod);
        return prog;
    }
}
