"""Reusable post composer for Little X (feed + channels)."""

import from .ui.avatar { Avatar, AvatarImage, AvatarFallback }
import from .ui.button { Button }
import from .ui.textarea { Textarea }

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
    ring_color = "var(--destructive)"
        if charsLeft < 0
        else ("var(--primary)" if charsLeft < 100 else "var(--muted-foreground)");
    over_limit = showCharRing and charsLeft < 0;
    initial = avatarAlt[0].upper() if avatarAlt else "?";

    return
        <div className="flex gap-3 border-b border-border px-4 py-3">
            <Avatar className="size-10 shrink-0">
                <AvatarImage src={avatar} alt={avatarAlt}/>
                <AvatarFallback>{initial}</AvatarFallback>
            </Avatar>
            <div className="flex min-w-0 flex-1 flex-col gap-2">
                <Textarea
                    className="min-h-0 resize-none border-0 bg-transparent px-0 py-1.5 text-lg shadow-none focus-visible:ring-0 dark:bg-transparent"
                    {placeholder}
                    {value}
                    onChange={lambda e: ChangeEvent { onChange(e.target.value); }}
                    {rows}
                />
                <div className="flex items-center justify-end gap-3">
                    {if showCharRing and len(value) > 0 {
                        <div className="flex items-center gap-2">
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
                                    className={"text-xs font-bold tabular-nums " + (
                                        "text-destructive"
                                            if charsLeft < 0
                                            else "text-primary"
                                    )}
                                >
                                    {str(charsLeft)}
                                </span>
                            }}
                        </div>
                    }}
                    <Button
                        className="rounded-full px-5 font-semibold"
                        disabled={not value.strip() or over_limit}
                        onClick={lambda { onPost(); }}
                    >
                        {buttonLabel}
                    </Button>
                </div>
            </div>
        </div>;
}
