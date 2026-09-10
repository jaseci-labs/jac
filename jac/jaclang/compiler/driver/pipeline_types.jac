import from enum { StrEnum }

enum PassIdentity(StrEnum) {
    NativeDemotionPass = "NativeDemotionPass",
    PlacementReportPass = "PlacementReportPass",
    ASTValidationPass = "ASTValidationPass",
    AbsorbImportsPass = "AbsorbImportsPass",
    AccessCheckPass = "AccessCheckPass",
    AppContextPass = "AppContextPass",
    BaseAstGenPass = "BaseAstGenPass",
    BoundaryAnalysisPass = "BoundaryAnalysisPass",
    BoundaryFactsPass = "BoundaryFactsPass",
    CFGBuildPass = "CFGBuildPass",
    ClientCapabilityCheckPass = "ClientCapabilityCheckPass",
    ClientDependenciesPass = "ClientDependenciesPass",
    CoalesceBBPass = "CoalesceBBPass",
    CommentAttachPass = "CommentAttachPass",
    ComptimeImportsPass = "ComptimeImportsPass",
    ComptimeResolvePass = "ComptimeResolvePass",
    DeclImplMatchPass = "DeclImplMatchPass",
    DependencyFactsPass = "DependencyFactsPass",
    DocIRGenPass = "DocIRGenPass",
    EndpointEffectPass = "EndpointEffectPass",
    EsastGenPass = "EsastGenPass",
    FreezeStructurePass = "FreezeStructurePass",
    GrammarExtractPass = "GrammarExtractPass",
    GraphLoweringPass = "GraphLoweringPass",
    InterfaceFactsPass = "InterfaceFactsPass",
    JacAutoLintPass = "JacAutoLintPass",
    JacFormatPass = "JacFormatPass",
    JacLintCheckPass = "JacLintCheckPass",
    JcirBytecodeGenPass = "JcirBytecodeGenPass",
    JcirGenPass = "JcirGenPass",
    JsxIntrinsicGuardPass = "JsxIntrinsicGuardPass",
    LayoutPass = "LayoutPass",
    MTIRGenPass = "MTIRGenPass",
    ModuleContextPass = "ModuleContextPass",
    NaIRGenPass = "NaIRGenPass",
    NativeCapabilityCheckPass = "NativeCapabilityCheckPass",
    NativeClosurePass = "NativeClosurePass",
    NativeCompilePass = "NativeCompilePass",
    NativeEligibilityPass = "NativeEligibilityPass",
    NativeImportFactsPass = "NativeImportFactsPass",
    NormalizePass = "NormalizePass",
    OwnershipCheckPass = "OwnershipCheckPass",
    PlacementApplyPass = "PlacementApplyPass",
    PlacementSpacesPass = "PlacementSpacesPass",
    PlacementSummaryPass = "PlacementSummaryPass",
    PortabilityWarnPass = "PortabilityWarnPass",
    ProgramPlacementPass = "ProgramPlacementPass",
    PyastBuildPass = "PyastBuildPass",
    RcFactsPass = "RcFactsPass",
    RegionInferPass = "RegionInferPass",
    SemDefMatchPass = "SemDefMatchPass",
    SemanticAnalysisPass = "SemanticAnalysisPass",
    ServingFactsPass = "ServingFactsPass",
    StaticAnalysisPass = "StaticAnalysisPass",
    SymTabBuildPass = "SymTabBuildPass",
    TypeCheckPass = "TypeCheckPass",
    TypeQueryPass = "TypeQueryPass",
    UniPass = "UniPass",
    UnparsePass = "UnparsePass",
    VariantAgreementPass = "VariantAgreementPass"
}

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
    IMPORTS = "imports",
    SPACES = "spaces",
    PLACEMENT_SUMMARY = "placement-summary",
    PLACEMENT = "placement",
    CLIENT_DEPENDENCIES = "client-dependencies",
    SERVING = "serving",
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

class ProductUnavailable(RuntimeError) {}

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
