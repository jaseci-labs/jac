"""Exposes BUG: JSX whitespace between adjacent {expr} children is dropped.

Per React/Babel, a space character on the same line between two JSX
expression children is significant — `<div>{a} {b}</div>` should render
"<value-of-a> <value-of-b>", not "<value-of-a><value-of-b>".

The Jac parser used to drop any whitespace-only JSX_TEXT token, so the
emitted children array lost the separator entirely and the tutorial UI
showed text like "3tasks remaining" / "1.5lb" instead of "3 tasks
remaining" / "1.5 lb".

Whitespace that crosses a newline (indent between `}` and the next `{`
on a new line) is structural and must still be dropped, matching Babel's
JSX text normalization rules.
"""

cl {
    def:pub app() -> Any {
        count: int = 5;
        amount: float = 1.5;
        unit: str = "lb";
        return
            <div>
                <span>{count} {("task" if count == 1 else "tasks")} remaining</span>
                <span>{amount} {unit}</span>
                <p>
                    {count}
                    {unit}
                </p>
            </div>;
    }
}
