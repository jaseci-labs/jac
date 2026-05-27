"""Chat panel: the user's prompts, the agent's answers, and the composer.

Derives its message list from the shared event feed (the `user`, `answer`,
`system`, and `error` events), so it stays in sync with everything else the
poll loop drives. The composer sends on Enter (Shift+Enter for a newline) and
is disabled while a turn is running.
"""

import from .ui.Button { Button }
import from .ui.Badge { Badge }
sv import from ..server { UiEvent }

def:pub Conversation(
    events: list[UiEvent],
    status: str,
    draft: str,
    onDraftChange: Callable[[str], None],
    onSend: Callable[[], None]
) -> JsxElement {
    msgs = [
        e
        for e in events
        if e.kind == "user"
        or e.kind == "answer"
        or e.kind == "system"
        or e.kind == "error"
    ];
    running = status == "running";
    return
        <div className="pane">
            <div className="pane-head">
                Conversation
                <span className="spacer"/>
                {<Badge label="working" variant="amber" pulse={True}/>
                    if running
                    else (
                        <Badge label="done" variant="green"/>
                            if status == "done"
                            else <Badge label="idle"/>
                    )}
            </div>
            <div className="pane-body">
                {<div className="empty">
                    Ask the agent to build or change something in your project. Watch it move through Plan, Build, and QA on the right.
                </div>
                    if len(msgs) == 0
                    else <div className="chat-list">
                        {[
                            <div
                                className={"msg user"
                                    if m.kind == "user"
                                    else (
                                        "msg system"
                                            if (m.kind == "system" or m.kind == "error")
                                            else "msg agent"
                                    )}
                                key={m.id}
                            >
                                <span className="who">
                                    {"you"
                                        if m.kind == "user"
                                        else ("jac ai" if m.kind == "answer" else "")}
                                </span>
                                <div className="bubble">{m.text}</div>
                            </div> for m in msgs
                        ]}
                    </div>}
            </div>
            <div className="composer">
                <textarea
                    className="input"
                    placeholder="Describe a change, e.g. 'add a dark-mode toggle'…"
                    value={draft}
                    disabled={running}
                    onChange={lambda e: ChangeEvent { onDraftChange(e.target.value); }}
                    onKeyDown={lambda e: KeyboardEvent { if e.key == "Enter"
                    and not e.shiftKey {
                        e.preventDefault();
                        onSend();
                    }}}
                />
                <Button
                    label="Send"
                    onClick={onSend}
                    disabled={running or len(draft.strip()) == 0}
                />
            </div>
        </div>;
}
