"""Footer stats bar: the latest turn's tool/file tallies and the run status."""

sv import from ..server { UiEvent }

def:pub StatsBar(events: list[UiEvent], active: str) -> JsxElement {
    latest = "";
    for e in events {
        if e.kind == "stats" {
            latest = e.text;
        }
    }
    return
        <div className="stats">
            <span className="stat">
                phase:
                <b>{active or "—"}</b>
            </span>
            <span className="spacer"/>
            <span className="stat">{latest or "no turns yet"}</span>
        </div>;
}
