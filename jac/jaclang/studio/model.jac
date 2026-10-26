import os;
import re;
import json;
import hashlib;
import time;
import threading;

glob SKIP_DIRS: list[str] = [
         "node_modules",
         "__pycache__",
         "build",
         "dist",
         ".venv",
         "venv",
         "zig-out",
         "zig-pkg",
         "vendor"
     ],
     SYM_SCHEME: str = "jac://sym/";

node StNode {
    has key: str = "",
        name: str = "",
        kind: str = "",
        file: str = "",
        line: int = 0,
        end_line: int = 0,
        col: int = 0,
        doc: str = "";
}

node StProject(StNode) {
    has root_dir: str = "";
}

node StPackage(StNode) {}

node StModule(StNode) {
    has files: list[str] = [],
        mtime: float = 0.0,
        archwire: str = "",
        local_name: str = "",
        indexed: bool = False,
        error: str = "";
}

node StArchetype(StNode) {
    has bases: list[str] = [],
        walker_targets: list[str] = [],
        impl_file: str = "",
        impl_line: int = 0;
}

node StAbility(StNode) {
    has signature: str = "",
        owner: str = "",
        event: str = "",
        impl_file: str = "",
        impl_line: int = 0,
        impl_end_line: int = 0;
}

node StField(StNode) {
    has type_str: str = "",
        owner: str = "";
}

node StImpl(StNode) {
    has target: str = "";
}

node StRule(StNode) {
    has sources: list[str] = [],
        targets: list[str] = [],
        names: list[str] = [];
}

edge Contains: StNode --> StNode {}

edge Wire: StModule --> StModule {
    has names: list[str] = [],
        injected: bool = True,
        form: str = "",
        archwire: str = "",
        line: int = 0;
}

edge Implements: StImpl --> StNode {}

edge Governs: StRule --> StModule {}

edge Traverses: StArchetype --> StArchetype {}

edge Uses: StNode --> StNode {}

obj WireInfo {
    has provider: str,
        consumer: str,
        scope: str = "",
        names: list[str] = [],
        injected: bool = True,
        form: str = "",
        archwire: str = "",
        line: int = 0,
        violation: str = "",
        rules: list[str] = [],
        crosses: bool = False,
        local_provider: str = "",
        local_consumer: str = "";

    def to_dict -> dict[str, any];
}

obj ProjectModel {
    has root_dir: str,
        top: StProject postinit,
        modules: dict[str, StModule] = {},
        packages: dict[str, StPackage] = {},
        symbols: dict[str, StNode] = {},
        by_file: dict[str, str] = {},
        wires: list[WireInfo] = [],
        rules: list[StRule] = [],
        archwires: list[str] = [],
        prog: JacProgram postinit,
        lock: any postinit,
        build_secs: float = 0.0,
        index_secs: float = 0.0,
        uses_done: set[str] = set(),
        arch_mtimes: dict[str, float] = {},
        rule_recs: dict[str, any] = {},
        dir_mtimes: dict[str, float] = {},
        hot_dirs: set[str] = set(),
        found: list[str] = [],
        _host: (ProjectHost | None) = None;

    def postinit;
    def build(on_progress: any = None, index: bool = True);
    def index_all(on_progress: any = None);
    def _arch_files -> list[str];
    def _head_files -> list[str];
    def _rel_dotted(path: str) -> str;
    def _ensure_package(dotted: str) -> StNode;
    def _add_module(key: str, path: str, archwire: str, local_name: str) -> StModule;
    def _discover;
    def _spec_key(spec: WiringSpec, local: str) -> str;
    def _is_nested_project(arch: str) -> bool;
    def _add_wiring(arch: str, spec: WiringSpec);
    def _add_symbol(owner: StNode, sym: StNode);
    def _clear_module_symbols(mod: StModule);
    def _text(nd: any) -> str;
    def _source_text(nd: any) -> str;
    def _span(sym: StNode, nd: uni.UniNode);
    def _doc(nd: any) -> str;
    def _ability_node(key: str, ab: uni.Ability, owner: str) -> StAbility;
    def index_module(key: str) -> bool;
    def _index_archetype(mod: StModule, arch: uni.Archetype);
    def _index_impl(mod: StModule, idef: uni.ImplDef) -> None;
    def _link_walkers;
    def refresh(path: str) -> list[str];
    def stale_files -> list[str];
    def project_host -> ProjectHost;
    def new_files -> list[str];
    def _note_dir(path: str) -> None;
    def _forget_file(real: str) -> list[str];
    def module_for_file(path: str) -> (StModule | None);
    def providers(key: str) -> list[WireInfo];
    def consumers(key: str) -> list[WireInfo];
    def children(key: str) -> list[StNode];
    def node_for(key: str) -> (StNode | None);
    def implementations(key: str) -> list[StImpl];
    def traversals(key: str) -> list[StNode];
    def walkers_of(key: str) -> list[StNode];
    def rules_for(key: str) -> list[StRule];
    def link_uses(key: str) -> None;
    def _cache_path(mod: StModule) -> str;
    def _save_cache(mod: StModule) -> None;
    def _load_cache(mod: StModule) -> bool;
    def rewire -> None;
    def _note_arch_mtimes -> None;
    def neighbourhood(key: str) -> (Neighbourhood | None);
    def users_of(key: str) -> list[StNode];
    def _link_for(nd: StNode) -> None;
    def uses_of(key: str) -> list[StNode];
    def search(
        query: str, limit: int = 50, kinds: (list[str] | None) = None
    ) -> list[StNode];

    def node_dict(nd: StNode) -> dict[str, any];
    def module_dict(key: str, deep: bool = True) -> dict[str, any];
    def _tree_dict(nd: StNode) -> dict[str, any];
    def to_dict(module: str = "") -> dict[str, any];
    def stats -> dict[str, any];
}

def fuzzy_score(q: str, key: str, name: str) -> int;

def wire_violation(
    spec: WiringSpec, provider: str, consumer: str, names: list[str], whole: bool
) -> str;

def sym_uri(key: str) -> str;

def find_project_root(start: str) -> str;

walker Neighbourhood {
    has providers: list[StNode] = [],
        consumers: list[StNode] = [],
        members: list[StNode] = [],
        rules: list[StNode] = [],
        impls: list[StNode] = [],
        walkers: list[StNode] = [],
        targets: list[StNode] = [],
        users: list[StNode] = [],
        uses: list[StNode] = [];

    can gather with StNode entry;
}

walker UsesOf {
    has users: list[StNode] = [],
        uses: list[StNode] = [];

    can gather with StNode entry;
}

glob INDEX_FORMAT: int = 1,
     NODE_EXTRA: dict[str, list[str]] = {
         "StArchetype": ["bases", "walker_targets", "impl_file", "impl_line"],
         "StAbility": [
             "signature",
             "owner",
             "event",
             "impl_file",
             "impl_line",
             "impl_end_line"
         ],
         "StField": ["type_str", "owner"],
         "StImpl": ["target"]
     },
     NODE_BASE: list[str] = [
         "key",
         "name",
         "kind",
         "file",
         "line",
         "end_line",
         "col",
         "doc"
     ];
