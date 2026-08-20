"""Markerless client page with `has` state importing a pullable helper."""

import from demote_cache_util { note, ping }

def:pub app -> JsxElement {
    has count: int = 0;

    can with entry {
        note("boot");
        count = count + 1;
    }

    msg = ping("x");
    return <div>{count}{msg}</div>;
}
