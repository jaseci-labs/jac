"""Live phase-graph visualizer for the agent walker, rendered with cytoscape.

Lays out whatever nodes/edges the backend traced from the real pipeline (see
`ui_graph`) once on mount -- no hardcoded states or positions -- then reflects
the walker's live position: the `active` node glows and pulses, every node along
`path` is marked visited, and each traversed edge lights up -- so you watch the
agent move through its own object-spatial graph in real time as `active`/`path`
update from the poll loop.
"""

import from react { useRef, useEffect }
import from "cytoscape" { default as cytoscape }
sv import from ..server { GraphNode, GraphEdge }

def:pub PhaseGraph(
    nodes: list[GraphNode],
    edges: list[GraphEdge],
    active: str,
    path: list[str],
    status: str,
    selected: str,
    onSelect: any
) -> JsxElement {
    containerRef: any = useRef(None);
    cyRef: any = useRef(None);

    # Build the graph once the nodes have loaded. The body is wrapped in the
    # positive guard rather than early-returning None: a useEffect callback must
    # return a cleanup function or nothing, never null (null is then invoked as
    # a cleanup and throws).
    useEffect(
        lambda { if containerRef.current and len(nodes) > 0 and not cyRef.current {
            els: list = [];
            # Rank each node by its position in the (BFS-ordered) node list so an
            # edge spanning more than one rank can be told apart from an adjacent
            # one below.
            ranks: dict[str, int] = {};
            for (i, n) in enumerate(nodes) {
                els.append({"data": {"id": n.id, "label": n.label, "desc": n.desc}});
                ranks[n.id] = i;
            }
            for e in edges {
                # A bidirectional pair between adjacent nodes (Build <-> QA) fans
                # out on its own, but an edge that skips a rank (QA -> Plan jumps
                # over Build) drawn straight runs behind the intervening node and
                # vanishes. Tag it so its style bows it out to the side instead.
                gap = ranks[e.source] - ranks[e.target];
                cls = "skip" if (gap > 1 or gap < -1) else "";
                els.append(
                    {
                        "data": {
                            "id": e.source + "->" + e.target,
                            "source": e.source,
                            "target": e.target
                        },
                        "classes": cls
                    }
                );
            }
            cy = cytoscape(
                {
                    "container": containerRef.current,
                    "elements": els,
                    # Auto-lay out the traced topology top-to-bottom from the
                    # entry (always the first node) instead of preset coordinates,
                    # so adding or rewiring a state places itself with no edit
                    # here. `directed` follows edge direction; loop-back edges
                    # (QA -> Build/Plan) just curve back up.
                    "layout": {
                        "name": "breadthfirst",
                        "directed": True,
                        "roots": "#" + nodes[0].id,
                        "spacingFactor": 1.1,
                        "fit": True,
                        "padding": 36
                    },
                    # Let the user drag the background to pan and scroll to zoom;
                    # keep nodes ungrabbable (autoungrabify) so a drag always pans
                    # rather than picking up a node. Clamp the zoom and soften the
                    # wheel so scrolling doesn't fly past the graph.
                    "userZoomingEnabled": True,
                    "userPanningEnabled": True,
                    "minZoom": 0.3,
                    "maxZoom": 3.0,
                    "wheelSensitivity": 0.2,
                    "boxSelectionEnabled": False,
                    "autoungrabify": True,
                    "style": [
                        {
                            "selector": "node",
                            "style": {
                                "label": "data(label)",
                                "text-valign": "center",
                                "text-halign": "center",
                                "color": "#cdd0d6",
                                "font-size": 15,
                                "font-weight": 600,
                                "width": 92,
                                "height": 56,
                                "shape": "round-rectangle",
                                "background-color": "#181a1d",
                                "border-width": 1.5,
                                "border-color": "#33363b",
                                "transition-property": "background-color, border-color, border-width",
                                "transition-duration": 250
                            }
                        },
                        {
                            "selector": "node.visited",
                            "style": {"border-color": "#4f46e5", "color": "#e7e7ea"}
                        },
                        {
                            "selector": "node.active",
                            "style": {
                                "background-color": "#312e81",
                                "border-color": "#818cf8",
                                "border-width": 3.5,
                                "color": "#ffffff"
                            }
                        },
                        {
                            "selector": "node.selected",
                            "style": {"border-color": "#22d3ee", "border-width": 3}
                        },
                        {
                            "selector": "edge",
                            "style": {
                                "width": 2,
                                "line-color": "#33363b",
                                "target-arrow-color": "#33363b",
                                "target-arrow-shape": "triangle",
                                "curve-style": "bezier",
                                "control-point-step-size": 60,
                                "transition-property": "line-color, target-arrow-color, width",
                                "transition-duration": 250
                            }
                        },
                        {
                            # A rank-skipping edge bows out to the side so it
                            # clears the node it would otherwise run straight
                            # behind, instead of bezier's straight default.
                            "selector": "edge.skip",
                            "style": {
                                "curve-style": "unbundled-bezier",
                                "control-point-distances": [130],
                                "control-point-weights": [0.5]
                            }
                        },
                        {
                            "selector": "edge.flow",
                            "style": {
                                "width": 3.5,
                                "line-color": "#6366f1",
                                "target-arrow-color": "#6366f1"
                            }
                        }
                    ]
                }
            );
            cyRef.current = cy;
            # Clicking a node selects it -- the parent shows that state's full
            # definition in the phase inspector. A grab cursor hints it's clickable.
            cy.on("tap", "node", lambda (evt: any) { onSelect(evt.target.id()); });
            cy.on(
                "mouseover",
                "node",
                lambda { if containerRef.current {
                    containerRef.current.style.cursor = "pointer";
                }}
            );
            cy.on(
                "mouseout",
                "node",
                lambda { if containerRef.current {
                    # Background shows a grab cursor (the canvas pans on drag).
                    containerRef.current.style.cursor = "grab";
                }}
            );
            # Re-fit after layout settles, in case the pane sized late.
            window.setTimeout(
                lambda { if cyRef.current {
                    cyRef.current.resize();
                    cyRef.current.fit(cyRef.current.elements(), 36);
                }},
                80
            );
        }},
        [nodes]
    );

    # Keep the canvas sized to its container: when a resize handle changes this
    # pane's dimensions the div resizes but cytoscape's canvas would not, so it
    # would crop -- a ResizeObserver re-syncs and refits on every size change.
    useEffect(
        lambda -> any {
            if not containerRef.current {
                return None;
            }
            ro = new(
                ResizeObserver,
                lambda { if cyRef.current {
                    cyRef.current.resize();
                    cyRef.current.fit(cyRef.current.elements(), 36);
                }}
            );
            ro.observe(containerRef.current);
            return lambda { ro.disconnect(); };
        },
        []
    );

    # Highlight the node the inspector is showing; rerun when the pick changes.
    useEffect(
        lambda {
            cy = cyRef.current;
            if cy {
                cy.nodes().removeClass("selected");
                if selected {
                    cy.getElementById(selected).addClass("selected");
                }
            }
        },
        [selected]
    );

    # Reflect the live walker position. Recreated each render, so it reads the
    # current `path`; rerun whenever the active node or run status changes.
    useEffect(
        lambda {
            cy = cyRef.current;
            if cy {
                cy.nodes().removeClass("active visited");
                cy.edges().removeClass("flow");
                i = 0;
                while i < len(path) {
                    cy.getElementById(path[i]).addClass("visited");
                    if i > 0 {
                        cy.getElementById(path[i - 1] + "->" + path[i]).addClass(
                            "flow"
                        );
                    }
                    i += 1;
                }
                if active {
                    cy.getElementById(active).addClass("active");
                }
            }
        },
        [active, status]
    );

    return
        <div className="graph-wrap">
            <div className="cy" ref={containerRef}/>
            <div className="graph-legend">
                <span className="legend-item">
                    <span className="legend-swatch" style={{"background": "#818cf8"}}/>
                    active
                </span>
                <span className="legend-item">
                    <span className="legend-swatch" style={{"background": "#4f46e5"}}/>
                    visited
                </span>
            </div>
        </div>;
}
