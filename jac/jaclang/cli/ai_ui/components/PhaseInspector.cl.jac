"""Phase inspector: the full definition of whichever graph node is selected,
plus that phase's captured context.

Click a node in the phase graph and this shows that state's role prompt (its
`sem` string -- the same text the router shows the model), its short blurb, the
tools it exposes, and the contents of its context: the messages that phase last
worked with (system prompt, the kickoff directive, and the tool turns it
accumulated). The static definition comes from the same traced `nodes` the graph
draws; the context is fetched per click (`agent_phase_context`) and passed in.
"""

sv import from ..server { GraphNode, PhaseContext }

def:pub PhaseInspector(
    nodes: list[GraphNode], selected: str, context: any
) -> JsxElement {
    sel: any = None;
    for nd in nodes {
        if nd.id == selected {
            sel = nd;
        }
    }
    # `context` is the fetched PhaseContext for `selected` (or None before a fetch
    # / for a phase that has not run). Guard every field read against that.
    hasCtx = bool(context) and context.found and len(context.messages) > 0;
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
                        <div className="insp-label">
                            context{<span className="insp-ctx-count">
                                {" · " + str(len(context.messages)) + " msg"}
                            </span>
                                if hasCtx
                                else <span/>}
                        </div>
                        {<div className="insp-ctx-empty">
                            No captured context yet — run a turn, then click this phase.
                        </div>
                            if not hasCtx
                            else <div className="insp-ctx">
                                {[
                                    (
                                        <div className="ictx-msg" key={"m" + str(i)}>
                                            <span className="ictx-role">
                                                {m.role or "?"}
                                            </span>
                                            {<pre className="ictx-body">
                                                {m.content}
                                            </pre>
                                                if m.content
                                                else <span/>}
                                            {<div className="ictx-tools">
                                                {[
                                                    (
                                                        <span
                                                            className="ictx-tool"
                                                            key={"tc" + str(j)}
                                                        >
                                                            {tc}
                                                        </span>
                                                    ) for (j, tc) in enumerate(m.tools)
                                                ]}
                                            </div>
                                                if len(m.tools) > 0
                                                else <span/>}
                                        </div>
                                    ) for (i, m) in enumerate(context.messages)
                                ]}
                            </div>}
                    </div>}
            </div>
        </div>;
}
