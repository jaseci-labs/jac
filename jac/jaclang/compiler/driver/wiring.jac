import hashlib;
import os;
import sys;
import from collections.abc { Iterator }
import from contextlib { contextmanager }
import from contextvars { ContextVar }
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    EmptyToken,
    Enum,
    ImplDef,
    GraphImport,
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
import from jaclang.compiler.frontend.roles { BodyRole, Kid }
import from jaclang.project.modresolver { find_jac_project_root, resolve_local_module }
import from jaclang.project.source { drop_git_ignored, read_file_with_encoding }

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
        blocks: list[GraphImport] = [],
        wires: list[ImportWire] = [],
        rules: list[ImportRule] = [],
        _lines: list[str] = [],
        _by_consumer: dict[str, list[ImportWire]] = {},
        _annex_cache: dict[str, str] = {},
        _policy_digest: str = "",
        _project_modules: (list[str] | None) = None,
        _prefix: (str | None) = None,
        _owned_dirs: dict[str, bool] = {},
        _indexed: bool = False,
        _scopes: dict[tuple[str, int], list[str]] = {},
        _wire_lines: dict[int, ImportWire] = {};

    def postinit -> None;
    def module_name(path: str) -> (str | None);
    def import_prefix -> str;
    def import_name(name: str) -> str;
    def module_file(name: str) -> (str | None);
    def owns(path: str) -> bool;
    def split_consumer(path: str) -> (tuple[str, list[str]] | None);
    def _index_consumers -> None;
    def consumer_scope(consumer: str, wire: ImportWire) -> list[str];
    def wire_at_line(line: int) -> (ImportWire | None);
    def is_package_dir(name: str) -> bool;
    def project_modules -> list[str];
    def consumer_wires(consumer: str) -> list[ImportWire];
    def is_covered(consumer: str) -> bool;
    def is_project_module(module: str) -> bool;
    def annex_source(consumer: str) -> (str | None);
    def digest_for(consumer: str) -> str;
    def wire_bindings(wire: ImportWire) -> list[WireBinding];
    def consumer_bindings(
        consumer: str, scope: (list[str] | None) = None
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
def dedupe_generated_imports(mod: Module) -> None;
def compiled_by_seed(path: str) -> bool;
def _load_spec(root_dir: str, arch_path: str) -> WiringSpec;
def scope_path_of(nd: UniNode) -> (list[str] | None);
def scope_owners(mod: Module) -> dict[str, (Ability | ImplDef)];
def inject_into_scope(owner: (Ability | ImplDef), stmt: UniNode) -> None;
def _import_items(stmt: Import) -> list[tuple[tuple[str, str, str, str], UniNode]];
def _import_keys(stmt: Import) -> set[tuple[str, str, str, str]];
def _relative_twin(
    key: tuple[str, str, str, str], consumer: str
) -> tuple[str, str, str, str];
