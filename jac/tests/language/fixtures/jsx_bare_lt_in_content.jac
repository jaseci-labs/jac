"""Test that bare `<` in JSX content is treated as text, not a tag.

A `<` followed by a non-alpha, non-`/`, non-`>` character (e.g. `<--`)
does not start a JSX tag. The lexer should consume it as JSX_TEXT and
the overall program should compile without hanging.
"""

def app -> JsxElement {
    return
        <div>
            <span>
                {"*"}
            </span>
            #  <--
        </div>;
}
