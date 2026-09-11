import from enum { StrEnum }

enum AnalysisFact(StrEnum) {
    CFG_FALSE = 'CfgFalse',
    CFG_SUCC = 'CfgSucc',
    CFG_TRUE = 'CfgTrue',
    DECIDED_CODESPACE = 'DecidedCodespace',
    DEFINES = 'Defines',
    IMPL_OF = 'ImplOf',
    IN_SCOPE = 'InScope',
    PLACED_IN = 'PlacedIn',
    SCOPE_CHILD = 'ScopeChild',
    SYM_OF = 'SymOf',
    TYPE_OF = 'TypeOf',
    ACCESS_CHECKS = 'access-checks',
    CAPABILITY = 'capability',
    CLIENT_CAPABILITY = 'client_capability',
    CODESPACE_PULL = 'codespace-pull',
    COMPTIME = 'comptime',
    FROZEN = 'frozen',
    OWNERSHIP = 'ownership',
    PORTABILITY = 'portability',
    RC_FACTS = 'rc-facts',
    REGION_INFER = 'region-infer',
    STATIC_CHECKS = 'static-checks',
    VARIANT_AGREEMENT = 'variant-agreement'
}

obj PassContract {
    has requires: tuple[AnalysisFact, ...] = (),
        provides: tuple[AnalysisFact, ...] = ();
}

enum CompilationProduct {
    SYMBOLS = "symbols",
    INTERFACE = "interface",
    FLOW = "flow",
    ANALYSIS = "analysis",
    BOUNDARIES = "boundaries",
    CLIENT = "client",
    LAYOUT = "layout",
    NATIVE_IR = "native-ir",
    EXECUTABLE = "executable"
}

enum TaskState {
    PENDING = "pending",
    RUNNING = "running",
    SUCCEEDED = "succeeded",
    FAILED = "failed",
    CANCELLED = "cancelled"
}

obj ProductTask {
    has product: CompilationProduct,
        state: TaskState = TaskState.PENDING,
        elapsed: float = 0.0;
}

enum UtilityProduct {
    PYTHON_AST = "python-ast",
    PYTHON_SYMBOLS = "python-symbols",
    GRAMMAR = "grammar",
    CFG_DOT = "cfg-dot",
    NORMALIZE = "normalize",
    UNPARSE = "unparse",
    DOC = "doc",
    FORMAT = "format"
}
