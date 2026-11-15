import io;
import os;
import json;
import from pathlib { Path }

def keep_path(rel: str) -> str;

obj CatProvider(SymbolProvider) {
    has cat: StubCatalog,
        type_id: int,
        alias_mod: int,
        alias_name: str,
        prop_kind: int,
        write_kind: int,
        write_type_id: int,
        symbits: int = 0,
        memo: (TypeBase | None) = None,
        memo_set: bool = False;

    override def resolve_type(symbol: Symbol) -> TypeBase;
    override def definition -> (Symbol | None);
    override def property_kind -> int;
    override def property_write_kind -> int;
    override def property_write_type -> (TypeBase | None);
}

node CatScope(UniScopeNode) {
    has cat: StubCatalog,
        cat_id: int,
        cat_kind: int,
        cat_name: str,
        cat_arch_kind: int,
        cat_kids: dict[str, int],
        cat_metaclass: int = -1,
        cat_owner_sym: (Symbol | None) = None;

    def init(
        *,
        cat: StubCatalog,
        cat_id: int,
        kind: int,
        name: str,
        arch_kind: int,
        kids: dict[str, int],
        tok: Token
    );

    def postinit;
    def find_scope(name: str) -> (UniScopeNode | None);
    def metaclass_type -> (TypeBase | None);
    def get_has_vars -> list[HasVar];
    def get_methods -> list[Ability];
    def __repr__ -> str;
}

node CatModule(Module) {
    has cat: StubCatalog,
        cat_id: int,
        cat_kids: dict[str, int];

    def init(
        *, cat: StubCatalog, cat_id: int, name: str, kids: dict[str, int], tok: Token
    );

    def find_scope(name: str) -> (UniScopeNode | None);
    def __repr__ -> str;
}

obj ScopeRec {
    has kind: int = 0,
        name: str = "",
        parent: int = -1,
        module: int = -1,
        owner: int = -1,
        line: int = 0,
        col: int = 0,
        end_line: int = 0,
        end_col: int = 0,
        arch_kind: int = 0,
        metaclass: int = -1,
        members: list[tuple[str, int]] = [],
        overloads: list[tuple[str, list[int]]] = [],
        kids: dict[str, int] = {};
}

obj SymbolRec {
    has name: str = "",
        symtype: str = "",
        access: int = 0,
        imported: bool = False,
        line: int = 0,
        col: int = 0,
        end_line: int = 0,
        end_col: int = 0,
        module: int = -1,
        scope: int = -1,
        type_id: int = -1,
        alias_mod: int = -1,
        alias_name: str = "",
        prop_kind: int = 0,
        write_kind: int = 0,
        write_type: int = -1,
        ownership: int = 0,
        binding: int = 0,
        symbits: int = 0;
}

obj StubCatalog {
    has buf: bytes,
        pkg_dir: str,
        resolver: (CatalogResolver | None) = None,
        path_mapper: Callable[[str], str] | None = None,
        hdr: Header postinit,
        _str_memo: dict[int, str] postinit,
        _mod_memo: dict[int, Module] postinit,
        _scope_memo: dict[int, UniScopeNode] postinit,
        _sym_memo: dict[int, Symbol] postinit,
        _type_memo: dict[int, TypeBase] postinit,
        _shared_memo: dict[int, ClassDetailsShared] postinit,
        _sources: dict[int, Source] postinit,
        _mod_names: dict[str, int] postinit,
        _mod_rel: dict[str, int] postinit,
        _mod_recs: list[tuple[str, str, int, int, str]] postinit,
        _base_dir: str postinit,
        _mapper: Callable[[str], str] postinit;

    def for_session -> StubCatalog;
    def postinit;
    def string(sid: int) -> str;
    def string_or_none(sid: int) -> (str | None);
    def _rec(table_off: int, idx: int) -> Cursor;
    def key -> str;
    def ambient_typing_names -> dict[str, set[str]];
    def abs_path(rel: str) -> str;
    def rel_of(path: str) -> (str | None);
    def module_path(parts: list[str]) -> (str | None);
    def module(name: str) -> (Module | None);
    def module_for_path(path: str) -> (Module | None);
    def symbol_in_module(mid: int, name: str) -> (Symbol | None);
    def _source(mid: int) -> Source;
    def _token(
        mid: int, name: str, line: int, col: int, end_line: int, end_col: int
    ) -> Token;

    def module_by_id(mid: int) -> (Module | None);
    def _read_scope(sid: int) -> ScopeRec;
    def scope_of(sid: int) -> (UniScopeNode | None);
    def _populate(scope: UniScopeNode, rec: ScopeRec);
    def _read_symbol(sid: int) -> SymbolRec;
    def symbol_of(sid: int) -> (Symbol | None);
    def _make_symbol(sid: int, rec: SymbolRec, scope: (UniScopeNode | None)) -> Symbol;
    def _flags(value: int) -> any;
    def _literal(c: Cursor) -> (str | int | bool | None);
    def _types(ids: list[int]) -> list[TypeBase];
    def type_of(tid: int) -> (TypeBase | None);
    def shared_of(shid: int) -> (ClassDetailsShared | None);
    def _orphan_scope(name: str) -> UniScopeNode;
}

def read_region(path: str, offset: int, length: int) -> (bytes | None);

def open_catalog_bytes(buf: bytes, pkg_dir: str) -> (StubCatalog | None);

def open_catalog_file(path: str, pkg_dir: str) -> (StubCatalog | None);

def open_catalog_region(
    path: str, offset: int, length: int, pkg_dir: str
) -> (StubCatalog | None);
