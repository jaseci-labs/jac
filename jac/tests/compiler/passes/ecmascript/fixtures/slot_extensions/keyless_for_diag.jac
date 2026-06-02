"""Rec 1.5 — keyless for-loop in a JSX slot (#6082 item 2).

Today `_emits_keyless_jsx` in `_check_body` only recurses into
`WhileStmt`; for-loops silently slip through. This fixture exercises
the dominant keyless footgun: a `for` slot rendering a single keyless
JSX child per iteration over an untyped list. The fix should fire a
warning — either reused W2019 (renamed "while" → "loop") or new W2021
if the auto-fragment work in item 1 lands first.
"""

def:pub TagList(tags: list[str]) -> JsxElement {
    return
        <ul class="tags">
            {for t in tags {
                <li>{t}</li>
            }}
        </ul>;
}
