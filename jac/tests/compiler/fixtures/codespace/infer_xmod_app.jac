"""Markerless client module that plain-imports a pure markerless module.

The accessless helpers must follow the client caller into the browser
bundle (direct calls, ES import); the def:pub stays a server endpoint and
bridges over RPC.
"""
import from infer_xmod_util { register, tag_count, server_ping, Badge }

def:pub app -> JsxElement {
    register("boot");
    n = tag_count();
    msg = server_ping("x");
    badge = Badge(label="boot");
    return <div>{n}{msg}{badge.label}</div>;
}
