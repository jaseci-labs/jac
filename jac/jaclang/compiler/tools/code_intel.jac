import os;
import time;
import json;

import from pathlib { Path }

walker SymbolCollector(ScopeWalker) {
    has symbols: list[uni.Symbol] = [];

    can collect_scope with uni.UniScopeNode entry;
}

glob INDEX_SCHEMA: int = 1,
     _SKIP_DIRS: set[str] = {
         "__pycache__",
         ".git",
         ".venv",
         "venv",
         "node_modules",
         "build",
         "dist",
         ".mypy_cache",
         ".pytest_cache"
     },
     _ARCH_KIND: dict[str, str] = {
         "node": "node",
         "walker": "walker",
         "edge": "edge",
         "obj": "obj",
         "class": "class",
         "enum": "enum"
     };


def _real(path: str) -> str;


obj SourceRef {
    has file: str,
        line: int,
        col: int = 0,
        role: str = "use",
        snippet: str = "";

    def render -> str;
    def to_dict -> dict[str, any];
}


obj SymbolInfo {
    has name: str,
        kind: str,
        file: str,
        line: int,
        col: int = 0,
        type_str: str = "",
        doc: str = "",
        signature: str = "",
        fields: list[str] = [],
        abilities: list[str] = [],
        base_classes: list[str] = [],
        is_genai: bool = False;

    def render -> str;
    def to_dict -> dict[str, any];
    static def from_dict(d: dict[str, any]) -> SymbolInfo;
}


obj Diagnostic {
    has file: str,
        line: int,
        severity: str,
        message: str;

    def render -> str;
    def to_dict -> dict[str, any];
}


def _diag_key(d: Diagnostic) -> str;


obj EntryPoint {
    has walker_name: str,
        ability: str,
        node_type: str,
        event: str,
        file: str = "",
        line: int = 0;

    def render -> str;
    def to_dict -> dict[str, any];
    static def from_dict(d: dict[str, any]) -> EntryPoint;
}


obj ContextSlice {
    has query: str,
        target: SymbolInfo | None = None,
        related: list[SymbolInfo] = [],
        uses: list[SourceRef] = [];

    def render -> str;
    def to_dict -> dict[str, any];
}


obj CodeIntelligence {
    has proj_dir: str,
        on_event: any = None;

    def postinit;
    def load;
    def _emit(op: str, file: str, recompiled: int, t0: float, cached: int = 0);
    def refresh(file: str = "") -> None;
    def _head_for(real: str) -> str;
    def _drop_file(real: str);
    def _full_compile_one(file: str) -> tuple[list[Alert], list[Alert]];
    def _cached_record(real: str) -> (dict[str, any] | None);
    def _compile_and_index(stale: set[str]);
    def _build_record(
        real: str, mod: uni.Module, uses: list[list[any]], diags: list[list[any]]
    ) -> dict[str, any];

    def _project_modules -> dict[str, uni.Module];
    def _dependents_of(targets: set[str]) -> set[str];
    def _decls_named(name: str) -> list[dict[str, any]];
    def _dir_signature -> dict[str, float];
    def _ensure;
    def is_loaded -> bool;
    def files -> list[str];
    def _discover -> list[str];
    def _collect_syms(scope: uni.UniScopeNode, out: list[uni.Symbol]);
    def _kind_of(owner: uni.UniNode) -> str;
    def _expr_str(expr: uni.UniNode | None) -> str;
    def _doc_of(owner: uni.UniNode) -> str;
    def _info(sym: uni.Symbol) -> SymbolInfo | None;
    def _fill_archetype(info: SymbolInfo, arch: uni.Archetype);
    def lookup(name: str) -> list[SymbolInfo];
    def definition(name: str) -> SymbolInfo | None;
    def references(name: str) -> list[SourceRef];
    def importers(name: str) -> list[str];
    def symbols(file: str = "") -> list[SymbolInfo];
    def archetypes(kind: str = "") -> list[SymbolInfo];
    def _archetype_info(arch: uni.Archetype) -> SymbolInfo | None;
    def entry_points -> list[EntryPoint];
    def _module_entry_points(mod: uni.Module) -> list[EntryPoint];
    def walkers_visiting(node_type: str) -> list[EntryPoint];
    def nodes_visited_by(walker_name: str) -> list[EntryPoint];
    def diagnostics(file: str = "") -> list[Diagnostic];
    def refresh_and_diff(file: str = "") -> list[Diagnostic];
    def slice_for(name: str, depth: int = 1) -> ContextSlice;
    def _type_names(info: SymbolInfo) -> list[str];
    def _idents(text: str) -> list[str];
}
