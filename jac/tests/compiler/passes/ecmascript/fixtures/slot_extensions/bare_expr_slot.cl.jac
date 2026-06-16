"""Issue #6732: a bare expression statement inside a JSX `{...}` statement
slot is template content and must be accumulated into the slot's children,
the same way a bare JSX element statement is -- instead of being evaluated
and silently discarded.

`Repro` mirrors the three slot shapes from the issue, all carrying the same
conditional string. Before the fix only B (a bare JSX element) and C (a
single-expression slot) rendered; A (a bare expression statement) dropped
its content and the only diagnostic was a misleading W0060 docstring warning.

`Kinds` exercises the general rule: every value-producing bare expression
statement -- string, f-string, identifier, number -- becomes a child, in
both the `if`/`else` and `for` slot bodies.
"""

def:pub Repro(show: bool) -> JsxElement {
    return
        <div>
            <div data-test="bare">
                {if show {
                    "BARE_STRING_A";
                }}
            </div>

            <div data-test="element">
                {if show {
                    <span>ELEMENT_STRING_B</span>
                }}
            </div>

            <div data-test="ternary">
                {"TERNARY_STRING_C" if show else ""}
            </div>
        </div>;
}

def:pub Kinds(name: str, count: int) -> JsxElement {
    return
        <ul>
            {if count > 0 {
                f"have {count}";
            } else {
                "EMPTY_BRANCH";
            }}
            {for label in [name, "tail"] {
                label;
            }}
        </ul>;
}
