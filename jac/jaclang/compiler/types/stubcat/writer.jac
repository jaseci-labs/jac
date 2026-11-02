import os;
import hashlib;
import json;

obj ScopeMembers {
    has names: dict[str, Symbol] = {},
        overloads: dict[str, list[Symbol]] = {};
}

def live_branches(guard: IfStmt) -> list[UniScopeNode];

def live_kid_scopes(scope: UniScopeNode) -> list[UniScopeNode];

def collect_scope_members(scope: UniScopeNode) -> ScopeMembers;

def live_scopes(scope: UniScopeNode) -> set[int];

def enclosing_scope(nd: UniNode) -> (UniScopeNode | None);

def star_import_members(
    mod: Module, evaluator: TypeEvaluator, visited: (set[int] | None) = None
) -> dict[str, Symbol];

def metaclass_of_scope(
    scope: UniScopeNode, evaluator: TypeEvaluator
) -> (TypeBase | None);

def home_scope(sym: Symbol) -> (UniScopeNode | None);

def module_of(scope: (UniScopeNode | None)) -> (Module | None);

def ident_key(parts: list[str]) -> str;

obj PathMapper {
    def map(path: str) -> str;
}

def encode_package_path(
    path: str, base_dir: str, package_dir: str, sentinel: str
) -> str;

obj PackagePathMapper(PathMapper) {
    has base_dir: str,
        package_dir: str,
        sentinel: str;

    def map(path: str) -> str;
}

obj CatalogWriter {
    has evaluator: TypeEvaluator,
        pkg_dir: str,
        strings: dict[str, int] postinit,
        str_list: list[str] postinit,
        module_names: dict[str, str] postinit,
        module_ids: dict[str, int] postinit,
        modules: list[Module] postinit,
        scope_ids: dict[str, int] postinit,
        scopes: list[UniScopeNode] postinit,
        pending_scopes: list[int] postinit,
        sym_ids: dict[str, int] postinit,
        syms: list[Symbol] postinit,
        pending_syms: list[int] postinit,
        type_ids: dict[str, int] postinit,
        _ident_visiting: set[int] postinit,
        _type_ident_memo: dict[int, tuple[TypeBase, str]] postinit,
        _type_tokens: dict[str, str] postinit,
        _canonical_paths: dict[str, str] postinit,
        types: list[TypeBase] postinit,
        pending_types: list[int] postinit,
        shared_ids: dict[str, int] postinit,
        shareds: list[ClassDetailsShared] postinit,
        pending_shared: list[int] postinit,
        module_recs: list[bytes] postinit,
        scope_recs: list[(bytes | None)] postinit,
        sym_recs: list[(bytes | None)] postinit,
        type_recs: list[(bytes | None)] postinit,
        shared_recs: list[(bytes | None)] postinit,
        sym_types: dict[str, (TypeBase | None)] postinit,
        sym_props: dict[str, tuple[int, int, (TypeBase | None)]] postinit,
        forced_scopes: set[str] postinit,
        base_dir: str postinit,
        external_modules: set[str] postinit,
        boundary: (Module | None) = None,
        path_mapper: (PathMapper | None) = None,
        spans: bool = True,
        failures: int = 0,
        evaluated: int = 0,
        failure_log: list[str] = [],
        orphans: list[str] = [];

    def postinit;
    def _real_path(path: str) -> str;
    def in_boundary(mod: (Module | None)) -> bool;
    def _mod_ident(mod: (Module | None)) -> str;
    def _scope_ident(scope: (UniScopeNode | None)) -> str;
    def _sym_ident(sym: Symbol) -> str;
    def _shared_ident(shared: ClassDetailsShared) -> str;
    def scope_dotted_path(scope: (UniScopeNode | None)) -> str;
    def sid(text: str) -> int;
    def rel_of(path: str) -> str;
    def add_module(mod: Module, dotted: str) -> None;
    def ref_module(mod: (Module | None)) -> int;
    def dotted_name_of(mod: Module) -> str;
    def force_all;
    def _materialize_lazy_members(scope: UniScopeNode) -> None;
    def force_scope(scope: UniScopeNode) -> None;
    def force_symbol(sym: Symbol) -> None;
    def _jac_method_of(sym: Symbol) -> (Ability | None);
    def property_facts(sym: Symbol) -> tuple[int, int, (TypeBase | None)];
    def ref_scope(scope: (UniScopeNode | None)) -> int;
    def ref_symbol(sym: (Symbol | None)) -> int;
    def _type_ident(t: TypeBase) -> str;
    def _type_ident_uncached(t: TypeBase) -> str;
    def _types_ident(ts: (list[TypeBase] | None)) -> str;
    def _literal_ident(value: any) -> str;
    def ref_type(t: (TypeBase | None)) -> int;
    def ref_types(ts: (list[TypeBase] | None)) -> list[int];
    def ref_shared(shared: (ClassDetailsShared | None)) -> int;
    def put_literal(out: bytearray, value: any);
    def encode_module(idx: int) -> bytes;
    def encode_scope(idx: int) -> bytes;
    def encode_symbol(idx: int) -> bytes;
    def encode_type(idx: int) -> bytes;
    def note_orphan(sh: ClassDetailsShared);
    def encode_shared(idx: int) -> bytes;
    def drain;
    def emit(key: str, ambient: dict[str, set[str]]) -> bytes;
    def manifest -> dict[str, any];
}

class IncoherentInterface(RuntimeError) {}

def incoherent_message(mod_path: str, orphans: list[str], failures: list[str]) -> str;

def build_module_iface(
    mod: Module,
    evaluator: TypeEvaluator,
    pkg_dir: str,
    path_mapper: (PathMapper | None) = None,
    spans: bool = True
) -> bytes;

def module_iface_shape(mod: Module, evaluator: TypeEvaluator, pkg_dir: str) -> str;

def module_iface_body(
    mod: Module,
    evaluator: TypeEvaluator,
    pkg_dir: str,
    path_mapper: (PathMapper | None),
    spans: bool
) -> bytes;
