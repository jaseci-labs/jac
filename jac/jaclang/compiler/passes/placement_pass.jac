import os;

class NativeRefused(Exception) {}

obj NativeRefusal {
    has kind: str,
        name: str,
        site: (UniNode | None) = None,
        help: (str | None) = None,
        code: str = "E5090",
        late: bool = False,
        noted: bool = False,
        text: str = "",
        brief: str = "",
        detail: str = "";

    def message -> str;
    def headline -> str;
    def located -> str;
    def full -> str;
}

obj NativeLegality {
    has units: dict[int, list[NativeRefusal]] = {},
        owners: dict[int, UniNode] = {},
        refs: dict[int, set[int]] = {},
        anchored_by: dict[int, set[int]] = {},
        tops: dict[int, UniNode] = {},
        elements: dict[int, NativeRefusal] = {},
        blockers: list[NativeRefusal] = [],
        module: list[NativeRefusal] = [],
        reach: list[NativeRefusal] = [],
        reached: dict[int, int] = {},
        late: dict[str, list[NativeRefusal]] = {},
        requires: dict[int, NativeRefusal] = {},
        module_requires: list[NativeRefusal] = [],
        preferences: dict[int, NativeRefusal] = {};

    def refuse_unit(owner: UniNode, refusal: NativeRefusal) -> None;
    def refuse_module(refusal: NativeRefusal) -> None;
    def refuse_site(mod: Module, refusal: NativeRefusal) -> None;
    def prefer_against(mod: Module, refusal: NativeRefusal) -> None;
    def refused_elements(mod: Module) -> set[int];
    def unit_refusals(owner: UniNode) -> list[NativeRefusal];
    def unit_refused(owner: UniNode) -> bool;
    def module_refused -> bool;
    def settle -> None;
    def static_units -> int;
    def late_units -> int;
    def unmet -> list[tuple[NativeRefusal, NativeRefusal]];
}

def native_unit_name(owner: UniNode) -> str;
def native_enclosing_unit(nd: UniNode) -> (UniNode | None);
def refusal_from_alert(alert: Alert) -> NativeRefusal;
def build_native_legality(
    mod: Module, prog: (JacProgram | None) = None
) -> NativeLegality;

def import_bindings(imp: Import) -> set[str];
def interop_refusal(mod: Module, nm: Name) -> (NativeRefusal | None);
def bridged_use_crosses(nm: Name) -> (str | None);
def binds_module_name(mod: Module, nm: Name) -> bool;
def element_requirements(mod: Module, prog: JacProgram) -> dict[int, tuple[str, str]];
def client_refused_elements(mod: Module) -> dict[int, list[tuple[UniNode, str]]];
def _runs_split(mod: Module) -> bool;
def _demote_unreached_imports(
    mod: Module, tentative: list[ContextAwareNode], prog: JacProgram
) -> None;

def stamp_native(mod: Module, held: set[int]) -> list[ContextAwareNode];
def uncrossable_native(mod: Module, prog: JacProgram, held: set[int]) -> set[int];
def settle_native_module(
    mod: Module, prog: JacProgram, pending: list[Alert], warnings: list[Alert]
) -> (NativeRefusal | None);

walker PlacementPass(CompilerPass) {
    static has contract: PassContract = PassContract(
        requires=(AnalysisFact.TYPE_OF, ),
        provides=(AnalysisFact.CAPABILITY, AnalysisFact.CLIENT_CAPABILITY, )
    );

    def _emit_refusal(refusal: NativeRefusal, required_by: str) -> None;
    def _report_unmet(legality: NativeLegality, why: str) -> None;
    def _check_conformance(ir_in: Module) -> None;
    def _run_decided(ir_in: Module) -> Module;
    def _run_undecided(ir_in: Module) -> Module;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
}

def _reference_targets(nm: Name) -> list[UniNode];

def unmet_label(need: NativeRefusal) -> tuple[str, str];
