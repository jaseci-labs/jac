"""Reusable post composer for Little X (feed + channels)."""

def:pub Composer(
    avatar: str,
    avatarAlt: str,
    placeholder: str,
    value: str,
    onChange: Callable[[str], None],
    onPost: Callable[[], None],
    rows: int = 3,
    buttonLabel: str = "Post",
    showCharRing: bool = False,
) -> JsxElement {
    charsLeft = 280 - len(value);
    ring_progress = min(1.0, (280 - charsLeft) / 280.0);
    ring_offset = str(62.83 * (1.0 - ring_progress));
    ring_color = "#ef4444"
        if charsLeft < 0
        else (
            "#f97316"
                if charsLeft < 50
                else ("#fb923c" if charsLeft < 100 else "#2a2a35")
        );
    over_limit = showCharRing and charsLeft < 0;

    return
        <div className="lx-composer">
            <img className="lx-avatar" src={avatar} alt={avatarAlt}/>
            <div className="lx-composer-body">
                <textarea
                    className="lx-composer-textarea"
                    {placeholder}
                    {value}
                    onChange={lambda e: ChangeEvent { onChange(e.target.value); }}
                    {rows}
                />
                <div className="lx-composer-footer">
                    {if showCharRing {
                        <div className="lx-char-ring-wrap">
                            <svg className="lx-char-ring" viewBox="0 0 24 24">
                                <circle
                                    className="lx-char-ring-bg"
                                    cx={12}
                                    cy={12}
                                    r={10}
                                />
                                <circle
                                    className="lx-char-ring-fill"
                                    cx={12}
                                    cy={12}
                                    r={10}
                                    strokeDasharray={"62.83"}
                                    strokeDashoffset={ring_offset}
                                    stroke={ring_color}
                                />
                            </svg>
                            {if charsLeft <= 20 {
                                <span
                                    className={"lx-char-count-over"
                                        if charsLeft < 0
                                        else "lx-char-count-warn"}
                                >
                                    {str(charsLeft)}
                                </span>
                            }}
                        </div>
                    } else {
                        <div/>
                    } }
                    <button
                        className="lx-post-btn"
                        disabled={not value.strip() or over_limit}
                        onClick={lambda { onPost(); }}
                    >
                        {buttonLabel}
                    </button>
                </div>
            </div>
        </div>;
}
