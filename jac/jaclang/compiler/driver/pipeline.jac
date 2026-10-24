import os;
import time;
import from contextvars { ContextVar }

class TypeshedUnavailableError(RuntimeError) {}

def no_passes(request: ProductRequest) -> PassSchedule;

def unavailable_schedule(request: ProductRequest) -> (PassSchedule | None);

def empty_schedule(request: ProductRequest) -> (PassSchedule | None);

def no_action(program: JacProgram, module: Module) -> bool;

def no_drop(program: JacProgram, module: Module);

def no_precheck;

obj ProductSpec {
    has needs: list[CompilationProduct] = [],
        passes: Callable[[ProductRequest], PassSchedule] = no_passes,
        bootstrap:
            Callable[[ProductRequest], (PassSchedule | None)] = unavailable_schedule,
        action: Callable[[JacProgram, Module], bool] = no_action,
        drop: Callable[[JacProgram, Module], None] = no_drop,
        precheck: Callable[[], None] = no_precheck,
        loads: list[str] = [],
        tier_with: list[CompilationProduct] = [],
        tiered: bool = False,
        acts: bool = False,
        cached: bool = False,
        tool: bool = False,
        on_import_error: ImportFallback = ImportFallback.RAISE;
}

def front_passes -> PassSchedule;

def symbols_passes(request: ProductRequest) -> PassSchedule;

def bootstrap_ir_passes(request: ProductRequest) -> (PassSchedule | None);

def ir_passes(request: ProductRequest) -> PassSchedule;

def flow_passes(request: ProductRequest) -> PassSchedule;

def analysis_passes(request: ProductRequest) -> PassSchedule;

def boundary_passes(request: ProductRequest) -> PassSchedule;

def client_passes(request: ProductRequest) -> PassSchedule;

def layout_passes(request: ProductRequest) -> PassSchedule;

def codegen_passes(request: ProductRequest) -> PassSchedule;

def py_ir_passes(request: ProductRequest) -> PassSchedule;

def frozen_passes(request: ProductRequest) -> PassSchedule;

def bytecode_passes(request: ProductRequest) -> PassSchedule;

def native_ir_passes(request: ProductRequest) -> PassSchedule;

def native_lower_passes(request: ProductRequest) -> PassSchedule;

def native_object_passes(request: ProductRequest) -> PassSchedule;

def format_passes(request: ProductRequest) -> PassSchedule;

def format_lintfix_passes(request: ProductRequest) -> PassSchedule;

def lint_passes(request: ProductRequest) -> PassSchedule;

def python_ast_passes(request: ProductRequest) -> PassSchedule;

def python_symbols_passes(request: ProductRequest) -> PassSchedule;

def grammar_passes(request: ProductRequest) -> PassSchedule;

def cfg_dot_passes(request: ProductRequest) -> PassSchedule;

def normalize_passes(request: ProductRequest) -> PassSchedule;

def unparse_passes(request: ProductRequest) -> PassSchedule;

def doc_passes(request: ProductRequest) -> PassSchedule;

def format_text_passes(request: ProductRequest) -> PassSchedule;

def place_module(program: JacProgram, module: Module) -> bool;

def prepare_interface(program: JacProgram, module: Module) -> bool;

def drop_client(program: JacProgram, module: Module);

def drop_native_ir(program: JacProgram, module: Module);

def drop_native_object(program: JacProgram, module: Module);

def require_typeshed_stubs -> None;

