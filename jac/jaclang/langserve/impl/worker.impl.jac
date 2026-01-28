"""Implementation of worker process for background compilation and LSP queries.

The worker process handles both:
1. Compilation (with cancel_token for interruptibility)
2. Foreground LSP requests (hover, definition, etc.)

Foreground requests have priority - they cancel ongoing compilation,
get handled immediately, then compilation restarts.
"""

import sys;
import time;
import threading;
import multiprocessing;
import from multiprocessing { Queue as MpQueue, Process }
import from multiprocessing.synchronize { Event as MpEvent }
import from typing { Optional, Callable }
import from queue { Empty }
import from jaclang.langserve.sem_manager { SemTokManager }
import from jaclang.langserve { utils }
import jaclang.pycore.unitree as uni;
import from jaclang.compiler.type_system.types {
    ClassType,
    FunctionType,
    OverloadedType,
    ModuleType
}
import from jaclang.compiler.type_system.type_utils { get_completion_items }
import from jaclang.pycore.unitree { UniScopeNode }
import from jaclang.pycore.passes { Alert }
import from jaclang.pycore.program { JacProgram }

impl WorkerConfig.default -> WorkerConfig {
    return WorkerConfig();
}

# ============== Request Parameter Containers ==============
impl PositionParams.from_request(
    request: dict
) -> PositionParams {
    return PositionParams(
        request_id=request.get('request_id', ''),
        file_path=request.get('file_path', ''),
        line=request.get('line', 0),
        character=request.get('character', 0)
    );
}

impl FileParams.from_request(request: dict) -> FileParams {
    return FileParams(
        request_id=request.get('request_id', ''),
        file_path=request.get('file_path', '')
    );
}

# ============== Response Builders ==============
impl _success(
    request_id: str, **data: dict
) -> dict {
    return {'request_id': request_id, 'success': True, ** data};
}

impl _error(request_id: str, msg: str, tb: str | None = None) -> dict {
    result = {'request_id': request_id, 'success': False, 'error_message': msg};
    if tb {
        result['error_traceback'] = tb;
    }
    return result;
}

impl _cancelled(request_id: str) -> dict {
    return {'request_id': request_id, 'success': False, 'cancelled': True};
}

impl _location_response(request_id: str, location: dict | None) -> dict {
    return {'request_id': request_id, 'success': True, 'location': location};
}

# ============== Request Builders ==============
impl _build_position_request(
    request_type: str, request_id: str, file_path: str, line: int, character: int
) -> dict {
    return {
        'request_type': request_type,
        'request_id': request_id,
        'file_path': file_path,
        'line': line,
        'character': character
    };
}

impl _build_file_request(request_type: str, request_id: str, file_path: str) -> dict {
    return {
        'request_type': request_type,
        'request_id': request_id,
        'file_path': file_path
    };
}

# ============== CompilationWorker (runs in separate process) ==============
"""CompilationWorker fields are set directly via constructor kwargs."""
impl CompilationWorker.run -> None {
    import from jaclang.pycore.program { JacProgram }
    import traceback;
    program = JacProgram();
    sem_managers: dict[str, SemTokManager] = {};
    poll_interval = self._config.poll_interval_ms / 1000.0;
    while not self._shutdown_event.is_set() {
        self.process_foreground_requests(program, sem_managers);
        try {
            request = self._request_queue.get(timeout=poll_interval);
        } except Empty {
            continue;
        }
        self.clear_cancellation();
        request_id = request.get('request_id', '');
        request_type = request.get('request_type', '');
        try {
            if request_type == 'SHUTDOWN' {
                break;
            } elif request_type == 'COMPILE_FILE' {
                self._response_queue.put(
                    self._compile_file(request, program, sem_managers)
                );
            }
        } except Exception as e {
            self._response_queue.put(
                _error(request_id, str(e), traceback.format_exc())
            );
        }
    }
}

impl CompilationWorker.has_foreground_request -> bool {
    if self._foreground_queue is None {
        return False;
    }
    try {
        return not self._foreground_queue.empty();
    } except Exception {
        return False;
    }
}

