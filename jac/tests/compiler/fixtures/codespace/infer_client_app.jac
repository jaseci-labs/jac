"""Markerless client module: placement inferred from JSX and npm imports.

No `cl` marker anywhere - the string-path import and JSX are the seeds, and
the helper def plus the mutable glob are pulled client through symbol
references.
"""

import from "clsx" { clsx }

glob click_count: int = 0;

def css_helper -> str {
    return clsx(["a", "b"]);
}

def:pub app -> JsxElement {
    click_count += 1;
    return <div>{css_helper()}{click_count}</div>;
}
