"""Fixture: client state handed to a child through JSX attribute shorthand.

`<Panel {flag}/>` parses one Name node into both halves of the attribute, its
name and its value. The value half is a state read like any other and has to
lower through the state cell; emitting it as a bare `flag` ships a module that
throws ReferenceError the moment the component renders. Found by the
free-identifier audit in the littleX example, same failure as #8224 from the
read side.
"""

def:pub Panel(flag: bool) -> JsxElement {
    return <div>{flag}</div>;
}

def:pub app -> JsxElement {
    has flag: bool = False;
    return <Panel {flag}/>;
}
