"""Regression fixture for issue #5508.

Two failure modes for the type-driven primitive emitter dispatch:

Case 1: ``in`` operator on a string-returning method call.  The receiver of
``.lower()`` is correctly transpiled to ``.toLowerCase()``, but the
surrounding ``in`` operator was not, because the operator-side dispatch
(``_try_primitive_op``) only matched primitive class names directly and did
not walk the MRO the way the method-side dispatch does.

Case 2: string methods on a value whose static type is not provably ``str``
(props of type ``dict``, results of ``or`` widening, etc.).  The dispatch
gives up and emits the Python method name verbatim, producing JavaScript
that crashes at runtime.
"""

cl {
    def:pub case1_in_chain() -> JsxElement {
        has found: bool = False;
        can with entry {
            name = "alice";
            found = "a" in name.lower();
        }
        return <div>{str(found)}</div>;
    }

    def:pub case2_props_upper(props: dict) -> JsxElement {
        name = props["name"] or "";
        initial = name[:1].upper();
        return <div>{initial}</div>;
    }

    def:pub case2_props_strip(props: dict) -> JsxElement {
        raw = props["title"] or "";
        clean = raw.strip();
        return <div>{clean}</div>;
    }

    def:pub case2_props_lower(props: dict) -> JsxElement {
        raw = props["label"] or "";
        lower = raw.lower();
        return <div>{lower}</div>;
    }
}
