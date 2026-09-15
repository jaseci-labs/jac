"""Client-context consumer inside the `web` app bridging to `social`."""

import from ..social_app { greet, greet as hello }

def:pub Panel -> JsxElement {
    has label: str = "";

    async can with entry {
        p = await greet("panel");
        label = p.name;
        other = await hello("alias");
        label = other.name;
    }

    <div>{label}</div>
}
