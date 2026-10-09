import from jaclang.compiler.frontend.roles { BodyRole }
import from jaclang.compiler.passes.context { CompileContext, CompilerPass }
import from jaclang.compiler.passes.scope_walk { ScopeWalker }
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    AssertStmt,
    Assignment,
    AtomTrailer,
    AtomUnit,
    AwaitExpr,
    BinaryExpr,
    Bool,
    BoolExpr,
    CompareExpr,
    ConnectOp,
    CtrlStmt,
    DictCompr,
    DictVal,
    DisconnectOp,
    DisengageStmt,
    EdgeOpRef,
    ElseIf,
    ElseStmt,
    EventSignature,
    ExprStmt,
    FString,
    FilterCompr,
    FinallyStmt,
    Float,
    ForeverStmt,
    FormattedValue,
    FuncCall,
    IfElseExpr,
    IfStmt,
    ImplDef,
    ImplImport,
    Import,
    InForStmt,
    InnerCompr,
    Int,
    IterForStmt,
    JsxExpression,
    JsxNormalAttribute,
    JsxSpreadAttribute,
    KVPair,
    KWPair,
    LambdaExpr,
    ListCompr,
    ListVal,
    MatchPattern,
    Module,
    ModuleItem,
    ModulePath,
    Name,
    NameAtom,
    Null,
    ParamVar,
    RaiseStmt,
    ReturnStmt,
    Semi,
    SetVal,
    Symbol,
    Test,
    Token,
    TupleVal,
    UnaryExpr,
    UniNode,
    UniScopeNode,
    WhileStmt,
    YieldExpr,
    in_type_position,
    is_identifier_slot,
    same_lexical_scope
}

import from jaclang.compiler.frontend.constant { ExprCtx, SymbolType }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.frontend.diagnostics {
    W1103,
    W2001,
    W2002,
    W2003,
    W2058,
    W2063,
    W2070,
    W2074,
    W2075,
    W2084,
    E1122,
    E1123,
    E1125,
    E2018,
    E2027,
    E2055,
    E2083,
    E2085,
    E2086,
    E2097
}

glob BUILTIN_NAMES: set[str] = {
         'ArithmeticError',
         'AssertionError',
         'AttributeError',
         'BaseException',
         'BaseExceptionGroup',
         'BlockingIOError',
         'BrokenPipeError',
         'BufferError',
         'BytesWarning',
         'ChildProcessError',
         'ConnectionAbortedError',
         'ConnectionError',
         'ConnectionRefusedError',
         'ConnectionResetError',
         'DeprecationWarning',
         'EOFError',
         'Ellipsis',
         'EncodingWarning',
         'EnvironmentError',
         'Exception',
         'ExceptionGroup',
         'False',
         'FileExistsError',
         'FileNotFoundError',
         'FloatingPointError',
         'FutureWarning',
         'GeneratorExit',
         'IOError',
         'ImportError',
         'ImportWarning',
         'IndentationError',
         'IndexError',
         'InterruptedError',
         'IsADirectoryError',
         'KeyError',
         'KeyboardInterrupt',
         'LookupError',
         'MemoryError',
         'ModuleNotFoundError',
         'NameError',
         'None',
         'NotADirectoryError',
         'NotImplemented',
         'NotImplementedError',
         'OSError',
         'OverflowError',
         'PendingDeprecationWarning',
         'PermissionError',
         'ProcessLookupError',
         'PythonFinalizationError',
         'RecursionError',
         'ReferenceError',
         'ResourceWarning',
         'RuntimeError',
         'RuntimeWarning',
         'StopAsyncIteration',
         'StopIteration',
         'SyntaxError',
         'SyntaxWarning',
         'SystemError',
         'SystemExit',
         'TabError',
         'TimeoutError',
         'True',
         'TypeError',
         'UnboundLocalError',
         'UnicodeDecodeError',
         'UnicodeEncodeError',
         'UnicodeError',
         'UnicodeTranslateError',
         'UnicodeWarning',
         'UserWarning',
         'ValueError',
         'Warning',
         'ZeroDivisionError',
         '_IncompleteInputError',
         '__build_class__',
         '__debug__',
         '__doc__',
         '__import__',
         '__loader__',
         '__name__',
         '__package__',
         '__spec__',
         'abs',
         'aiter',
         'all',
         'anext',
         'any',
         'ascii',
         'bin',
         'bool',
         'breakpoint',
         'bytearray',
         'bytes',
         'callable',
         'chr',
         'classmethod',
         'compile',
         'complex',
         'copyright',
         'credits',
         'delattr',
         'dict',
         'dir',
         'divmod',
         'enumerate',
         'eval',
         'exec',
         'exit',
         'filter',
         'float',
         'format',
         'frozenset',
         'getattr',
         'globals',
         'hasattr',
         'hash',
         'help',
         'hex',
         'id',
         'input',
         'int',
         'isinstance',
         'issubclass',
         'iter',
         'len',
         'license',
         'list',
         'locals',
         'map',
         'max',
         'memoryview',
         'min',
         'next',
         'object',
         'oct',
         'open',
         'ord',
         'pow',
         'print',
         'property',
         'quit',
         'range',
         'repr',
         'reversed',
         'round',
         'set',
         'setattr',
         'slice',
         'sorted',
         'staticmethod',
         'str',
         'sum',
         'super',
         'tuple',
         'type',
         'vars',
         'zip'
     },
     DEPRECATED_TYPING_ALIASES: dict[str, str] = {
         'Dict': 'dict',
         'FrozenSet': 'frozenset',
         'List': 'list',
         'Set': 'set',
         'Tuple': 'tuple',
         'Type': 'type'
     },
     ITERATION_COMBINATORS: set[str] = {
         'every',
         'filter',
         'find',
         'findIndex',
         'findLast',
         'findLastIndex',
         'flatMap',
         'forEach',
         'map',
         'reduce',
         'reduceRight',
         'some',
         'sort',
         'toSorted'
     },
     KEEPING_METHODS: dict[str, set[str]] = {
         'list': {'append', 'extend', 'insert'},
         'set': {'add'}
     };

