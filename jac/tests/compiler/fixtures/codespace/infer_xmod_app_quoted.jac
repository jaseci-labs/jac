"""infer_xmod_app.jac, importing the same module through quoted paths.

A quoted path that names a Jac module is the same import as the dotted one.
"""
import from ".infer_xmod_util" { register, tag_count, server_ping }
import from "./infer_xmod_util.jac" { Badge }

def:pub app -> JsxElement {
    register("boot");
    n = tag_count();
    msg = server_ping("x");
    badge = Badge(label="boot");
    return <div>{n}{msg}{badge.label}</div>;
}
