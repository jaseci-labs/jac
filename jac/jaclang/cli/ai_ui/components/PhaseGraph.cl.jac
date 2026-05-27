"""Live phase-graph visualizer for the agent walker, rendered with cytoscape.

Draws the Plan -> Build -> QA -> Done pipeline (with QA's loop-back edges) once
on mount, then reflects the walker's live position: the `active` node glows and
pulses, every node along `path` is marked visited, and each traversed edge
lights up -- so you watch the agent move through its own object-spatial graph in
real time as `active`/`path` update from the poll loop.
"""

import from react { useRef, useEffect }
cl import from "cytoscape" { default as cytoscape }
sv import from ..server { GraphNode, GraphEdge }

def:pub PhaseGraph(
    nodes: list[GraphNode],
    edges: list[GraphEdge],
    active: str,
    path: list[str],
    status: str
) -> JsxElement {
    containerRef: any = useRef(None);
    cyRef: any = useRef(None);

    # Build the graph once the nodes have loaded. The body is wrapped in the
    # positive guard rather than early-returning None: a useEffect callback must
    # return a cleanup function or nothing, never null (null is then invoked as
    # a cleanup and throws).
    useEffect(
        lambda { if containerRef.current and len(nodes) > 0 and not cyRef.current {
            positions = {
                "Plan": {"x": 170, "y": 60},
                "Build": {"x": 170, "y": 190},
                "QA": {"x": 170, "y": 320},
                "Done": {"x": 170, "y": 450}
            };
            els: list = [];
            for n in nodes {
                els.append(
                    {
                        "data": {"id": n.id, "label": n.label, "desc": n.desc},
                        "position": positions.get(n.id, {"x": 170, "y": 60})
                    }
                );
            }
            for e in edges {
                els.append(
                    {
                        "data": {
                            "id": e.source + "->" + e.target,
                            "source": e.source,
                            "target": e.target
                        }
                    }
                );
            }
            cy = cytoscape(
                {
                    "container": containerRef.current,
                    "elements": els,
                    "layout": {"name": "preset", "fit": True, "padding": 36},
                    "userZoomingEnabled": False,
                    "userPanningEnabled": False,
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