glob IR_LOADS: list[str] = [
         'jaclang.compiler.symbol_utils',
         'jaclang.compiler.expr_keys',
         'jaclang.compiler.type_registry',
         'jaclang.compiler.field_semantics',
         'jaclang.compiler.intrinsic_registry',
         'jaclang.compiler.types.type_evaluator',
         'jaclang.compiler.types.stubcat.modiface',
         'jaclang.compiler.types.stubcat.writer',
         'jaclang.compiler.passes.pyast_load_pass',
         'jaclang.compiler.passes.layout_pass',
         'jaclang.compiler.passes.cfg_build_pass',
         'jaclang.compiler.passes.sem_def_match_pass',
         'jaclang.compiler.passes.jsx_intrinsic_guard_pass',
         'jaclang.compiler.passes.mtir_gen_pass',
         'jaclang.compiler.passes.comptime_resolve_pass',
         'jaclang.project.mobui_scope'
     ],
     ANALYSIS_LOADS: list[str] = [
         'jaclang.compiler.field_semantics',
         'jaclang.compiler.passes.type_checker_pass',
         'jaclang.compiler.types.type_evaluator',
         'jaclang.compiler.passes.pyast_load_pass',
         'jaclang.compiler.passes.rc_facts_pass',
         'jaclang.compiler.types.type_utils',
         'jaclang.compiler.types.ts_decl_parser',
         'jaclang.compiler.symbol_utils',
         'jaclang.compiler.expr_keys',
         'jaclang.compiler.type_registry',
         'jaclang.compiler.driver.bccache',
         'jaclang.compiler.frontend.codeinfo',
         'jaclang.compiler.frontend.diagnostic_utils',
         'jaclang.project.modresolver',
         'jaclang.project.tomlio',
         'jaclang.project.mobui_scope',
         'jaclang.project.config',
         'jaclang.compiler.passes.static_analysis_pass',
         'jaclang.compiler.passes.access_check_pass',
         'jaclang.compiler.passes.variant_agreement_pass',
         'jaclang.compiler.passes.capability_check_pass',
         'jaclang.compiler.capability_notes',
         'jaclang.compiler.boundary_rules',
         'jaclang.compiler.native_bindings',
         'jaclang.compiler.passes.placement_pass',
         'jaclang.compiler.passes.ownership_check_pass',
         'jaclang.compiler.passes.region_infer_pass',
         'jaclang.compiler.tools.jac_auto_lint_pass'
     ],
     CODEGEN_LOADS: list[str] = [
         'jaclang.compiler.passes.rc_facts_pass',
         'jaclang.compiler.backends.es',
         'jaclang.compiler.passes.freeze_structure_pass'
     ],
     NATIVE_LOADS: list[str] = ['jaclang.compiler.backends.native.na_ir_gen_pass', ];

