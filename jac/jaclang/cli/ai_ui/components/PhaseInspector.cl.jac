"""Phase inspector: the full definition of whichever graph node is selected.

Click a node in the phase graph and this shows that state's role prompt (its
`sem` string -- the same text the router shows the model), its short blurb, and
the tools it exposes. With nothing selected it prompts the user to pick a node.
Reads from the same traced `nodes` the graph draws, so it always matches the
real pipeline.
"""

sv import from ..server { GraphNode }

def:pub PhaseInspector(nodes: list[GraphNode], selected: str) -> JsxElement {
    sel: any = None;
    for nd in nodes {
        if nd.id == selected {
            sel = nd;
        }
    }
    return
        <div className="bp-section inspector">
            <div className="pane-head">
                phase{<span className="insp-name">{sel.label}</span>
                    if sel
                    else <span/>}
            </div>
            <div className="bp-body insp-body">
                {<div className="empty">
                    Click a node in the phase graph to inspect it.
                </div>
                    if not sel
                    else <div className="insp-content">
                        <div className="insp-desc">{sel.desc}</div>
                        <div className="insp-label">role</div>
                        <div className="insp-sem">{sel.sem or "(no role prompt)"}</div>
                        {<div className="insp-label">tools</div>
                            if len(sel.tools) > 0
                            else <span/>}
                        {<div className="insp-tools">
                            {[
                                (<span className="insp-tool" key={t}>{t}</span>)
                                for t in sel.tools
                            ]}
                        </div>
                            if len(sel.tools) > 0
                            else <span/>}
                    </div>}
            </div>
        </div>;
}