impl CompilationWorker.process_foreground_requests(
    program: JacProgram, sem_managers: dict[str, SemTokManager]
) -> None {
    import traceback;
    if self._foreground_queue is None {
        return;
    }
    while True {
        try {
            request = self._foreground_queue.get_nowait();
        } except Empty {
            break;
        }

        request_id = request.get('request_id', '');
        request_type = request.get('request_type', '');
        try {
            response = self._dispatch_foreground(
                request_type, request, program, sem_managers
            );
            self._response_queue.put(response);
        } except Exception as e {
            self._response_queue.put(
                _error(request_id, str(e), traceback.format_exc())
            );
        }
    }
}

impl CompilationWorker._dispatch_foreground(
    request_type: str,
    request: dict,
    program: JacProgram,
    sem_managers: dict[str, SemTokManager]
) -> dict {
    if request_type == 'HOVER' {
        return self.handle_hover(request, program, sem_managers);
    } elif request_type == 'DEFINITION' {
        return self.handle_definition(request, program, sem_managers);
    } elif request_type == 'REFERENCES' {
        return self.handle_references(request, program, sem_managers);
    } elif request_type == 'COMPLETION' {
        return self.handle_completion(request, program, sem_managers);
    } elif request_type == 'OUTLINE' {
        return self.handle_outline(request, program, sem_managers);
    } elif request_type == 'SEMANTIC_TOKENS' {
        return self.handle_semantic_tokens(request, program, sem_managers);
    } elif request_type == 'RENAME' {
        return self.handle_rename(request, program, sem_managers);
    } elif request_type == 'FORMAT' {
        return self.handle_format(request, program);
    } else {
        return _error(request.get('request_id', ''), f'Unknown: {request_type}');
    }
}

impl CompilationWorker._compile_file(
    request: dict, program: JacProgram, sem_managers: dict[str, SemTokManager]
) -> dict {
    import from threading { Event }
    import hashlib;
    start = time.time();
    request_id = request.get('request_id', '');
    file_uri = request.get('file_uri', '');
    # Convert URI to path
    file_path = file_uri[7:] if file_uri.startswith("file://") else file_uri;
    if not file_path {
        return _error(request_id, 'Missing file_uri');
    }
    # Read source from disk (saved files only)
    try {
        with open(file_path, 'r') as f {
            source = f.read();
        }
    } except Exception as e {
        return _error(request_id, f'Cannot read file: {e}');
    }
    # Check if source has changed using module.source.hash from hub
    source_hash = hashlib.md5(source.encode()).hexdigest();
    existing_module = program.mod.hub.get(file_path);
    if existing_module and existing_module?.source and existing_module.source {
        if existing_module.source.hash == source_hash {
            # Ensure sem_managers entry exists even for cached modules
            if file_path not in sem_managers and existing_module?.loc {
                sem_managers[file_path] = SemTokManager(
                    ir=existing_module, hub=program.mod.hub
                );
            }
            return _success(
                request_id,
                file_path=file_path,
                diagnostics=self._serialize_diagnostics(file_path, program),
                hub_files=list(program.mod.hub.keys()),
                duration_ms=(time.time() - start) * 1000,
                cached=True
            );
        }
    }
    # Clear old errors for this file
    program.errors_had = [
        e
        for e in program.errors_had
        if not (e?.loc?.mod_path == file_path)
    ];
    program.warnings_had = [
        w
        for w in program.warnings_had
        if not (w?.loc?.mod_path == file_path)
    ];
    if self.is_cancelled() or self.has_foreground_request() {
        return _cancelled(request_id);
    }
    # Create cancel token from our cancel event for fine-grained cancellation
    cancel_token = self._cancel_event;
    # Compile with cancel_token for interruptibility
    module = program.compile(
        file_path=file_path,
        use_str=source,
        type_check=True,
        no_cgen=True,
        cancel_token=cancel_token
    );
    # Collect errors from internal_program (compiler routes jaclang/* files there)
    self._collect_internal_errors(program, file_path);
    if self.is_cancelled() or self.has_foreground_request() {
        return _cancelled(request_id);
    }
    if module?.loc {
        program.mod.hub[file_path] = module;
        sem_managers[file_path] = SemTokManager(ir=module, hub=program.mod.hub);
    }
    # Handle impl files
    if module?.annexable_by {
        parent_path = module.annexable_by;
        try {
            with open(parent_path, 'r') as f {
                parent_source = f.read();
            }
            program.errors_had = [
                e
                for e in program.errors_had
                if not (e?.loc?.mod_path == parent_path)
            ];
            program.warnings_had = [
                w
                for w in program.warnings_had
                if not (w?.loc?.mod_path == parent_path)
            ];
            parent_module = program.compile(
                file_path=parent_path,
                use_str=parent_source,
                type_check=True,
                no_cgen=True,
                cancel_token=cancel_token
            );
            self._collect_internal_errors(program, parent_path);
            if parent_module?.loc {
                program.mod.hub[parent_path] = parent_module;
                sem_managers[parent_path] = SemTokManager(
                    ir=parent_module, hub=program.mod.hub
                );
            }
            # Refresh impl file sem_managers after parent compilation
            # (parent compilation may update the impl module's AST)
            impl_module = program.mod.hub.get(file_path);
            if impl_module?.loc {
                sem_managers[file_path] = SemTokManager(
                    ir=impl_module, hub=program.mod.hub
                );
            }
        } except Exception { }
    }
    return _success(
        request_id,
        file_path=file_path,
        diagnostics=self._serialize_diagnostics(file_path, program),
        hub_files=list(program.mod.hub.keys()),
        duration_ms=(time.time() - start) * 1000
    );
}

