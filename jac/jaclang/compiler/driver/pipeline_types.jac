import from enum { StrEnum }

enum AnalysisFact(StrEnum) {
    CFG_SUCC = 'CfgSucc',
    IMPL_OF = 'ImplOf',
    PLACED_IN = 'PlacedIn',
    SYM_OF = 'SymOf',
    TYPE_OF = 'TypeOf',
    ACCESS_CHECKS = 'access-checks',
    CAPABILITY = 'capability',
    COMPTIME = 'comptime',
    DECL_TYPES = 'decl-types',
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
    IR = "ir",
    FLOW = "flow",
    PLACEMENT = "placement",
    ANALYSIS = "analysis",
    DECLARATIONS = "declarations",
    BOUNDARIES = "boundaries",
    INTERFACE = "interface",
    CLIENT = "client",
    LAYOUT = "layout",
    CODEGEN = "codegen",
    PY_IR = "py-ir",
    FROZEN = "frozen",
    BYTECODE = "bytecode",
    NATIVE_IR = "native-ir",
    NATIVE_LOWER = "native-lower",
    NATIVE_OBJECT = "native-object"
}

enum ImportFallback {
    RAISE = "raise",
    BOOTSTRAP = "bootstrap",
    BOOTSTRAP_INTERNAL = "bootstrap-internal",
    REPORT = "report"
}

obj ProductRequest {
    has gen_mtir: bool = True,
        native: bool = False,
        endpoint_effects: bool = True;
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
        import_fallback: bool = False;
}
