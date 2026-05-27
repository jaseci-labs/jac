"""Footer stats bar: the latest turn's summary, the same set the CLI prints.

Duration, tool breakdown (read/write/run), files changed, token usage, cost,
generation throughput, and project health -- each as a labeled chip. Mirrors
the CLI's one-line turn summary so the two surfaces show identical numbers.
"""

sv import from ..server { TurnStatsView }

"""Compact a token count: 12400 -> '12.4k', 840 -> '840'."""
def short_num(n: int) -> str {
    return (str(n / 1000) + "k") if n >= 1000 else str(n);
}

def:pub StatsBar(stats: TurnStatsView, active: str) -> JsxElement {
    has_tokens = stats.tokens_in > 0 or stats.tokens_out > 0;
    clean = stats.errors == 0 and stats.warnings == 0;
    health_label = (
        "clean"
            if clean
            else (
                str(stats.errors) + " err" + (
                    (", " + str(stats.warnings) + " warn") if stats.warnings > 0 else ""
                )
            )
    );
    health_cls = "stat health " + (
        "ok" if clean else ("warn" if stats.errors == 0 else "err")
    );
    return
        <div className="stats">
            <span className="stat">
                phase
                <b>{active or "—"}</b>
            </span>
            <span className="stat-sep"/>
            {<span className="stat-hint">no turns yet</span>
                if not stats.has_run
                else <span className="stat-row">
                    <span className="stat">
                        <b>{str(stats.elapsed) + "s"}</b>
                    </span>
                    <span className="stat">
                        <b>{str(stats.tools)}</b>
                        tools
                        <span className="stat-sub">
                            {str(stats.reads) + "r / " + str(stats.writes) + "w / " + str(
                                stats.runs
                            ) + "x"}
                        </span>
                    </span>
                    <span className="stat">
                        <b>{str(stats.files)}</b>
                        {"file" if stats.files == 1 else "files"}
                    </span>
                    {<span className="stat">
                        <b>{short_num(stats.tokens_in)}</b>
                        in
                        <b>{short_num(stats.tokens_out)}</b>
                        out
                    </span>
                        if has_tokens
                        else <span/>}
                    {<span className="stat">
                        <b>{"~$" + str(stats.cost)}</b>
                    </span>
                        if stats.cost > 0.0
                        else <span/>}
                    {<span className="stat">
                        <b>{str(stats.tok_per_s)}</b>
                        tok/s
                    </span>
                        if stats.tok_per_s > 0.0
                        else <span/>}
                    {<span className={health_cls}>
                        <span className="dot"/>
                        {health_label}
                    </span>
                        if stats.health_loaded
                        else <span/>}
                </span>}
        </div>;
}
