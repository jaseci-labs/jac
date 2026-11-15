"""Client-context consumer inside the `web` app bridging to `social`.

`Badge`, `Relay`, `relay` and the entry's aliases `Emblem`, `RelayAlias` and
`relay_alias` are declared in `social_ops` and only re-imported by the `social`
entry, and `Beacon` arrives through its `include`; they bridge exactly like the
entry's own `greet`, always to the declared name.
"""

import from ..social_app {
    greet,
    greet as hello,
    Badge,
    Beacon,
    Emblem as Medal,
    Relay,
    RelayAlias,
    relay,
    relay_alias
}

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
        badge = Badge(label=label);
        await (root spawn RelayAlias(name=badge.label));
        medal = Medal(label=label);
        await (root spawn Beacon());
        label = medal.label;
    }

    <div>{label}</div>
}
