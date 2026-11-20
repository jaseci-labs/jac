"""Bare (Python) imports used by server-placed code are everyday reality
and must stay silent: only a client-placed value use lacks a binding at
runtime. The component never touches the import."""

import from os { path }

def helper(p: str) -> str {
    return path.basename(p);
}

def:pub app -> JsxElement {
    <div>ok</div>
}
