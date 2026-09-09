"""Client-context consumer inside the `web` app bridging to `social`."""

import from ..social_app { greet }

def:pub Panel -> JsxElement {
    has label: str = "";

    async can with entry {
        p = await greet("panel");
        label = p.name;
    }

    <div>{label}</div>
}