impl CompilationWorker._serialize_diagnostics(
    file_path: str, program: JacProgram
) -> dict {
    def serialize_item(item: Alert) -> dict | None {
        if item?.loc {
            return {
                'message': item.msg,
                'mod_path': item.loc.mod_path,
                'line': item.loc.first_line,
                'col': item.loc.col_start,
                'end_line': item.loc.last_line,
                'end_col': item.loc.col_end
            };
        }
        return None;
    }
    return {
        'errors': [
            d
            for e in program.errors_had
            if (d := serialize_item(e))
        ],
        'warnings': [
            d
            for w in program.warnings_had
            if (d := serialize_item(w))
        ]
    };
}

# ============== Foreground Request Handlers ==============
impl CompilationWorker.handle_hover(
    request: dict, program: JacProgram, sem_managers: dict[str, SemTokManager]
) -> dict {
    p = PositionParams.from_request(request);
    sym_node = self._get_token_at_position(
        p.file_path, p.line, p.character, sem_managers, program.mod.hub
    );
    if sym_node {
        if hover_text := self._get_node_info(sym_node) {
            return _success(p.request_id, hover_text=hover_text);
        }
    }
    return _success(p.request_id, hover_text=None);
}

"""Return definition location for a file."""
impl CompilationWorker.handle_definition(
    request: dict, program: JacProgram, sem_managers: dict[str, SemTokManager]
) -> dict {
    p = PositionParams.from_request(request);
    node_selected = self._get_token_at_position(
        p.file_path, p.line, p.character, sem_managers, program.mod.hub
    );
    if not node_selected {
        return _location_response(p.request_id, None);
    }
    node_type = node_selected.type;
    parent = node_selected.parent;
    # Check for impl body first (stub -> impl navigation)
    if isinstance(parent, uni.AstImplNeedingNode) and parent.body {
        if isinstance(parent.body, uni.ImplDef) {
            return _location_response(
                p.request_id, self._make_location_dict(parent.body.sym.decl)
            );
        }
    }
    # Handle go to def for types and variables
    if node_type {
        if isinstance(node_type, ModuleType) {
            return _location_response(
                p.request_id,
                {
                    'uri': str(node_type.file_uri),
                    'line': 0,
                    'character': 0,
                    'end_line': 0,
                    'end_character': 0
                }
            );
        } elif isinstance(node_type, (ClassType, FunctionType, OverloadedType)) {
            return _location_response(
                p.request_id,
                self._make_location_dict(node_selected.sym.decl)
                if node_selected.sym
                else None
            );
        }
    }
    # Ad-hoc handling for impl-def go to def
    if not parent {
        return _location_response(p.request_id, None);
    }
    if isinstance(parent, uni.ImplDef) and parent.decl_link {
        return _location_response(
            p.request_id, self._make_location_dict(parent.decl_link.sym.decl)
        );
    }
    # Fallback: use symbol resolution if available
    if node_selected.sym and node_selected.sym.defn {
        try {
            return _location_response(
                p.request_id, self._make_location_dict(node_selected.sym.defn[0])
            );
        } except Exception { }
    }
    return _location_response(p.request_id, None);
}

