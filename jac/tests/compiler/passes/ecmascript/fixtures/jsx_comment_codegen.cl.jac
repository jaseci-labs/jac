"""Codegen fixture for JsxComment.  Each function exercises a different
JSX-comment placement; runtime children list must contain no null slots."""

cl def:pub comment_only_child -> JsxElement {
    return
        <section>{ #* drop me *# }</section>;
}

cl def:pub comment_between_siblings -> JsxElement {
    return
        <div>
            <span>before</span>
            { #* invisible *# }
            <span>after</span>
        </div>;
}

cl def:pub comment_adjacent_to_expression -> JsxElement {
    count: int = 7;
    return
        <p>{ #* label *# }{count}</p>;
}
