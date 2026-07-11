"""Token-usage call detail: the full conversation one model call saw, the diff
vs the prior call, and what the call produced.

Opened by clicking a token-usage row. By default it shows only the input that is
NEW since the previous call (the cached prefix is collapsed to a one-line note),
which makes the context's call-by-call growth obvious; "show full input" expands
the whole conversation with the carried-over messages dimmed. Prev/Next step
through the calls of the same phase.
"""

sv import from ..server { CallDetail, CallMessage, CallTool }

"""Compact a token count: 14000 -> "14.0k", 219 -> "219"."""
def _tk(n: int) -> str {
    return (str(n / 1000) + "k") if n >= 1000 else str(n);
}

"""One available tool: its name, description, and full JSON schema (the bytes the
API's `tools` param actually carries). The chip shows ~chars/4 tokens for this
schema -- the same rough estimate the modal uses for the tools total."""
def ToolBlock(t: CallTool) -> JsxElement {
    toks = len(t.schema) // 4;
    return
        <div className="cd-msg cd-toolschema">
            <div className="cd-msg-head">
                <span className="cd-role">{t.name or "?"}</span>
                <span className="spacer"/>
                <span className="cd-toks">{"~" + str(toks) + " tok"}</span>
            </div>
            {<div className="cd-tooldesc">{t.description}</div>
                if t.description
                else <span/>}
            <pre className="cd-content">{t.schema}</pre>
        </div>;
}

"""One message as a labeled block: role + any tool-call summaries + its content.
Dimmed when carried over (cached) unchanged from the previous call. The chip
shows ~chars/4 tokens for this message (its content plus any tool-call args)."""
def MsgBlock(m: CallMessage, cached: bool) -> JsxElement {
    chars = len(m.content);
    for tc in m.tools {
        chars += len(tc);
    }
    toks = chars // 4;
    return
        <div className={"cd-msg cd-" + (m.role or "x") + (" cached" if cached else "")}>
            <div className="cd-msg-head">
                <span className="cd-role">{m.role or "?"}</span>
                {<span className="cd-tag">cached</span> if cached else <span/>}
                <span className="spacer"/>
                <span className="cd-toks">{"~" + str(toks) + " tok"}</span>
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
    has showFull: bool = False,
        showTools: bool = False;

    newCount = detail.total - detail.shared;
    toolTokens = detail.tool_chars // 4;
    return
        <div className="modal-overlay" onClick={lambda { onClose(); }}>
            <div
                className="modal cd-modal"
                onClick={lambda (e: any) { e.stopPropagation(); }}
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
                            {<div className="cd-note">
                                Tokens-in spans both the messages below and the tool schemas (sent as a separate API param) — see "tools available" at the bottom.
                            </div>
                                if len(detail.tools) > 0
                                else <div className="cd-note">
                                    No tools were sent with this call (e.g. a routing or classification call), so tokens-in covers only the messages below.
                                </div>}
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
                            {<button
                                className="cd-section-label cd-tools-head"
                                onClick={lambda { showTools = not showTools; }}
                            >
                                <span className="chev">
                                    {"▾" if showTools else "▸"}
                                </span>
                                {"tools available — " + str(len(detail.tools)) + " · ~" + str(
                                    toolTokens
                                ) + " tok (sent as schemas, not messages)"}
                            </button>
                                if len(detail.tools) > 0
                                else <span/>}
                            {<div className="cd-msgs">
                                {[
                                    (<ToolBlock t={t} key={"ts" + str(i)}/>)
                                    for (i, t) in enumerate(detail.tools)
                                ]}
                            </div>
                                if (showTools and len(detail.tools) > 0)
                                else <span/>}
                        </div>}
                </div>
            </div>
        </div>;
}
