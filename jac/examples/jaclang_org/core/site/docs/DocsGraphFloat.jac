import from core.docs.graph { TreeNode }

glob ROW_H: float = 16.0,
     COL_W: float = 44.0,
     PAD_X: float = 8.0,
     PAD_Y: float = 12.0,
     LABEL_W: float = 150.0,
     JOURNEY_MS: float = 1400.0;

def _short(t: str) -> str {
    if len(t) > 24 {
        return t[:23] + "…";
    }
    return t;
}

def _edge_d(e: dict[str, any]) -> str {
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

def _push(n: TreeNode, depth: int, acc: dict[str, any], px: float, py: float) {
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

def _model(tree: list[TreeNode], version: str) -> dict[str, any] {
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

def _chain(index: dict[str, any], cur_path: str) -> list[int] {
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

def:pub DocsGraphFloat(
    tree: list[TreeNode], version: str, cur_path: str, on_go: any = None
) -> JsxElement {
    has boxRef: Ref[any] = Ref(),
        dotRef: Ref[any] = Ref(),
        rafRef: Ref[any] = Ref(0);

    def go(p: str) {
        if on_go is not None {
            on_go(p);
        }
    }

    def run_journey {
        if rafRef.current {
            window.cancelAnimationFrame(rafRef.current);
            rafRef.current = 0;
        }
        m = _model(tree, version);
        chain = _chain(m["index"] as dict[str, any], cur_path);
        nodes = m["nodes"] as list[dict[str, any]];
        dot: any = dotRef.current;
        if not dot {
            return;
        }
        if len(chain) < 2 {
            rn = nodes[0] as dict[str, any];
            dot.setAttribute("cx", str(rn["x"] as float));
            dot.setAttribute("cy", str(rn["y"] as float));
            dot.setAttribute("opacity", "1");
            return;
        }
        segs: list[dict[str, any]] = [];
        total = 0.0;
        k = 1;
        while k < len(chain) {
            el: any = document.getElementById("dgf-e-" + str(chain[k] as int));
            if el {
                seg_len = el.getTotalLength() as float;
                el.setAttribute("stroke-dasharray", str(seg_len));
                el.setAttribute("stroke-dashoffset", str(seg_len));
                segs.append({"el": el, "len": seg_len});
                total += seg_len;
            }
            k += 1;
        }
        if len(segs) == 0 or total <= 0.0 {
            return;
        }
        dot.setAttribute("opacity", "1");
        st: dict[str, any] = {"t0": -1.0};
        fns: dict[str, any] = {"step": None};
        fns["step"] = lambda (ts: any) {
            if (st["t0"] as float) < 0.0 {
                st["t0"] = ts as float;
            }
            prog = ((ts as float) - (st["t0"] as float)) / JOURNEY_MS;
            if prog > 1.0 {
                prog = 1.0;
            }
            ease = 1.0 - (1.0 - prog) * (1.0 - prog) * (1.0 - prog);
            d = ease * total;
            cum = 0.0;
            for s in segs {
                sl = s["len"] as float;
                sel: any = s["el"];
                if d >= cum + sl {
                    sel.setAttribute("stroke-dashoffset", "0");
                } elif d > cum {
                    sel.setAttribute("stroke-dashoffset", str(sl - (d - cum)));
                    pt: any = sel.getPointAtLength(d - cum);
                    dot.setAttribute("cx", str(pt.x as float));
                    dot.setAttribute("cy", str(pt.y as float));
                    box: any = boxRef.current;
                    if box {
                        box.scrollTop = (pt.y as float)
                            - (box.clientHeight as float) / 2.0;
                        box.scrollLeft = (pt.x as float)
                            - (box.clientWidth as float) / 2.0;
                    }
                }
                cum += sl;
            }
            if prog < 1.0 {
                rafRef.current = window.requestAnimationFrame(fns["step"]);
            } else {
                rafRef.current = 0;
                last = segs[len(segs) - 1] as dict[str, any];
                lel: any = last["el"];
                ept: any = lel.getPointAtLength(last["len"] as float);
                dot.setAttribute("cx", str(ept.x as float));
                dot.setAttribute("cy", str(ept.y as float));
            }
        };
        rafRef.current = window.requestAnimationFrame(fns["step"]);
    }

    can with [tree, cur_path] entry {
        if len(tree) > 0 {
            _ = setTimeout(lambda { run_journey(); }, 80);
        }
    }

    m = _model(tree, version);
    nodes = m["nodes"] as list[dict[str, any]];
    edges = m["edges"] as list[dict[str, any]];
    chain = _chain(m["index"] as dict[str, any], cur_path);
    target_i = (chain[len(chain) - 1] as int) if len(chain) > 1 else -1;
    return
        <div>
            <p
                className="mb-2 font-mono text-[10px] uppercase tracking-widest text-muted-foreground"
            >
                live graph
            </p>
            <div ref={boxRef} className="no-scrollbar max-h-[33vh] overflow-auto">
                <svg width={m["w"] as float} height={m["h"] as float} className="block">
                    {for e in edges {
                        <path
                            key={"e" + str(e["i"] as int)}
                            id={"dgf-e-" + str(e["i"] as int)}
                            d={_edge_d(e)}
                            fill="none"
                            className={"stroke-primary"
                                if (e["i"] as int) in chain
                                else "stroke-border"}
                            strokeWidth={1.8 if (e["i"] as int) in chain else 1.0}
                        />
                    }}
                    {for n in nodes {
                        <g
                            key={"n" + str(n["i"] as int)}
                            onClick={lambda (_ev: MouseEvent) { go(n["path"] as str); }}
                            className="cursor-pointer"
                        >
                            {if (n["i"] as int) == target_i {
                                <circle
                                    cx={n["x"] as float}
                                    cy={n["y"] as float}
                                    r={6}
                                    fill="none"
                                    strokeWidth={1}
                                    className="docmap-halo animate-ping stroke-primary"
                                />
                            }}
                            {if (n["kind"] as str) == "root" {
                                <circle
                                    cx={n["x"] as float}
                                    cy={n["y"] as float}
                                    r={4}
                                    className="fill-primary"
                                />
                            } elif (n["i"] as int) in chain {
                                <circle
                                    cx={n["x"] as float}
                                    cy={n["y"] as float}
                                    r={3.2}
                                    className="fill-primary/80"
                                />
                            } elif (n["kind"] as str) == "dir" {
                                <circle
                                    cx={n["x"] as float}
                                    cy={n["y"] as float}
                                    r={2.8}
                                    fill="none"
                                    strokeWidth={1}
                                    className="stroke-muted-foreground/40"
                                />
                            } else {
                                <circle
                                    cx={n["x"] as float}
                                    cy={n["y"] as float}
                                    r={2.2}
                                    className="fill-muted-foreground/50"
                                />
                            }   }
                            <text
                                x={(n["x"] as float) + 7.0}
                                y={(n["y"] as float) + 3.0}
                                fontSize={9}
                                className={"font-mono "
                                    + (
                                        "fill-primary"
                                            if (n["i"] as int) in chain
                                            else "fill-muted-foreground/70"
                                    )}
                            >
                                {_short(n["label"] as str)}
                            </text>
                        </g>
                    }}
                    <circle ref={dotRef} r={4} className="fill-primary" opacity={0}/>
                </svg>
            </div>
        </div>;
}
