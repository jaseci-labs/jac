"""`unsafe_html` ambient builtin for raw-HTML insertion.

`unsafe_html(x)` returns a marker that the client runtime recognises and
renders as raw HTML via `dangerouslySetInnerHTML`. The escape default for
plain `{expr}` children is unchanged -- only `unsafe_html(...)` opts into
the raw path. The name carries its own security review hint at the use
site.
"""

obj Comment {
    has author: str,
        body_html: str;
}

"""Renders an HTML-formatted comment body verbatim."""
def:pub CommentCard(c: Comment) -> JsxElement {
    return
        <article class="comment">
            <h3>{c.author}</h3>
            <div class="body">{unsafe_html(c.body_html)}</div>
        </article>;
}

"""Mixes raw HTML with safe text and JSX in one element."""
def:pub MixedRender(safe: str, raw: str) -> JsxElement {
    return
        <section>
            <p>{safe}</p>
            <div class="trusted">{unsafe_html(raw)}</div>
            <footer>end</footer>
        </section>;
}
