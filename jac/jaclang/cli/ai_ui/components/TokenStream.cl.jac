"""Live token firehose: every reasoning/answer token the model emits, raw and
in order, as it streams. A monospace ticker (a section of the bottom pane) that
auto-scrolls so the newest token stays in view.
"""

import from react { useRef, useEffect }

def:pub TokenStream(text: str, live: bool) -> JsxElement {
    endRef: any = useRef(None);
    useEffect(
        lambda { if endRef.current {
            endRef.current.scrollIntoView({"block": "end"});
        }},
        [len(text)]
    );
    return
        <div className="bp-section tokenstream">
            <div className="pane-head">
                token stream
                <span className="spacer"/>
                {<span className="think-dot live"/> if live else <span/>}
            </div>
            <div className="bp-body tokenstream-body">
                {text
                    if len(text) > 0
                    else "tokens appear here as the model generates…"}
                <span ref={endRef}/>
            </div>
        </div>;
}
