import type from jaclang.compiler.session.services { AnalysisServices }
import from jaclang.compiler.ir.identity { GraphId }
import from enum { StrEnum }

enum PassIdentity(StrEnum) {
    ClientLinkPass = "ClientLinkPass",
    CatalogPreparePass = "CatalogPreparePass",
    BindingFactsPass = "BindingFactsPass",
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
    BINDING_FACTS = "binding-facts",
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

obj AnalysisContract {
    has requires: tuple[AnalysisFact, ...] = (),
        provides: tuple[AnalysisFact, ...] = ();
}

enum CompilationProduct {
    CLIENT_LINK = "client-link",
    CATALOG = "catalog",
    NATIVE_ELIGIBILITY = "native-eligibility",
    NATIVE_CLOSURE = "native-closure",
    TYPE_QUERY = "type-query",
    PLACEMENT_REPORT = "placement-report",
    NATIVE_DEMOTION = "native-demotion",
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
    UNAVAILABLE = "unavailable",
    CANCELLED = "cancelled"
}

obj ProductTask {
    has product: CompilationProduct,
        state: TaskState = TaskState.PENDING,
        elapsed: float = 0.0,
        version: int = 0,
        dependencies: dict[tuple[str, CompilationProduct, str], int] = {},
        initial_version: int = 0;
}

class ProductUnavailable(RuntimeError) {}

enum UtilityProduct {
    INTERFACE_CONTEXT = "interface-context",
    PYTHON_AST = "python-ast",
    PYTHON_SYMBOLS = "python-symbols",
    GRAMMAR = "grammar",
    CFG_DOT = "cfg-dot",
    NORMALIZE = "normalize",
    UNPARSE = "unparse",
    DOC = "doc",
    FORMAT = "format"
}

obj ProductKey[T] {
    has product: CompilationProduct,
        result_type: type[T];
}

obj ProductRecord[T] {
    has value: T,
        version: int,
        state: TaskState = TaskState.SUCCEEDED;
}

import type from collections.abc { Callable }
import type from jaclang.compiler.pipeline.program_pass { QueryTransform }
import type from jaclang.compiler.session.session { JacProgram }
import type from jaclang.compiler.ir.schema { Module }
import type from jaclang.compiler.pipeline.pass_base { DiagnosticPolicy }

obj QueryContext {
    has program: AnalysisServices,
        module: Module,
        policy: DiagnosticPolicy;
}

obj QuerySpec[A, R] {
    has identity: PassIdentity,
        product: CompilationProduct,
        create: Callable[[QueryContext, A], QueryTransform[R]],
        writes: frozenset[RelationFamily],
        clone_syntax: bool = False,
        recipe: Callable[[A], str] = repr;
}

obj NativeClosureRequest {
    has dependencies: list[str],
        hold_exempt: bool = False;
}

import type from threading { Event }
import type from jaclang.compiler.ir.base { UniNode }
import type from jaclang.compiler.ir.schema { Module, PythonModuleAst }
import type from jaclang.compiler.pipeline.pass_base { Transform, Alert, PassResult }
import type from jaclang.compiler.backends.es.framework_backend { FrameworkBackend }
import from jaclang.compiler.ir.identity { RelationFamily }

enum PassScope { MODULE = "module", CLOSURE = "closure", SYNTAX = "syntax" }

obj PassContext {
    has program: AnalysisServices,
        ir: UniNode,
        policy: DiagnosticPolicy,
        cancel_token: Event | None = None,
        completed: PassResult | None = None,
        errors: list[Alert] = [],
        warnings: list[Alert] = [],
        client_backend: FrameworkBackend | None = None;

    def module_ir -> Module {
        import from jaclang.compiler.ir.schema { Module }
        ir = self.ir;
        if not isinstance(ir, Module) {
            raise TypeError("This pass requires a module IR");
        }
        return ir;
    }

    def python_ir -> PythonModuleAst {
        import from jaclang.compiler.ir.schema { PythonModuleAst }
        ir = self.ir;
        if not isinstance(ir, PythonModuleAst) {
            raise TypeError("This pass requires a Python module AST");
        }
        return ir;
    }
}

obj PassSpec {
    has identity: PassIdentity,
        create: Callable[[PassContext], Transform],
        scope: PassScope,
        writes: frozenset[RelationFamily],
        analysis: AnalysisContract,
        native_early_bit: int = 0,
        preserves_facts_on_error: bool = False;
}

type TaskAddress = tuple[GraphId, CompilationProduct, str];
type ResultAddress = tuple[str, CompilationProduct, str];
