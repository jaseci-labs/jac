"""Fixture: `defview` body rule violations caught by ViewLowerPass.

Exercises the view_body_check diagnostics:
  - E2019: a `defview` cannot `return` a value.
  - E2020: bare `return;` is not allowed inside a template loop.
  - E2021: `break` / `skip` are not allowed inside a template loop.
  - W2019: a `while` loop renders JSX without a `key` attribute.

Each rule is exercised at both a shallow position and at least one nested
position (loop wrapping a `match` / `switch` / `try`) so the recursion in
`_check_body` and `_emits_keyless_jsx` is covered.
"""

defview ValueReturn(x: int) {
    <p>before</p>
    return x + 1;
}

defview ReturnInLoop(items: list) {
    for it in items {
        <li key={it}>{it}</li>
        return;
    }
}

defview BreakInLoop(items: list) {
    for it in items {
        <li key={it}>{it}</li>
        break;
    }
}

defview KeylessWhile(n: int) {
    while n > 0 {
        <span>tick</span>
    }
}

# --- Nested-recursion coverage --------------------------------------------

defview ReturnInLoopUnderMatch(items: list, kind: str) {
    for it in items {
        <li key={it}>{it}</li>
        match kind {
            case "stop": return;
        }
    }
}

defview BreakInLoopUnderTry(items: list) {
    for it in items {
        <li key={it}>{it}</li>
        try {
            break;
        } except Exception {
            <span key={it}>err</span>
        }
    }
}

defview KeylessWhileUnderTry(n: int) {
    while n > 0 {
        try {
            <span>tick</span>
        } except Exception {
            <em>err</em>
        }
    }
}

defview KeylessWhileUnderSwitch(n: int, kind: str) {
    while n > 0 {
        switch kind {
            case "a": <span>a</span>
            default: <span>b</span>
        }
    }
}
