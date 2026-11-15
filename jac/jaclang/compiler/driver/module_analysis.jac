import os;
import time;

obj ModuleAnalysis {
    has program: JacProgram,
        path: str,
        options: CompileOptions,
        source: str | None = None,
        module: uni.Module postinit,
        module_path: str = "",
        parse_failed: bool = False,
        blocked: bool = False,
        native: bool = False,
        placement_only: bool = False,
        session: (SessionHooks | None) = None;

    def postinit;
    def parse;
    def require(
        product: CompilationProduct, request: (ProductRequest | None) = None
    ) -> bool;

    def ready(product: CompilationProduct) -> bool;
    def has_full_ir -> bool;
}

obj PlanStep {
    has name: str,
        admit: Callable[[ModuleAnalysis], bool],
        run: Callable[[ModuleAnalysis], None];
}

def cancelled(options: CompileOptions) -> bool;

def always(task: ModuleAnalysis) -> bool;

def run_parse(task: ModuleAnalysis);

def run_head(task: ModuleAnalysis);

def admits_placement(task: ModuleAnalysis) -> bool;

def run_placement(task: ModuleAnalysis);

def run_analysis(task: ModuleAnalysis);

def admits_boundaries(task: ModuleAnalysis) -> bool;

def run_boundaries(task: ModuleAnalysis);

glob ANALYSIS_PLAN: tuple[PlanStep, ...] = (
         PlanStep(name="PARSE", admit=always, run=run_parse),
         PlanStep(name="IR", admit=always, run=run_head),
         PlanStep(name="PLACEMENT", admit=admits_placement, run=run_placement),
         PlanStep(name="ANALYSIS", admit=always, run=run_analysis),
         PlanStep(name="BOUNDARIES", admit=admits_boundaries, run=run_boundaries)
     );

def run_plan(task: ModuleAnalysis, steps: tuple[PlanStep, ...]);

def analyze_module(
    program: JacProgram, path: str, options: CompileOptions, source: str | None = None
) -> ModuleAnalysis;
