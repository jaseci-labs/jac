"""Fixture: JSX-slot body rule violations caught by ViewLowerPass.

Exercises the slot-body diagnostics (`{...}` JSX child slots):
  - E2019: a slot cannot `return` a value (any position).
  - E2020: bare `return;` is not allowed anywhere in a slot body — use
           `skip;` for the slot early-exit.
  - E2021: `break;` is not allowed inside a template loop.
  - E2023: redundant `{...}` slot wrapping inside a slot body.
  - W2019: a `while` loop renders JSX without a `key` attribute.

Each rule is exercised at both a shallow position and at least one nested
position (loop wrapping a `match` / `switch` / `try`) so the recursion in
`_check_body` and `_emits_keyless_jsx` is covered.
"""

def:pub ValueReturn(x: int) -> JsxElement {
    return <div>
        {<p>before</p>; return x + 1;}
    </div>;
}

def:pub ReturnInLoop(items: list) -> JsxElement {
    return <ul>
        {for it in items {
            <li key={it}>{it}</li>
            return;
        }}
    </ul>;
}

def:pub ReturnAtTopLevel(items: list) -> JsxElement {
    # Bare `return;` outside any loop now also drives E2020 — the
    # "use `skip;` for slot early-exit" message applies regardless
    # of loop position.
    return <ul>
        {if len(items) == 0 {
            <li>empty</li>
            return;
        }}
    </ul>;
}

def:pub BreakInLoop(items: list) -> JsxElement {
    return <ul>
        {for it in items {
            <li key={it}>{it}</li>
            break;
        }}
    </ul>;
}

def:pub KeylessWhile(n: int) -> JsxElement {
    return <div>
        {while n > 0 {
            <span>tick</span>
        }}
    </div>;
}

def:pub RedundantSlotWrap(items: list) -> JsxElement {
    # Inside a slot body, an inner `{...}` slot is redundant — the body
    # is already in slot mode. E2023 fires for the inner `{if ...}`
    # below and for the inner `{for ...}` further down.
    return <ul>
        {if len(items) == 0 {
            <li>empty</li>
            skip;
        }
        {if len(items) > 5 {
            <li>too many</li>
        }}
        {for it in items {
            <li key={it}>{it}</li>
        }}}
    </ul>;
}

# --- Nested-recursion coverage --------------------------------------------

def:pub ReturnInLoopUnderMatch(items: list, kind: str) -> JsxElement {
    return <ul>
        {for it in items {
            <li key={it}>{it}</li>
            match kind {
                case "stop": return;
            }
        }}
    </ul>;
}

def:pub BreakInLoopUnderTry(items: list) -> JsxElement {
    return <ul>
        {for it in items {
            <li key={it}>{it}</li>
            try {
                break;
            } except Exception {
                <span key={it}>err</span>
            }
        }}
    </ul>;
}

def:pub KeylessWhileUnderTry(n: int) -> JsxElement {
    return <div>
        {while n > 0 {
            try {
                <span>tick</span>
            } except Exception {
                <em>err</em>
            }
        }}
    </div>;
}

def:pub KeylessWhileUnderSwitch(n: int, kind: str) -> JsxElement {
    return <div>
        {while n > 0 {
            switch kind {
                case "a": <span>a</span>
                default: <span>b</span>
            }
        }}
    </div>;
}