"""Create a location dict from an AST node."""
impl CompilationWorker._make_location_dict(ast_node: uni.UniNode) -> dict | None {
    import os;
    if not ast_node or not ast_node?.loc or not ast_node.loc {
        return None;
    }
    loc = ast_node.loc;
    # Normalize the path to resolve any ../.. components
    mod_path = os.path.normpath(loc.mod_path) if loc.mod_path else '';
    return {
        'uri': mod_path,
        'line': max(0, loc.first_line - 1),  # Convert to 0-indexed, ensure >= 0
        'character': max(0, loc.col_start - 1),  # Ensure >= 0
        'end_line': max(0, loc.last_line - 1),
        'end_character': max(0, loc.col_end - 1)
    };
}

impl CompilationWorker.handle_references(
    request: dict, program: JacProgram, sem_managers: dict[str, SemTokManager]
) -> dict {
    p = PositionParams.from_request(request);
    sym_node = self._get_token_at_position(
        p.file_path, p.line, p.character, sem_managers, program.mod.hub
    );
    locations = [];
    if sym_node and sym_node?.sym and sym_node.sym {
        for use_node in sym_node.sym.uses {
            if loc := self._make_location_dict(use_node) {
                locations.append(loc);
            }
        }
    }
    return _success(p.request_id, locations=locations);
}

impl CompilationWorker.handle_completion(
    request: dict, program: JacProgram, sem_managers: dict[str, SemTokManager]
) -> dict {
    p = PositionParams.from_request(request);
    items = [];
    try {
        tok = self._get_node_at_position(
            p.file_path, p.line, p.character - 1, program.mod.hub
        );
        if tok and isinstance(tok, uni.Token) {
            if tok.name == "DOT" {
                if isinstance(tok.parent, uni.AtomTrailer) {
                    items = self._get_completion_for_node(tok.parent.target, program);
                }
            } elif tok.name == "NAME" {
                if tok.parent and isinstance(tok.parent, uni.AtomTrailer) {
                    items = self._get_completion_for_node(tok.parent.target, program);
                } elif scope_node := tok.find_parent_of_type(UniScopeNode) {
                    items = self._get_completion_for_scope(scope_node);
                }
            }
        }
    } except Exception { }
    return _success(p.request_id, items=items);
}

impl CompilationWorker._get_completion_for_node(
    expr_node: uni.Expr, program: JacProgram
) -> list {
    # Get completion items for a node's type
    items = [];
    try {
        if isinstance(expr_node, uni.Expr) {
            type_eval = program.get_type_evaluator();
            node_type = type_eval.get_type_of_expression(expr_node);
            if node_type {
                for item in get_completion_items(node_type) {
                    items.append(
                        {
                            'label': item.label,
                            'kind': item.kind?.value or item.kind,
                            'detail': item.detail
                        }
                    );
                }
            }
        }
    } except Exception { }
    return items;
}

impl CompilationWorker._get_completion_for_scope(scope_node: uni.UniScopeNode) -> list {
    # Get completion items for a scope
    items = [];
    try {
        for item in get_completion_items(scope_node) {
            items.append(
                {
                    'label': item.label,
                    'kind': item.kind?.value or item.kind,
                    'detail': item.detail
                }
            );
        }
    } except Exception { }
    return items;
}

