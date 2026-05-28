"""Token-usage call detail: the full conversation one model call saw, the diff
vs the prior call, and what the call produced.

Opened by clicking a token-usage row. By default it shows only the input that is
NEW since the previous call (the cached prefix is collapsed to a one-line note),
which makes the context's call-by-call growth obvious; "show full input" expands
the whole conversation with the carried-over messages dimmed. Prev/Next step
through the calls of the same phase.
"""

sv import from ..server { CallDetail, CallMessage }

"""Compact a token count: 14000 -> "14.0k", 219 -> "219"."""
def _tk(n: int) -> str {
    return (str(n / 1000) + "k") if n >= 1000 else str(n);
}

"""One message as a labeled block: role + any tool-call summaries + its content.
Dimmed when carried over (cached) unchanged from the previous call."""
def MsgBlock(m: CallMessage, cached: bool) -> JsxElement {
    return
        <div className={"cd-msg cd-" + (m.role or "x") + (" cached" if cached else "")}>
            <div className="cd-msg-head">
                <span className="cd-role">{m.role or "?"}</span>
                {<span className="cd-tag">cached</span> if cached else <span/>}
            </div>
            {<pre className="cd-content">{m.content}</pre> if m.content else <span/>}
            {<div className="cd-tools">
                {[
                    (<div className="cd-tool" key={"t" + str(i)}>{t}</div>)
                    for (i, t) in enumerate(m.tools)
                ]}
            </div>
                if len(m.tools) > 0
                else <span/>}
        </div>;
}

def:pub CallDetailModal(
    detail: CallDetail,
    onPrev: Callable[[], None],
    onNext: Callable[[], None],
    onClose: Callable[[], None]
) -> JsxElement {
    has showFull: bool = False;

    newCount = detail.total - detail.shared;
    return
        <div className="modal-overlay" onClick={lambda { onClose(); }}>
            <div
                className="modal cd-modal"
                onClick={lambda e: any { e.stopPropagation(); }}
            >
                <div className="modal-head">
                    <span className={"tok-chip tok-" + detail.node}>{detail.node}</span>
                    <span className="cd-title">model call</span>
                    <span className="cd-tokens">
                        <b>{_tk(detail.tokens_in)}</b>
                        in ·
                        <b>{_tk(detail.tokens_out)}</b>
                        out
                    </span>
                    <span className="spacer"/>
                    <button
                        className="btn ghost sm"
                        disabled={detail.prev_id < 0}
                        onClick={lambda { onPrev(); }}
                    >
                        ‹ prev
                    </button>
                    <button
                        className="btn ghost sm"
                        disabled={detail.next_id < 0}
                        onClick={lambda { onNext(); }}
                    >
                        next ›
                    </button>
                    <button className="modal-x" onClick={lambda { onClose(); }}>
                        ×
                    </button>
                </div>
                <div className="modal-body cd-body">
                    {<div className="empty">
                        Call detail unavailable (it may have scrolled out of the capture window).
                    </div>
                        if not detail.found
                        else <div className="cd-inner">
                            <div className="cd-summary">
                                <span>
                                    <b>{str(detail.total)}</b>
                                    msgs
                                </span>
                                <span className="cd-sep">·</span>
                                <span>
                                    <b>{str(detail.shared)}</b>
                                    cached
                                </span>
                                <span className="cd-sep">·</span>
                                <span>
                                    <b>{str(newCount)}</b>
                                    new
                                </span>
                                <span className="spacer"/>
                                <button
                                    className="btn ghost sm"
                                    onClick={lambda { showFull = not showFull; }}
                                >
                                    {"show diff only"
                                        if showFull
                                        else "show full input"}
                                </button>
                            </div>
                            <div className="cd-note">
                                Tokens-in also counts the tool JSON schemas, which the API sends separately from these messages.
                            </div>
                            <div className="cd-section-label">
                                {"input — full conversation"
                                    if showFull
                                    else "input — new since previous call"}
                            </div>
                            {<div className="cd-cached-note">
                                ↑ {str(
                                    detail.shared
                                )} earlier message(s) carried over unchanged (cached)
                            </div>
                                if (not showFull and detail.shared > 0)
                                else <span/>}
                            <div className="cd-msgs">
                                {[
                                    (
                                        <MsgBlock
                                            m={m}
                                            cached={i < detail.shared}
                                            key={"i" + str(i)}
                                        />
                                            if (showFull or i >= detail.shared)
                                            else <span key={"i" + str(i)}/>
                                    ) for (i, m) in enumerate(detail.input)
                                ]}
                            </div>
                            <div className="cd-section-label">
                                output — what this call produced
                            </div>
                            <div className="cd-msgs">
                                {<div className="empty">
                                    No captured output (the live final call, or a routing decision).
                                </div>
                                    if len(detail.output) == 0
                                    else <span/>}{[
                                    (
                                        <MsgBlock
                                            m={m}
                                            cached={False}
                                            key={"o" + str(i)}
                                        />
                                    ) for (i, m) in enumerate(detail.output)
                                ]}
                            </div>
                        </div>}
                </div>
            </div>
        </div>;
}