enum ClosureFate {
    IN_PLACE = 'in place',
    ENDS_LOOP = 'ends loop',
    OPAQUE = 'opaque',
    HELD = 'held'
}

type LoopStmt = InForStmt | IterForStmt | WhileStmt | ForeverStmt;
type Closure = Ability | LambdaExpr;

def is_bootstrap_compiled_module(mod_path: str) -> bool {
    import from jaclang.compiler.frontend.host { active_host }
    norm = mod_path.replace("\\", "/");
    if norm.startswith("jaclang/") {
        return active_host().is_seed_source(norm[len("jaclang/"):]);
    }
    marker = "/jaclang/";
    idx = norm.rfind(marker);
    if idx < 0 {
        return False;
    }
    return active_host().is_seed_source(norm[idx + len(marker):]);
}

def is_ambient_provider_module(mod_path: str) -> bool {
    return (mod_path.endswith("builtin.jac") or mod_path.endswith("builtin.py"))
        and "runtime" in mod_path;
}

def is_nested_function(nd: Ability) -> bool {
    return not nd.is_method and not isinstance(nd.parent, Module);
}

def scope_encloses(owner: UniScopeNode, nd: UniNode) -> bool {
    outer = nd.parent;
    while outer is not None {
        if same_lexical_scope(outer, owner) {
            return True;
        }
        outer = outer.parent;
    }
    return False;
}

def loop_repeats(loop: LoopStmt, part: UniNode) -> bool {
    if isinstance(loop, ForeverStmt) {
        return True;
    }
    if part is loop.else_body {
        return False;
    }
    if isinstance(loop, InForStmt) {
        return part is not loop.collection;
    }
    if isinstance(loop, IterForStmt) {
        return part is not loop.iter;
    }
    return True;
}

def callee_name(call: FuncCall) -> str {
    target = call.target;
    if isinstance(target, AtomTrailer) and target.is_attr {
        target = target.right;
    }
    return target.value if isinstance(target, Name) else '';
}

def worse_fate(left: ClosureFate, right: ClosureFate) -> ClosureFate {
    if left == ClosureFate.HELD or right == ClosureFate.HELD {
        return ClosureFate.HELD;
    }
    if left == ClosureFate.OPAQUE or right == ClosureFate.OPAQUE {
        return ClosureFate.OPAQUE;
    }
    if left == ClosureFate.ENDS_LOOP or right == ClosureFate.ENDS_LOOP {
        return ClosureFate.ENDS_LOOP;
    }
    return ClosureFate.IN_PLACE;
}

def keeping_receiver(call: FuncCall) -> (UniNode | None) {
    target = call.target;
    if not (isinstance(target, AtomTrailer) and target.is_attr) {
        return None;
    }
    method = target.right;
    if not isinstance(method, Name) or method.sym is None {
        return None;
    }
    owner = method.sym.parent_tab;
    if owner is None {
        return None;
    }
    kept = KEEPING_METHODS.get(owner.scope_name);
    if kept is None or method.value not in kept {
        return None;
    }
    home = owner.parent_scope;
    if isinstance(home, Module) and home.name == 'builtins' {
        return target.target;
    }
    return None;
}