impl CompilationWorker.handle_outline(
    request: dict, program: JacProgram, sem_managers: dict[str, SemTokManager]
) -> dict {
    f = FileParams.from_request(request);
    symbols = [];
    if f.file_path in program.mod.hub {
        module = program.mod.hub[f.file_path];
        if module and module?.sym_tab and module.sym_tab {
            symbols = utils.get_symbols_for_outline_dict(module.sym_tab);
        }
    }
    return _success(f.request_id, symbols=symbols);
}

impl CompilationWorker.handle_semantic_tokens(
    request: dict, program: JacProgram, sem_managers: dict[str, SemTokManager]
) -> dict {
    f = FileParams.from_request(request);
    tokens = [];
    if f.file_path in sem_managers {
        if sem_mgr := sem_managers[f.file_path] {
            tokens = sem_mgr.sem_tokens;
        }
    }
    return _success(f.request_id, tokens=tokens);
}

impl CompilationWorker.handle_rename(
    request: dict, program: JacProgram, sem_managers: dict[str, SemTokManager]
) -> dict {
    p = PositionParams.from_request(request);
    new_name = request.get('new_name', '');
    sym_node = self._get_token_at_position(
        p.file_path, p.line, p.character, sem_managers, program.mod.hub
    );
    edits = {};
    if sym_node and sym_node?.sym and sym_node.sym {
        all_nodes = [*sym_node.sym.uses];
        if sym_node.sym.defn {
            all_nodes.append(sym_node.sym.defn[0]);
        }
        for edit_node in all_nodes {
            if edit_node and edit_node?.loc and edit_node.loc {
                uri = edit_node.loc.mod_path;
                if uri not in edits {
                    edits[uri] = [];
                }
                edits[uri].append(
                    {
                        'line': edit_node.loc.first_line - 1,
                        'character': edit_node.loc.col_start - 1,
                        'end_line': edit_node.loc.last_line - 1,
                        'end_character': edit_node.loc.col_end - 1,
                        'new_text': new_name
                    }
                );
            }
        }
    }
    return _success(p.request_id, edits=edits);
}

impl CompilationWorker.handle_format(request: dict, program: JacProgram) -> dict {
    import from jaclang.pycore.program { JacProgram }
    f = FileParams.from_request(request);
    source = request.get('source', '');
    try {
        prog = JacProgram.jac_str_formatter(source_str=source, file_path=f.file_path);
        formatted = prog.mod.main.gen.jac if not prog.errors_had else source;
        return _success(f.request_id, formatted=formatted);
    } except Exception {
        return _success(f.request_id, formatted=source);
    }
}

# ============== Helper Methods ==============
impl CompilationWorker._get_token_at_position(
    file_path: str,
    line: int,
    character: int,
    sem_managers: dict[str, SemTokManager],
    hub: dict
) -> uni.AstSymbolNode | None {
    # Get the AST token at the given position
    if file_path not in hub {
        return None;
    }
    sem_mgr = sem_managers.get(file_path);
    if not sem_mgr {
        return None;
    }
    try {
        token_index = utils.find_index(sem_mgr.sem_tokens, line, character);
        if token_index is not None {
            return sem_mgr.static_sem_tokens[token_index][3];
        }
    } except Exception { }
    return None;
}

impl CompilationWorker._get_node_at_position(
    file_path: str, line: int, col: int, hub: dict
) -> uni.Token | None {
    # Get AST node at position by walking the tree
    if file_path not in hub {
        return None;
    }
    ast = hub[file_path];
    if not ast {
        return None;
    }
    try {
        for ast_node in ast._in_mod_nodes {
            if isinstance(ast_node, uni.Token)
            and utils.position_within_node(ast_node, line + 1, col + 1) {
                return ast_node;
            }
        }
    } except Exception { }
    return None;
}

