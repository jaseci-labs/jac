"""Regression fixture for direct calls to props-destructured JSX components.

Multi-param JSX components lower to a single `props` object plus a destructure
preamble. Direct call sites must therefore repackage positional / keyword args
into that props object, while single-`props` components must *not* be rewrapped.
"""

cl {
    def:pub Greeting(name: str, title: str = "!") -> JsxElement {
        return <div>{name}{title}{props.children}</div>;
    }

    def:pub SingleKeyStyle(payload: dict) -> JsxElement {
        return <div>{payload["label"]}</div>;
    }

    def:pub PropsPassthrough(props: dict) -> JsxElement {
        return <div>{props["label"]}</div>;
    }

    def plain(name: str, title: str = "!") -> str {
        return name + title;
    }

    def:pub direct_pos -> any {
        return Greeting("World");
    }

    def:pub direct_kw -> any {
        return Greeting(title="?", name="World");
    }

    def:pub direct_single_object(payload: dict) -> any {
        return SingleKeyStyle(payload);
    }

    def:pub direct_spread(vals: list) -> any {
        return Greeting(*vals);
    }

    def:pub direct_mixed_spread(vals: list) -> any {
        return Greeting("Hi", *vals);
    }

    def:pub passthrough_bundle(bundle: dict) -> any {
        return PropsPassthrough(bundle);
    }

    def:pub plain_spread(vals: list) -> any {
        return plain(*vals);
    }
}
