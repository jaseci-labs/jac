"""Branch 4 control-flow lifting fixture.

Exercises the idiomatic, provably-pure JSX control-flow shapes the producer
lifts to neutral `EachChild`/`IfChild`:

- a keyed list comprehension (`<For>` on Solid / `.map()` on the JS family),
- a filtered keyed comprehension (`coll.filter(...)` folded into `each=`),
- a view-shaped ternary with both arms (`<Show when fallback>` / `?:`),
- a view-shaped ternary with a `None` alternate (`<Show when>` / `?:`).
"""

cl def:pub item_list(items: list) -> JsxElement {
    return <ul>
        {[<li key={x.id}>{x.title}</li> for x in items]}
    </ul>;
}

cl def:pub filtered_list(items: list) -> JsxElement {
    return <ul>
        {[<li key={x.id}>{x.title}</li> for x in items if x.active]}
    </ul>;
}

cl def:pub toggle_view(flag: bool, a: str, b: str) -> JsxElement {
    return <div>
        {<span>{a}</span> if flag else <p>{b}</p>}
    </div>;
}

cl def:pub maybe_view(flag: bool, a: str) -> JsxElement {
    return <div>
        {<span>{a}</span> if flag else None}
    </div>;
}