impl CompilationWorker._get_node_info(sym_node: uni.AstSymbolNode) -> str | None {
    # Get hover information for a symbol node
    try {
        if isinstance(sym_node, uni.NameAtom) {
            sym_node = sym_node.name_of;
        }

        if not sym_node?.sym or not sym_node.sym {
            return None;
        }

        access = (sym_node.sym.access.value + ' ') if sym_node.sym.access else '';
        node_info = f"({access}{sym_node.sym_category.value}) {sym_node.sym_name}";

        if sym_node?.name_spec and sym_node.name_spec and sym_node.name_spec.clean_type {
            node_info += f": {sym_node.name_spec.clean_type}";
        }

        if isinstance(sym_node, uni.AstSymbolNode) {
            if sym_node?.name_spec and sym_node.name_spec {
                if isinstance(sym_node.name_spec.type, ClassType) {
                    node_info += f": {sym_node.name_spec.type.shared.class_name}";
                }
            }
        }

        if isinstance(sym_node, uni.AstDocNode) and sym_node.doc {
            node_info += f"\n{sym_node.doc.value}";
        }

        if isinstance(sym_node, uni.Ability) and sym_node.signature {
            node_info += f"\n{sym_node.signature.unparse()}";
        }

        return node_info.strip();
    } except AttributeError {
        return None;
    }
}

impl CompilationWorker.is_cancelled -> bool {
    return self._cancel_event.is_set() if self._cancel_event else False;
}

impl CompilationWorker.clear_cancellation -> None {
    if self._cancel_event {
        self._cancel_event.clear();
    }
}

"""Collect errors from compiler's internal_program for jaclang/* files.

The compiler routes jaclang/* files to a separate internal_program,
so errors end up there instead of the target program the LSP checks.
"""
impl CompilationWorker._collect_internal_errors(
    program: JacProgram, file_path: str
) -> None {
    try {
        compiler = program._get_compiler();
        internal = compiler._internal_program;
        if internal is None or internal is program {
            return;
        }
        for e in internal.errors_had {
            if e?.loc?.mod_path == file_path {
                program.errors_had.append(e);
            }
        }
        for w in internal.warnings_had {
            if w?.loc?.mod_path == file_path {
                program.warnings_had.append(w);
            }
        }
        # Clear collected errors from internal_program to avoid duplicates on recompile
        internal.errors_had = [
            e
            for e in internal.errors_had
            if not (e?.loc?.mod_path == file_path)
        ];
        internal.warnings_had = [
            w
            for w in internal.warnings_had
            if not (w?.loc?.mod_path == file_path)
        ];
    } except Exception as e {
        print(f"[Worker] _collect_internal_errors failed: {e}", file=sys.stderr);
    }
}

# ============== WorkerManager (runs in main process) ==============
impl WorkerManager.postinit -> None {
    self._config = self._config or WorkerConfig.default();
    self._request_counter = 0;
    self._pending_requests = {};
    self._running = False;
    self._diagnostics_callback = None;
    self._current_request_id = None;
    self._dirty_files = set();
    self._compiling_uri = None;
    self._timer = None;
    self._timer_lock = threading.Lock();
    self._last_activity = 0;
    self._analysis_in_progress = False;
    self._foreground_queue = None;
}

impl WorkerManager._next_request_id -> str {
    self._request_counter += 1;
    return f"req_{self._request_counter}";
}

impl WorkerManager.start -> None {
    if self._process and self._process.is_alive() {
        return;
    }
    self._request_queue = multiprocessing.Queue();
    self._response_queue = multiprocessing.Queue();
    self._foreground_queue = multiprocessing.Queue();  # High-priority LSP requests
    self._shutdown_event = multiprocessing.Event();
    self._cancel_event = multiprocessing.Event();
    config_dict = {
        'poll_interval_ms': self._config.poll_interval_ms,
        'shutdown_timeout_ms': self._config.shutdown_timeout_ms
    };
    self._process = multiprocessing.Process(
        target=worker_process_main,
        args=(
            self._request_queue,
            self._response_queue,
            self._shutdown_event,
            self._cancel_event,
            config_dict,
            self._foreground_queue  # Pass foreground queue to worker
        ),
        daemon=True
    );
    self._process.start();
    self._running = True;
}