glob PRODUCTS: dict[CompilationProduct, ProductSpec] = {
         CompilationProduct.SYMBOLS: ProductSpec(
             passes=symbols_passes,
             bootstrap=symbols_passes,
             loads=['jaclang.compiler.symbol_utils'],
             tier_with=[CompilationProduct.IR],
             tiered=True,
             on_import_error=ImportFallback.BOOTSTRAP
         ),
         CompilationProduct.IR: ProductSpec(
             passes=ir_passes,
             bootstrap=bootstrap_ir_passes,
             loads=IR_LOADS,
             tiered=True,
             on_import_error=ImportFallback.BOOTSTRAP_INTERNAL
         ),
         CompilationProduct.FLOW: ProductSpec(passes=flow_passes, cached=True),
         CompilationProduct.PLACEMENT: ProductSpec(action=place_module, acts=True),
         CompilationProduct.ANALYSIS: ProductSpec(
             needs=[CompilationProduct.FLOW],
             passes=analysis_passes,
             precheck=require_typeshed_stubs,
             loads=ANALYSIS_LOADS,
             tiered=True,
             cached=True
         ),
         CompilationProduct.BOUNDARIES: ProductSpec(passes=boundary_passes),
         CompilationProduct.INTERFACE: ProductSpec(
             action=prepare_interface, acts=True, cached=True
         ),
         CompilationProduct.CLIENT: ProductSpec(
             needs=[CompilationProduct.ANALYSIS],
             passes=client_passes,
             drop=drop_client,
             cached=True
         ),
         CompilationProduct.LAYOUT: ProductSpec(passes=layout_passes, cached=True),
         CompilationProduct.CODEGEN: ProductSpec(
             passes=codegen_passes,
             bootstrap=empty_schedule,
             loads=CODEGEN_LOADS,
             tier_with=[CompilationProduct.IR, CompilationProduct.NATIVE_LOWER],
             tiered=True,
             on_import_error=ImportFallback.REPORT
         ),
         CompilationProduct.PY_IR: ProductSpec(passes=py_ir_passes),
         CompilationProduct.FROZEN: ProductSpec(
             passes=frozen_passes,
             bootstrap=empty_schedule,
             tier_with=[CompilationProduct.CODEGEN],
             tiered=True,
             on_import_error=ImportFallback.REPORT
         ),
         CompilationProduct.BYTECODE: ProductSpec(
             needs=[CompilationProduct.PY_IR], passes=bytecode_passes
         ),
         CompilationProduct.NATIVE_IR: ProductSpec(
             needs=[CompilationProduct.FLOW, CompilationProduct.ANALYSIS],
             passes=native_ir_passes,
             loads=NATIVE_LOADS,
             cached=True
         ),
         CompilationProduct.NATIVE_LOWER: ProductSpec(
             needs=[CompilationProduct.ANALYSIS],
             passes=native_lower_passes,
             drop=drop_native_ir,
             loads=NATIVE_LOADS
         ),
         CompilationProduct.NATIVE_OBJECT: ProductSpec(
             needs=[CompilationProduct.NATIVE_LOWER],
             passes=native_object_passes,
             drop=drop_native_object
         ),
         CompilationProduct.FORMAT: ProductSpec(passes=format_passes),
         CompilationProduct.FORMAT_LINTFIX: ProductSpec(passes=format_lintfix_passes),
         CompilationProduct.LINT: ProductSpec(passes=lint_passes),
         CompilationProduct.PYTHON_AST: ProductSpec(
             passes=python_ast_passes, tool=True
         ),
         CompilationProduct.PYTHON_SYMBOLS: ProductSpec(
             passes=python_symbols_passes, tool=True
         ),
         CompilationProduct.GRAMMAR: ProductSpec(passes=grammar_passes, tool=True),
         CompilationProduct.CFG_DOT: ProductSpec(passes=cfg_dot_passes, tool=True),
         CompilationProduct.NORMALIZE: ProductSpec(passes=normalize_passes, tool=True),
         CompilationProduct.UNPARSE: ProductSpec(passes=unparse_passes, tool=True),
         CompilationProduct.DOC: ProductSpec(passes=doc_passes, tool=True),
         CompilationProduct.FORMAT_TEXT: ProductSpec(
             passes=format_text_passes, tool=True
         )
     },
     _LOADING: ContextVar[list[CompilationProduct]] = ContextVar(
         'jac_schedule_loading', `default=[]
     );

def contract_of(p: type[CompilerPass]) -> PassContract;

def validate_schedule(
    passes: PassSchedule,
    preprovided: (set[AnalysisFact] | None) = None,
    origin: str = 'schedule'
) -> PassSchedule;

def providers_of(passes: PassSchedule) -> set[AnalysisFact];

def schedule_loading -> bool;

def tier_reason(product: CompilationProduct) -> str;

def resolve(
    product: CompilationProduct,
    request: (ProductRequest | None) = None,
    internal: bool = False,
    peer_fell_back: bool = False
) -> tuple[(PassSchedule | None), bool, bool];

def schedule_for(
    product: CompilationProduct,
    request: (ProductRequest | None) = None,
    internal: bool = False
) -> (PassSchedule | None);

def unavailable(product: CompilationProduct) -> str;

def product_passes(
    product: CompilationProduct, request: (ProductRequest | None) = None
) -> PassSchedule;

def product_facts(product: CompilationProduct) -> set[AnalysisFact];

def early_passes -> PassSchedule;

def dependents(product: CompilationProduct) -> list[CompilationProduct];

def product_ready(
    program: JacProgram, module: Module, product: CompilationProduct
) -> bool;

def cancelled(cancel_token: (CancelToken | None)) -> bool;

def produce(
    program: JacProgram,
    module: Module,
    product: CompilationProduct,
    cancel_token: (CancelToken | None),
    request: (ProductRequest | None),
    task: (ProductTask | None) = None
) -> (bool | None);

def require(
    program: JacProgram,
    module: Module,
    product: CompilationProduct,
    cancel_token: (CancelToken | None) = None,
    request: (ProductRequest | None) = None
) -> bool;

def invalidate(program: JacProgram, module: Module, product: CompilationProduct);

def execute_passes(
    program: JacProgram,
    module: Module,
    passes: PassSchedule,
    cancel_token: (CancelToken | None) = None
) -> Module;

def run_utility(
    product: CompilationProduct,
    ir: any,
    program: JacProgram,
    cancel_token: (CancelToken | None) = None
) -> any;
