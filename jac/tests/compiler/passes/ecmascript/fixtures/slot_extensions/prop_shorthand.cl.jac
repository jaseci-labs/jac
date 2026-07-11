"""Rec 5 — `{name}` JSX attribute shorthand.

New parser-level attribute production. `<Box {title} {count} {onClick}/>`
should be sugar for the explicit form
`<Box title={title} count={count} onClick={onClick}/>`. No keyword, no
declarator, no semantic change — purely a shorter spelling for the
common "pass a same-named local binding through" pattern.
"""

def:pub Box(title: str, count: int, onClick: any) -> JsxElement {
    return
        <button class="box" onClick={onClick}>
            <span class="title">{title}</span>
            <span class="count">{count}</span>
        </button>;
}

def:pub Page -> JsxElement {
    title = "Hello";
    count = 3;
    onClick = lambda { print("click"); };

    return
        <main>
            <Box {title} {count} {onClick}/>
        </main>;
}
