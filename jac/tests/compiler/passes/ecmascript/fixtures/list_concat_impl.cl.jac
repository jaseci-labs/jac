"""Fixture: list concatenation in .impl.jac must compile to array spread.

Regression test for the bug where `tasks = tasks + [task]` in impl files
compiles to JS string concatenation `M + [J]` instead of `[...M, J]`
(or `[...M, ...J]`).
"""

sv import from list_concat_impl_server { add_item }

def:pub app -> JsxElement {
    has items: list = [];

    async def addItem -> None;

    return <div>{[<span key={i.name}>{i.name}</span> for i in items]}</div>;
}
