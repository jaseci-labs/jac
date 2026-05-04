"""Fixture for the cl-component def-site props-bundle diagnostic (W5015).

W5015 fires only on JSX components that take a single parameter named `props`
(the JS-idiomatic React shape). That shape sacrifices per-prop type checking
at JSX call sites because the param_map keys on parameter name — so
`<JsPropsStyle title=\"...\" />` would E1101 against any single-`props`
signature. The Jac-idiomatic forms (multi-param, or a single non-`props`
named bundle) preserve per-prop validation and must not warn.
"""

cl {
    # JS-idiomatic shape: single param literally named `props`. SHOULD warn —
    # this is the only definition shape that bypasses per-prop validation.
    def:pub JsPropsStyle(props: dict) -> JsxElement {
        return <div>{props.foo}{props.bar}</div>;
    }

    # Jac-idiomatic shape: multiple direct params auto-destructured. Each prop
    # is type-checked at JSX call sites. No warning.
    def:pub DirectStyle(foo: str, bar: str) -> JsxElement {
        return <div>{foo}{bar}</div>;
    }

    # Single-key destructure with a non-`props` name. The call site
    # `<SingleKeyStyle payload={...} />` validates `payload` against its
    # declared type, so this is a typed bundle, not the props-bundle shape.
    # No warning.
    def:pub SingleKeyStyle(payload: dict) -> JsxElement {
        return <div>{payload}</div>;
    }
}
