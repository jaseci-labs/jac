"""Test that {#* block comment *#} inside JSX body is handled correctly.

Three cases:
  1. Comment between siblings — both siblings must survive.
  2. Comment as the only child — element must compile with no children.
  3. Comment adjacent to a real {expr} — both must survive.
"""

# Case 1: comment between two sibling elements
def with_siblings -> JsxElement {
    return
        <div>
            <span>before</span>
            { #* this comment should be silently dropped *# }
            <span>after</span>
        </div>;
}

# Case 2: comment as sole child
def comment_only_child -> JsxElement {
    return
        <section>{ #* nothing to render *# }</section>;
}

# Case 3: comment next to a real expression — both must survive
def comment_next_to_expr -> JsxElement {
    count: int = 42;
    return
        <p>{ #* label: *# }{count}</p>;
}
