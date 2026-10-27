glob ROW_H: float = 16.0,
     COL_W: float = 44.0,
     PAD_X: float = 8.0,
     PAD_Y: float = 12.0,
     LABEL_W: float = 150.0,
     JOURNEY_MS: float = 1400.0;

def _short(t: str) -> str;

def _edge_d(e: dict[str, any]) -> str;

def _push(n: TreeNode, depth: int, acc: dict[str, any], px: float, py: float);

def _model(tree: list[TreeNode], version: str) -> dict[str, any];

def _chain(index: dict[str, any], cur_path: str) -> list[int];

def:pub DocsGraphFloat(
    tree: list[TreeNode], version: str, cur_path: str, on_go: any = None
) -> JsxElement;

impl _short(t: str) -> str {
    if len(t) > 24 {
        return t[:23] + "…";
    }
    return t;
}

impl _edge_d(e: dict[str, any]) -> str {
    x1 = e["x1"] as float;
    y1 = e["y1"] as float;
    x2 = e["x2"] as float;
    y2 = e["y2"] as float;
    mx = x1 + (x2 - x1) * 0.5;
    return "M "
        + str(x1)
        + " "
        + str(y1)
        + " C "
        + str(mx)
        + " "
        + str(y1)
        + ", "
        + str(mx)
        + " "
        + str(y2)
        + ", "
        + str(x2)
        + " "
        + str(y2);
}

impl _push(n: TreeNode, depth: int, acc: dict[str, any], px: float, py: float) {
    nodes: list[dict[str, any]] = acc["nodes"] as list[dict[str, any]];
    edges: list[dict[str, any]] = acc["edges"] as list[dict[str, any]];
    index: dict[str, any] = acc["index"] as dict[str, any];
    x = PAD_X + (depth as float) * COL_W;
    y = PAD_Y + (acc["row"] as float) * ROW_H;
    acc["row"] = (acc["row"] as float) + 1.0;
    i = len(nodes);
    nodes.append(
        {
            "i": i,
            "path": n.path,
            "label": n.title if n.title != "" else n.name,
            "kind": n.kind,
            "x": x,
            "y": y
        }
    );
    index[("d:" if n.kind == "dir" else "p:") + n.path] = i;
    edges.append({"i": i, "x1": px, "y1": py, "x2": x, "y2": y});
    if x + LABEL_W > (acc["w"] as float) {
        acc["w"] = x + LABEL_W;
    }
    for c in n.children {
        _push(c, depth + 1, acc, x, y);
    }
}

impl _model(tree: list[TreeNode], version: str) -> dict[str, any] {
    acc: dict[str, any] = {
        "row": 1.0,
        "nodes": [],
        "edges": [],
        "index": {"": 0},
        "w": 234.0
    };
    (acc["nodes"] as list[dict[str, any]]).append(
        {"i": 0, "path": "", "label": version, "kind": "root", "x": PAD_X, "y": PAD_Y}
    );
    for t in tree {
        _push(t, 1, acc, PAD_X, PAD_Y);
    }
    acc["h"] = PAD_Y + (acc["row"] as float) * ROW_H + PAD_Y;
    return acc;
}

impl _chain(index: dict[str, any], cur_path: str) -> list[int] {
    chain: list[int] = [0];
    walk = "";
    for seg in cur_path.split("/") {
        if seg == "" {
            continue;
        }
        walk = seg if walk == "" else (walk + "/" + seg);
        first = ("p:" + walk) if walk == cur_path else ("d:" + walk);
        second = ("d:" + walk) if walk == cur_path else ("p:" + walk);
        if first in index {
            chain.append(index[first] as int);
        } elif second in index {
            chain.append(index[second] as int);
        }
    }
    return chain;
}
