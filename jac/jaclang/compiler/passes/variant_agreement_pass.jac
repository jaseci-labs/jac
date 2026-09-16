import from jaclang.compiler.passes.context { CompileContext }
import os;
import from jaclang.compiler.frontend.unitree {
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

import from jaclang.compiler.frontend.constant { SymbolAccess }
import from jaclang.compiler.frontend.diagnostics { E5105 }
import type from jaclang.compiler.driver.program { JacProgram }

glob VARIANT_SUFFIX: str = ".native.jac",
     ANNEX_MARKERS: tuple[str, ...] = (".impl.jac", ".test.jac");

def variant_sibling(mod_path: str) -> (str | None);
def annotation_text(nd: (UniNode | None)) -> str;
def public_surface(mod: Module) -> dict[str, tuple[str, str, UniNode]];

walker VariantAgreementPass {
    has ctx: CompileContext,
        prog: JacProgram,
        module: Module;

    static has HOST_PASS: bool = True;

    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def _parse_sibling(path: str) -> (Module | None);
    def _emit_once(nd: UniNode, **kwargs: any) -> None;
    def _compare(base: Module, variant: Module) -> None;
}
