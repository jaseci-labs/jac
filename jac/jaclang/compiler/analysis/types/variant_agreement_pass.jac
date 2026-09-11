import type from jaclang.compiler.session.services { AnalysisServices }
import os;
import from jaclang.compiler.ir.schema {
    Ability,
    Archetype,
    Enum,
    FuncSignature,
    GlobalVars,
    HasVar,
    Module,
    Name,
    UniNode
}
import from jaclang.compiler.pipeline.pass_base { Transform }
import from jaclang.compiler.ir.enums { SymbolAccess }
import from jaclang.compiler.frontend.diagnostics { E5105 }
import type from jaclang.compiler.session.session { JacProgram }

glob VARIANT_SUFFIX: str = ".native.jac",
     ANNEX_MARKERS: tuple = (".impl.jac", ".test.jac");

def variant_sibling(mod_path: str) -> (str | None);
def annotation_text(nd: (UniNode | None)) -> str;
def public_surface(mod: Module) -> dict[str, tuple[str, str, UniNode]];

walker VariantAgreementPass(Transform) {
    has prog: AnalysisServices,
        ir_in: Module,
        cancel_token: any = None;

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def _parse_sibling(path: str) -> (Module | None);
    def _emit_once(nd: UniNode, **kwargs: any) -> None;
    def _compare(base: Module, variant: Module) -> None;
}
