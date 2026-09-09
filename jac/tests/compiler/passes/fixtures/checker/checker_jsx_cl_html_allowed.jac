"""Fixture: .jac files may use raw HTML host tags even in a mobUI app.

This is a regression fixture for the kind-leak bug: a consumer app with
``kind = "mobile"`` in its ``[apps.<name>]`` table stamped the mobUI
enforcement root on the shared program, so JsxIntrinsicGuardPass fired E1105
on framework .jac files (e.g. client_runtime.jac) compiled into the same
program during jac build. The root is now a per-module fact
(``Module.mobui_enforced_root``) and files outside it are exempt."""

def Widget -> JsxElement {
    return
        <div>
            <span>hello</span>
            <button>click</button>
        </div>;
}
