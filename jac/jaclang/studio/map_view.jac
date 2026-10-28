import from jaclang.osprey.ui.cells { StyleAttrs, TextSpan }
import from jaclang.osprey.ui.width { display_width }

glob MAP_VIEWS: list[str] = [
         "matrix",
         "layers",
         "issues",
         "roles",
         "iface",
         "rules",
         "clusters"
     ],
     LIST_VIEWS: list[str] = ["issues", "roles", "iface", "rules", "clusters"],
     ITEM_HINTS: dict[str, str] = {
         "violation": " Enter lists the wires · Space adds them to the context",
         "back": " Enter lists the wires · Space adds them to the context",
         "cycle": " Enter shows the cycle in the layers view · Space adds this level to the context",
         "module": " Enter shows its wiring · s slice · b blast radius · Space adds it to the context",
         "export": " Enter shows the blast radius of this name · Space adds its module to the context",
         "import": " Enter shows the provider's wiring · Space adds it to the context",
         "group": " Enter opens that package in the map",
         "rule": " Enter lists the wires the rule admits",
         "arm": " Enter lists the wires that use this permission",
         "wire": " Enter shows the wire in the wiring view · Space adds it to the context",
         "cluster": " Enter maps just this cluster's modules (x clears)",
         "split": " Enter opens the package in the map",
         "hint": ""
     },
     DETAIL_LINES: int = 4,
     GUTTER: int = 4,
     C_FEEDS_IT: int = 179,
     C_IT_FEEDS: int = 117,
     C_BACK: int = 203,
     C_CYCLE: int = 176,
     C_BOX: int = 237,
     C_CROSS: int = 236;

obj MapItem {
    has kind: str,
        label: str,
        detail: str = "",
        src: str = "",
        dst: str = "",
        key: str = "",
        section: str = "";
}

obj MapState {
    has scope: str = "",
        level: (GraphLevel | None) = None,
        sig: tuple[int, int, int] = (0, 0, 0),
        view: str = "matrix",
        r: int = 0,
        c: int = 0,
        top: int = 0,
        left: int = 0,
        sel: int = 0,
        item: int = 0,
        scroll: int = 0,
        width: int = 80,
        only: (set[str] | None) = None,
        only_label: str = "",
        only_spec: str = "",
        data: dict[str, any] = {};

    def selected_node -> (GraphNode | None);
    def selected_item -> (MapItem | None);
    def group_key -> str;
    def selected_edge -> (GraphEdge | None);
    def select_key(key: str) -> None;
    def set_view(view: str) -> None;
}

def crumbs(scope: str) -> str;

def view_tabs(view: str) -> str;

def node_token(nd: GraphNode) -> str;

def issue_items(level: GraphLevel) -> list[MapItem];

def view_items(state: MapState, lvl: GraphLevel) -> list[MapItem];

def roles_items(
    rep: RolesReport, scope: str, only: (set[str] | None)
) -> list[MapItem];

def iface_items(rep: InterfaceReport) -> list[MapItem];

def rules_items(rep: IntentReport) -> list[MapItem];

def clusters_items(rep: ClusterReport) -> list[MapItem];

def short_key(key: str, scope: str) -> str;

def map_move(state: MapState, key: str) -> bool;

def map_lines(state: MapState, w: int, h: int, focused: bool) -> list[list[TextSpan]];

def matrix_lines(
    state: MapState, lvl: GraphLevel, w: int, h: int, focused: bool
) -> list[list[TextSpan]];

def layer_layout(
    level: GraphLevel, w: int, spaced: bool
) -> tuple[list[tuple[int, int, int, int]], int];

def layers_lines(
    state: MapState, lvl: GraphLevel, w: int, h: int, focused: bool
) -> list[list[TextSpan]];

def list_lines(
    state: MapState, lvl: GraphLevel, w: int, h: int, focused: bool
) -> list[list[TextSpan]];

def node_detail(level: GraphLevel, nd: GraphNode, w: int) -> list[list[TextSpan]];

def edge_detail(level: GraphLevel, e: GraphEdge, w: int) -> list[list[TextSpan]];

def chip_line(
    head: str, chips: list[tuple[str, StyleAttrs]], w: int
) -> list[TextSpan];

def neighbour_style(level: GraphLevel, sel: GraphNode, nd: GraphNode) -> StyleAttrs;
