"""Rec 9 — `.style.css` annex with auto-scoped class names.

This fixture references `class="card"` and the same-base-name
`style_annex.style.css` annex declares `.card { ... }`. The compiler is
expected to:

  1. Hash each declared class with a per-module digest (e.g. blake2s
     truncated to 8 hex chars).
  2. Rewrite the CSS rule's selector to the hashed form.
  3. Rewrite JSX `className` literals in the same module that match a
     declared class to the same hashed form.
  4. Emit the rewritten CSS as a sibling file and a side-effect import.

The annex file lives alongside this one as `style_annex.style.css`.
"""

def:pub Card(title: str, body: str) -> JsxElement {
    return
        <article className="card">
            <h2 className="card-title">{title}</h2>
            <p>{body}</p>
        </article>;
}
