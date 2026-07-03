"""Fixture: .cl.jac files may use raw HTML host tags even in a mobUI project.

This is a regression fixture for the kind-leak bug: a consumer project with
jac.toml ``client_kind = "mobui"`` stamped project_kind on the shared program, so
JsxIntrinsicGuardPass fired E1105 on framework .cl.jac files (e.g.
client_runtime.cl.jac) compiled into the same program during jac build."""

def Widget -> JsxElement {
    return
        <div>
            <span>hello</span>
            <button>click</button>
        </div>;
}
