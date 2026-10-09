"""Client-context consumer inside the `web` app bridging to `social`.

`Relay` and `relay` are declared in `social_ops` and only re-imported by the
`social` entry; they bridge exactly like the entry's own `greet`.
"""

import from ..social_app { greet, greet as hello, Relay, relay }

def:pub Panel -> JsxElement {
    has label: str = "";

    async can with entry {
        p = await greet("panel");
        label = p.name;
        other = await hello("alias");
        label = other.name;
        label = await relay(label);
        await (root spawn Relay(name=label));
    }

    <div>{label}</div>
}
