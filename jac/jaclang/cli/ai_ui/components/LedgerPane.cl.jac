"""The session ledger, live: the durable cross-phase memory the walker writes.

Each phase records a one-line summary of what it accomplished, and the `note`
tool appends free-form notes -- the same text every later phase (and later turn)
sees in its prompt. The backend pushes a ledger message whenever it changes, so
this panel updates in real time. `ledger` is `any` because it arrives either as
the typed first-paint snapshot or as a raw stream dict; both expose
`.changes` ([{phase, summary}]) and `.notes` ([str]).
"""

import from react { useRef, useEffect }

def:pub LedgerPane(ledger: any) -> JsxElement {
    endRef: any = useRef(None);
    changes = ledger.changes if ledger else [];
    notes = ledger.notes if ledger else [];
    n = len(changes) + len(notes);
    useEffect(
        lambda { if endRef.current {
            endRef.current.scrollIntoView({"block": "end"});
        }},
        [n]
    );
    return
        <div className="bp-section ledgerpane">
            <div className="pane-head">
                ledger
                <span className="spacer"/>
                <span className="think-count">{str(n) + " entries"}</span>
            </div>
            <div className="bp-body ledger-body">
                {<div className="empty">Nothing recorded yet.</div>
                    if n == 0
                    else <div className="ledger-list">
                        {[
                            (
                                <div className="ledger-row" key={"c" + str(i)}>
                                    <span className="ledger-phase">{c.phase}</span>
                                    <span className="ledger-summary">{c.summary}</span>
                                </div>
                            ) for (i, c) in enumerate(changes)
                        ]}
                        {[
                            (
                                <div className="ledger-row note" key={"n" + str(i)}>
                                    <span className="ledger-phase">note</span>
                                    <span className="ledger-summary">{t}</span>
                                </div>
                            ) for (i, t) in enumerate(notes)
                        ]}
                        <div ref={endRef}/>
                    </div>}
            </div>
        </div>;
}
