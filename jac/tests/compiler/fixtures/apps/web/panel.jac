"""Client-context consumer inside the `web` app bridging to `social`.

`Relay`, `relay` and `relay_alias` (the entry's alias of `relay`) are declared in
`social_ops` and only re-imported by the `social` entry; they bridge exactly like
the entry's own `greet`, always to the declared name.
"""

import from ..social_app { greet, greet as hello, Relay, relay, relay_alias }

def:pub Panel -> JsxElement {
    has label: str = "";

    async can with entry {
        p = await greet("panel");
        label = p.name;
        other = await hello("alias");
        label = other.name;
        label = await relay(label);
        label = await relay_alias(label);
        await (root spawn Relay(name=label));
    }

    <div>{label}</div>
}
