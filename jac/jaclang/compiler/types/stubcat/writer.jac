import os;
import hashlib;
import json;
import struct;

obj ScopeMembers {
    has names: dict[str, Symbol] = {},
        overloads: dict[str, list[Symbol]] = {};
}

def live_branches(guard: IfStmt) -> list[UniScopeNode];

def live_kid_scopes(scope: UniScopeNode) -> list[UniScopeNode];

def collect_scope_members(scope: UniScopeNode) -> ScopeMembers;

def live_scopes(scope: UniScopeNode) -> set[int];

def enclosing_scope(nd: any) -> (UniScopeNode | None);

def star_import_members(
    mod: Module, evaluator: any, visited: (set[int] | None) = None
) -> dict[str, Symbol];

def metaclass_of_scope(scope: UniScopeNode, evaluator: any) -> (TypeBase | None);

def home_scope(sym: Symbol) -> (UniScopeNode | None);

def module_of(scope: (UniScopeNode | None)) -> (Module | None);

obj CatalogWriter {
    has evaluator: any,
        pkg_dir: str,
        strings: dict[str, int] postinit,
        str_list: list[str] postinit,
        module_names: dict[any, str] postinit,
        module_ids: dict[any, int] postinit,
        modules: list[Module] postinit,
        scope_ids: dict[any, int] postinit,
        scopes: list[UniScopeNode] postinit,
        pending_scopes: list[int] postinit,
        sym_ids: dict[any, int] postinit,
        syms: list[Symbol] postinit,
        pending_syms: list[int] postinit,
        type_ids: dict[any, int] postinit,
        _ident_visiting: set[int] postinit,
        _type_ident_memo: dict[int, tuple[TypeBase, any]] postinit,
        _canonical_paths: dict[str, str] postinit,
        types: list[TypeBase] postinit,
        pending_types: list[int] postinit,
        shared_ids: dict[any, int] postinit,
        shareds: list[ClassDetailsShared] postinit,
        pending_shared: list[int] postinit,
        module_recs: list[bytes] postinit,
        scope_recs: list[(bytes | None)] postinit,
        sym_recs: list[(bytes | None)] postinit,
        type_recs: list[(bytes | None)] postinit,
        shared_recs: list[(bytes | None)] postinit,
        sym_types: dict[any, (TypeBase | None)] postinit,
        sym_props: dict[any, tuple[int, int, (TypeBase | None)]] postinit,
        forced_scopes: set[any] postinit,
        base_dir: str postinit,
        external_modules: set[any] postinit,
        boundary: (Module | None) = None,
        path_mapper: Callable[[str], str] | None = None,
        spans: bool = True,
        failures: int = 0,
        evaluated: int = 0,
        failure_log: list[str] = [],
        orphans: list[str] = [];

    def postinit;
    def _real_path(path: str) -> str;
    def in_boundary(mod: (Module | None)) -> bool;
    def _mod_ident(mod: (Module | None)) -> any;
    def _scope_ident(scope: (UniScopeNode | None)) -> any;
    def _sym_ident(sym: Symbol) -> any;
    def _shared_ident(shared: ClassDetailsShared) -> any;
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
    def _type_ident(t: TypeBase) -> any;
    def _type_ident_uncached(t: TypeBase) -> any;
    def _types_ident(ts: (list[TypeBase] | None)) -> tuple[any, ...];
    def _literal_ident(value: any) -> any;
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

class IncoherentInterface(RuntimeError) {
    has mod_path: str,
        orphans: list[str],
        failures: list[str];

    def init(
        self: IncoherentInterface,
        mod_path: str,
        orphans: list[str],
        failures: list[str] | None = None
    );
}

def build_module_iface(
    mod: Module,
    evaluator: any,
    pkg_dir: str,
    path_mapper: Callable[[str], str] | None = None,
    spans: bool = True
) -> bytes;

def module_iface_shape(mod: Module, evaluator: any, pkg_dir: str) -> str;

def module_iface_body(
    mod: Module,
    evaluator: any,
    pkg_dir: str,
    path_mapper: Callable[[str], str] | None,
    spans: bool
) -> bytes;