impl WorkerManager.stop -> None {
    if not self._process {
        return;
    }
    self._running = False;
    self._cancel_timer();
    try {
        self._request_queue.put(
            {'request_type': 'SHUTDOWN', 'request_id': self._next_request_id()}
        );
    } except Exception { }
    self._shutdown_event.set();
    self._process.join(timeout=self._config.shutdown_timeout_ms / 1000.0);
    if self._process.is_alive() {
        self._process.terminate();
    }
    self._process = None;
}

impl WorkerManager.is_running -> bool {
    return self._running and self._process is not None and self._process.is_alive();
}

impl WorkerManager.schedule_file(file_uri: str) -> None {
    if not self._running {
        self.start();
    }
    self._last_activity = time.time();
    self._dirty_files.add(file_uri);
    if self._analysis_in_progress {
        self.cancel_current();
    }
    self._reset_timer();
}

impl WorkerManager.has_pending -> bool {
    return len(self._dirty_files) > 0;
}

impl WorkerManager.is_busy -> bool {
    with self._timer_lock {
        has_timer = self._timer is not None and self._timer.is_alive();
    }
    return self.has_pending() or has_timer or self._analysis_in_progress;
}

impl WorkerManager._reset_timer -> None {
    with self._timer_lock {
        if self._timer {
            self._timer.cancel();
        }
        self._timer = threading.Timer(
            self._config.debounce_ms / 1000.0, self._on_timer_expired
        );
        self._timer.daemon = True;
        self._timer.start();
    }
}

impl WorkerManager._cancel_timer -> None {
    with self._timer_lock {
        if self._timer {
            self._timer.cancel();
            self._timer = None;
        }
    }
}

impl WorkerManager._on_timer_expired -> None {
    if not self._running {
        return;
    }
    elapsed = (time.time() - self._last_activity) * 1000;
    if elapsed < self._config.debounce_ms {
        with self._timer_lock {
            self._timer = threading.Timer(
                (self._config.debounce_ms - elapsed) / 1000.0, self._on_timer_expired
            );
            self._timer.daemon = True;
            self._timer.start();
        }
        return;
    }
    self._process_pending();
}

impl WorkerManager._process_pending -> None {
    if not self._running or not self._dirty_files {
        return;
    }
    file_uri = self._dirty_files.pop();
    self._analysis_in_progress = True;
    self.compile_file(file_uri);
}

impl WorkerManager.compile_file(
    file_uri: str, callback: Optional[Callable] = None
) -> str {
    if not self.is_running() {
        self.start();
    }
    if self._current_request_id {
        self.cancel_current();
    }
    request_id = self._next_request_id();
    self._current_request_id = request_id;
    self._compiling_uri = file_uri;
    request = {
        'request_type': 'COMPILE_FILE',
        'request_id': request_id,
        'file_uri': file_uri
    };
    if callback {
        self._pending_requests[request_id] = callback;
    }
    self._request_queue.put(request);
    return request_id;
}

impl WorkerManager.cancel_current -> None {
    if self._cancel_event {
        self._cancel_event.set();
    }
    self._analysis_in_progress = False;
}

# ============== Foreground Request Methods (blocking) ==============
impl WorkerManager._send_foreground_request(
    request: dict, timeout_ms: float
) -> dict | None {
    if not self.is_running() {
        self.start();
    }
    self.cancel_current();
    self._foreground_queue.put(request);
    timeout_sec = timeout_ms / 1000.0;
    try {
        response = self._response_queue.get(timeout=timeout_sec);
        if response.get('request_id') == request.get('request_id') {
            return response;
        }
        self._handle_response(response);
        return self._response_queue.get(timeout=timeout_sec / 2);
    } except Empty {
        return None;
    }
}

impl WorkerManager.request_hover(
    file_path: str, line: int, character: int, timeout_ms: float = 5000
) -> dict | None {
    return self._send_foreground_request(
        _build_position_request(
            'HOVER', self._next_request_id(), file_path, line, character
        ),
        timeout_ms
    );
}

impl WorkerManager.request_definition(
    file_path: str, line: int, character: int, timeout_ms: float = 5000
) -> dict | None {
    return self._send_foreground_request(
        _build_position_request(
            'DEFINITION', self._next_request_id(), file_path, line, character
        ),
        timeout_ms
    );
}

