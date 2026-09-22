import hashlib;
import os;
import from collections.abc { Iterator }
import from contextlib { contextmanager }
import from contextvars { ContextVar }
import from jaclang.compiler.frontend.unitree {
    ImplImport,
    Import,
    ImportRule,
    ImportWire,
    Module,
    ModuleItem,
    ModulePath,
    ModulePattern,
    Token,
    UniNode
}
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.compiler.frontend.roles { Kid }
import from jaclang.project.modresolver { find_jac_project_root, resolve_local_module }
import from jaclang.project.source { read_file_with_encoding }

glob ARCH_FILE_NAME: str = "arch.jac";

obj WireBinding {
    has provider: str,
        form: str,
        name: str = "",
        alias: str = "";

    def key -> tuple[str, str, str, str] {
        return (self.provider, self.form, self.name, self.alias);
    }

    def wire_text(consumer: str) -> str;
}

obj WiringSpec {
    has root_dir: str,
        path: str,
        source: str,
        digest: str = "",
        parse_failed: bool = False,
        module: (Module | None) = None,
        blocks: list[ImplImport] = [],
        wires: list[ImportWire] = [],
        rules: list[ImportRule] = [],
        _lines: list[str] = [],
        _by_consumer: dict[str, list[ImportWire]] = {},
        _annex_cache: dict[str, str] = {},
        _rules_digest: str = "",
        _project_modules: (list[str] | None) = None;

    def postinit -> None;
    def module_name(path: str) -> (str | None);
    def module_file(name: str) -> (str | None);
    def is_package_dir(name: str) -> bool;
    def project_modules -> list[str];
    def consumer_wires(consumer: str) -> list[ImportWire];
    def is_covered(consumer: str) -> bool;
    def annex_source(consumer: str) -> (str | None);
    def digest_for(consumer: str) -> str;
    def wire_bindings(wire: ImportWire) -> list[WireBinding];
    def consumer_bindings(
        consumer: str
    ) -> dict[tuple[str, str, str, str], ImportWire];

    def import_provider(path_node: ModulePath) -> (str | None);
    def rules_for_provider(provider: str) -> list[ImportRule];
    def rules_admitting(provider: str, consumer: str) -> list[ImportRule];
    static def admitted_names(rules: list[ImportRule]) -> (set[str] | None);
    static def pattern_text(pattern: ModulePattern) -> str;
    static def import_form(
        is_absorb: bool, is_typed: bool, is_comptime: bool, from_form: bool
    ) -> str;

    def _wire_text(wire: ImportWire) -> list[tuple[int, int, str]];
    def _column_of(pos: int) -> int;
}

glob _spec_cache: dict[str, tuple[tuple[float, int], WiringSpec]] = {},
     _resolution: ContextVar[dict[str, WiringSpec | None] | None] = ContextVar(
         'jac_wiring_resolution', `default=None
     ),
     _building: set[str] = set();

@contextmanager
def wiring_scope -> Iterator[None] {
    if _resolution.get() is not None {
        yield ;
        return;
    }
    token = _resolution.set({});
    try {
        yield ;
    } finally {
        _resolution.reset(token);
    }
}

def is_arch_file(path: str) -> bool;
def arch_file_for(path: str) -> (str | None);
def wiring_for_path(path: str) -> (WiringSpec | None);
def wiring_annex_for(file_path: str) -> (tuple[str, str] | None);
def wiring_digest_for(file_path: str) -> str;
def _load_spec(root_dir: str, arch_path: str) -> WiringSpec;