def carries_over(sym: Symbol, store: Assignment) -> bool {
    if store.aug_op is not None {
        return True;
    }
    value = store.value;
    if value is None {
        return False;
    }
    for use in sym.uses {
        if use.expr_ctx == ExprCtx.LOAD and is_within(use, value) {
            return True;
        }
    }
    return False;
}

def comes_before(first: UniNode, second: UniNode) -> bool {
    if first.loc.first_line != second.loc.first_line {
        return first.loc.first_line < second.loc.first_line;
    }
    return first.loc.col_start < second.loc.col_start;
}

def runs_later(closure: Closure) -> bool {
    return isinstance(closure, Ability)
        and (closure.is_async or ModuleFacts.ability_is_generator(closure));
}

def makes_fresh_container(value: (UniNode | None)) -> bool {
    made = value;
    while isinstance(made, AtomUnit) {
        made = made.value;
    }
    return isinstance(made, (ListVal, TupleVal, SetVal, DictVal, ListCompr, DictCompr));
}

def reads_binding(name_nd: Name) -> bool {
    if name_nd.expr_ctx == ExprCtx.LOAD {
        return True;
    }
    store = name_nd.parent;
    return isinstance(store, Assignment) and store.aug_op is not None;
}

def store_root(target: UniNode) -> UniNode {
    base = target;
    while isinstance(base, AtomTrailer) {
        base = base.target;
    }
    return base;
}

def is_within(nd: UniNode, outer: UniNode) -> bool {
    cur: (UniNode | None) = nd;
    while cur is not None {
        if cur is outer {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

walker UnusedSymbolWalker(ScopeWalker) {
    has analysis: StaticAnalysisPass;

    can check_scope with UniScopeNode entry {
        self.analysis._check_unused_symbols(here);
    }
}

walker StaticAnalysisPass(CompilerPass) {
    has _in_place: dict[int, bool] = {};

    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def _check_unused_symbols(scope: UniScopeNode) -> None;
    def _check_undefined_names(mod: Module) -> None;
    def _literal_case_suggestion(name: str) -> (str | None);
    def _enclosing_class_member(name_nd: Name) -> (str | None);
    def _osp_shape_position(name_nd: Name) -> (str | None);
    def _native_type_position(name_nd: Name) -> (str | None);
    def _check_unreachable_code(mod: Module) -> None;
    def _check_semantic_patterns(mod: Module) -> None;
    def _check_typing_import_refusals(mod: Module) -> None;
    def _check_redundant_imports(mod: Module) -> None;
    def _check_client_imports(mod: Module) -> None;
    def _check_placement_warnings(mod: Module) -> None;
    def _check_loop_closure_captures(mod: Module) -> None;
    def _runs_in_place(closure: Closure) -> bool;
    def _closure_fate(
        closure: Closure, loop: (LoopStmt | None), seen: list[int]
    ) -> ClosureFate;

    def _binding_fate(
        binding: Symbol,
        origin: (Closure | None),
        home: (UniScopeNode | None),
        direct: bool,
        loop: (LoopStmt | None),
        seen: list[int]
    ) -> ClosureFate;

    def _use_fate(
        use: UniNode,
        home: (UniScopeNode | None),
        direct: bool,
        loop: (LoopStmt | None),
        seen: list[int]
    ) -> ClosureFate;

    def _value_fate(
        value: UniNode, direct: bool, loop: (LoopStmt | None), seen: list[int]
    ) -> ClosureFate;

    def _stored_fate(
        target: UniNode, loop: (LoopStmt | None), seen: list[int]
    ) -> ClosureFate;

    def _overwritten_each_iteration(
        store: Assignment, target: UniNode, loop: (LoopStmt | None)
    ) -> bool;

    def _carried_fate(
        sym: Symbol, site: UniNode, loop: (LoopStmt | None)
    ) -> ClosureFate;

    def _returned_fate(
        leave: (ReturnStmt | LambdaExpr), loop: (LoopStmt | None), seen: list[int]
    ) -> ClosureFate;

    def _calls_of(closure: Closure) -> list[FuncCall];
    def _is_frame(nd: UniNode) -> bool;
    def _frame_of(nd: UniNode) -> (UniScopeNode | None);
    def _outlives(nd: UniNode, loop: LoopStmt) -> bool;
    def _loops_outlived_by(nd: UniNode) -> list[LoopStmt];
    def _rebound_each_iteration(
        sym: Symbol, loop: LoopStmt, afresh: bool
    ) -> (NameAtom | None);

    def _read_when_created(name_nd: Name, closure: Closure) -> bool;
}
