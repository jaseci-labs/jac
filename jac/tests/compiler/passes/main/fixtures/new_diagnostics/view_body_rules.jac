"""Fixture: JSX-slot body rule violations caught by ViewLowerPass.

Exercises the slot-body diagnostics (`{...}` JSX child slots):
  - E2019: a slot cannot `return` a value.
  - E2020: bare `return;` is not allowed inside a template loop.
  - E2021: `break` / `skip` are not allowed inside a template loop.
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
