"""Markerless pull-policy fixture: an access-tagged glob is visibility-only
(still pulled client by reference), a one-sided obj referenced only by client
code relocates wholesale instead of stubbing, and a two-sided node keeps its
auto-share stub with literal has-defaults materialized."""

import from "clsx" { clsx }

glob:pub TOKENS: dict = {bg: "#000"};

obj Panel {
    has width: int = 640,
        tags: list = [];
}

node Task {
    has title: str = "untitled",
        done: bool = False;
}

def:pub add_task(title: str) -> Task {
    t = root ++> Task(title=title);
    return t[0];
}

def:pub app -> JsxElement {
    has tasks: list[Task] = [];

    async can with entry {
        t = await add_task("hi");
        tasks = [t];
    }

    p = Panel(width=800);
    cls = clsx(TOKENS);
    return <div class={cls}>{p.width}{for t in tasks { <p>{t.title}</p> }}</div>;
}
