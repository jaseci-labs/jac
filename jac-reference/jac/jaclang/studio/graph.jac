glob MAP_PREFIX: str = "map:",
     DEPS_PREFIX: str = "deps:",
     DEPS_SEP: str = "=>",
     MAX_TEXT_EDGES: int = 80,
     MAX_DEPS_WIRES: int = 80,
     MAX_TEXT_MATRIX: int = 40;

obj GraphNode {
    has key: str,
        label: str,
        kind: str = "module",
        modules: int = 0,
        inner: int = 0,
        layer: int = 0,
        cycle: int = -1,
        fed_from_outside: int = 0,
        feeds_outside: int = 0,
        violations: int = 0,
        rules: list[str] = [];
}

obj GraphEdge {
    has src: str,
        dst: str,
        wires: list[WireInfo] = [],
        back: bool = False,
        violations: int = 0;

    def count -> int;
}

obj GraphLevel {
    has scope: str,
        nodes: list[GraphNode] = [],
        edges: dict[tuple[str, str], GraphEdge] = {},
        cycles: list[list[str]] = [],
        index: dict[str, int] = {},
        wires: int = 0,
        back_wires: int = 0,
        inner_wires: int = 0,
        violations: int = 0;

    def node_of(key: str) -> (GraphNode | None);
    def label_of(key: str) -> str;
    def edge_of(src: str, dst: str) -> (GraphEdge | None);
    def out_edges(key: str) -> list[GraphEdge];
    def in_edges(key: str) -> list[GraphEdge];
    def back_edges -> list[GraphEdge];
    def layers -> list[list[GraphNode]];
    def title -> str;
}

def in_scope(key: str, scope: str) -> bool;

def group_of(key: str, scope: str) -> str;

def effective_scope(
    model: ProjectModel, scope: str, only: (set[str] | None) = None
) -> str;

def parent_scope(
    model: ProjectModel, scope: str, only: (set[str] | None) = None
) -> (str | None);

def scope_for(model: ProjectModel, key: str) -> str;

def graph_level(
    model: ProjectModel, scope: str = "", only: (set[str] | None) = None
) -> GraphLevel;

def order_groups(names: list[str], weights: dict[tuple[str, str], int]) -> list[str];

def strong_components(
    names: list[str], weights: dict[tuple[str, str], int]
) -> list[list[str]];

def edge_wires(
    model: ProjectModel, src: str, dst: str, only: (set[str] | None) = None
) -> list[WireInfo];

def edge_scope(src: str, dst: str) -> str;

def deps_key(src: str, dst: str) -> str;

def parse_deps_key(key: str) -> (tuple[str, str] | None);

def split_spec(key: str) -> tuple[str, str];

def level_dict(level: GraphLevel, model: ProjectModel) -> dict[str, any];

def level_text(level: GraphLevel, model: ProjectModel) -> str;

def matrix_text(level: GraphLevel) -> list[str];

def deps_text(
    model: ProjectModel, src: str, dst: str, only: (set[str] | None) = None
) -> str;
