"""Shared RN HTML tag map (D10).

Single source of truth for:
  - compile-time lint in ``react_native/build.jac``
  - runtime JSX dispatch in ``client_runtime_native.cl.jac``

Keep tag lists here only. Do not duplicate in build or runtime modules.
"""

glob RN_HTML_VIEW_TAGS = [
         "div",
         "section",
         "main",
         "article",
         "header",
         "footer",
         "nav",
         "aside",
         "ul",
         "ol",
         "li",
         "form"
     ],
     RN_HTML_TEXT_TAGS = [
         "span",
         "p",
         "h1",
         "h2",
         "h3",
         "h4",
         "h5",
         "h6",
         "label",
         "strong",
         "em",
         "small"
     ],
     RN_HTML_SPECIAL_TAGS = ["button", "input", "textarea", "img", "a"];

"""All HTML tags with explicit native renderers (view, text, or special)."""
def supported_rn_html_tags -> frozenset {
    tags: set[str] = set();
    for tag in RN_HTML_VIEW_TAGS {
        tags.add(tag);
    }
    for tag in RN_HTML_TEXT_TAGS {
        tags.add(tag);
    }
    for tag in RN_HTML_SPECIAL_TAGS {
        tags.add(tag);
    }
    return frozenset(tags);
}
