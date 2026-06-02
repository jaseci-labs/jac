"""Client component that calls cross-module server endpoints via `sv import`.

The `sv import` + `await <fn>()` is the cross-boundary signal Path B keys on.
`CrossView` is imported as a boundary type; `cross_orphan` is intentionally not
referenced here.
"""
sv import from .crossbound_server { cross_pub, cross_priv, CrossView }

cl def:pub Panel() -> JsxElement {
    has msg: str = "";

    async can with entry {
        a = await cross_pub();
        b = await cross_priv();
        msg = a.msg;
    }

    return
        <div id="panel">{msg}</div>;
}
