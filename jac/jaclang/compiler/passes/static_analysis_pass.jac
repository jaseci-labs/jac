import from jaclang.compiler.frontend.roles { BodyRole }
import from jaclang.compiler.passes.context { CompileContext, CompilerPass }
import from jaclang.compiler.passes.scope_walk { ScopeWalker }
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    Assignment,
    AtomTrailer,
    AtomUnit,
    AwaitExpr,
    BinaryExpr,
    Bool,
    CompareExpr,
    ConnectOp,
    CtrlStmt,
    DisconnectOp,
    DisengageStmt,
    EdgeOpRef,
    ElseIf,
    ElseStmt,
    EventSignature,
    FString,
    FilterCompr,
    FinallyStmt,
    Float,
    ForeverStmt,
    FormattedValue,
    FuncCall,
    IfStmt,
    ImplDef,
    ImplImport,
    Import,
    InForStmt,
    Int,
    IterForStmt,
    KWPair,
    LambdaExpr,
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
    Symbol,
    Test,
    Token,
    UniNode,
    UniScopeNode,
    WhileStmt,
    in_type_position,
    is_identifier_slot,
    same_lexical_scope
}

import from jaclang.compiler.frontend.constant { ExprCtx, SymbolType }
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
     };

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
    def _consumed_by_its_call(closure: LambdaExpr) -> bool;
    def _only_called_where_bound(closure: Closure, binding: Symbol) -> bool;
    def _is_frame(nd: UniNode) -> bool;
    def _frame_of(nd: UniNode) -> (UniScopeNode | None);
    def _loops_outlived_by(closure: Closure) -> list[LoopStmt];
    def _rebound_each_iteration(sym: Symbol, loop: LoopStmt) -> (NameAtom | None);
    def _read_when_created(name_nd: Name, closure: Closure) -> bool;
}