impl WorkerManager.request_references(
    file_path: str, line: int, character: int, timeout_ms: float = 5000
) -> dict | None {
    return self._send_foreground_request(
        _build_position_request(
            'REFERENCES', self._next_request_id(), file_path, line, character
        ),
        timeout_ms
    );
}

impl WorkerManager.request_completion(
    file_path: str,
    line: int,
    character: int,
    trigger: str | None = None,
    timeout_ms: float = 5000
) -> dict | None {
    req = _build_position_request(
        'COMPLETION', self._next_request_id(), file_path, line, character
    );
    req['trigger'] = trigger;
    return self._send_foreground_request(req, timeout_ms);
}

impl WorkerManager.request_outline(
    file_path: str, timeout_ms: float = 5000
) -> dict | None {
    return self._send_foreground_request(
        _build_file_request('OUTLINE', self._next_request_id(), file_path), timeout_ms
    );
}

impl WorkerManager.request_semantic_tokens(
    file_path: str, timeout_ms: float = 5000
) -> dict | None {
    return self._send_foreground_request(
        _build_file_request('SEMANTIC_TOKENS', self._next_request_id(), file_path),
        timeout_ms
    );
}

impl WorkerManager.request_rename(
    file_path: str, line: int, character: int, new_name: str, timeout_ms: float = 5000
) -> dict | None {
    req = _build_position_request(
        'RENAME', self._next_request_id(), file_path, line, character
    );
    req['new_name'] = new_name;
    return self._send_foreground_request(req, timeout_ms);
}

impl WorkerManager.request_format(
    file_path: str, source: str, timeout_ms: float = 5000
) -> dict | None {
    req = _build_file_request('FORMAT', self._next_request_id(), file_path);
    req['source'] = source;
    return self._send_foreground_request(req, timeout_ms);
}

impl WorkerManager.process_pending_responses -> None {
    while True {
        try {
            response = self._response_queue.get_nowait();
        } except Empty {
            break;
        }
        self._handle_response(response);
    }
    if self._process and not self._process.is_alive() and self._running {
        self._running = False;
    }
}

impl WorkerManager._handle_response(response: dict) -> None {
    request_id = response.get('request_id', '');
    if self._current_request_id == request_id {
        self._current_request_id = None;
    }
    if response.get('cancelled', False) {
        self._pending_requests.pop(request_id, None);
        # Reschedule the cancelled compilation
        if self._compiling_uri {
            self._dirty_files.add(self._compiling_uri);
        }
        self._compiling_uri = None;
        if self._dirty_files {
            self._reset_timer();
        }
        return;
    }
    if request_id in self._pending_requests {
        try {
            self._pending_requests.pop(request_id)(response);
        } except Exception { }
    }
    if response.get('success', False) and response.get('diagnostics') {
        self._analysis_in_progress = False;
        self._compiling_uri = None;
        if self._diagnostics_callback {
            try {
                self._diagnostics_callback(response);
            } except Exception { }
        }
        # Process next dirty file if any
        if self._dirty_files {
            self._reset_timer();
        }
    } elif not response.get('success', False) {
        self._analysis_in_progress = False;
        self._compiling_uri = None;
        if self._dirty_files {
            self._reset_timer();
        }
    }
}

impl WorkerManager.set_diagnostics_callback(callback: Callable) -> None {
    self._diagnostics_callback = callback;
}

impl worker_process_main(
    request_queue: MpQueue,
    response_queue: MpQueue,
    shutdown_event: MpEvent,
    cancel_event: MpEvent,
    config_dict: dict,
    foreground_queue: MpQueue | None = None
) -> None {
    config = WorkerConfig(
        poll_interval_ms=config_dict.get('poll_interval_ms', 100),
        shutdown_timeout_ms=config_dict.get('shutdown_timeout_ms', 5000)
    );
    worker = CompilationWorker(
        _request_queue=request_queue,
        _response_queue=response_queue,
        _shutdown_event=shutdown_event,
        _cancel_event=cancel_event,
        _config=config,
        _foreground_queue=foreground_queue
    );
    worker.run();
}
