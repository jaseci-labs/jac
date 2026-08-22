"""Client-side routing + capability-error tests (run under bun via cl test runner).

These lock in the centralized routing decision tree (docs §7) that now lives in
one place in the client runtime:

- __jacRoute picks the channel: native (__jac_invoke) vs web (fetch) for standard
  calls, and sidecar vs a structured capability error for file uploads.
- __jacCapabilityError mirrors the sv-side runtimelib.http_surface.capability_error
  envelope, naming [desktop.http] + the capability.
- jacUploadFile routes a multipart upload to the [desktop.http] sidecar when
  present (with the X-Jac-Sidecar-Token gate + the user Bearer token), and fails
  with the capability error in lean mode.
"""

import from "@jac/runtime" {
    __jacRoute,
    __jacCapabilityError,
    __jacHttpSidecar,
    __jacHttpHasCapability,
    jacUploadFile,
    __setLocalStorage
}


def _clear_env {
    globalThis.__JAC_NATIVE__ = False;
    globalThis.__jac_invoke = undefined;
    globalThis.__JAC_HTTP__ = undefined;
    globalThis.window = {"location": {"reload": lambda { }}};
}

"""Install a mock sidecar descriptor (window.__JAC_HTTP__)."""
def _install_sidecar(caps: list) {
    globalThis.__JAC_HTTP__ = {
        "base": "http://127.0.0.1:9099",
        "token": "sidecar-tok",
        "capabilities": caps
    };
}

"""Mock fetch; returns the list recording each {url, opts}."""
def _install_fetch(response: dict) -> list {
    seen = [];
    globalThis.fetch = lambda (url: any, opts: any) -> any {
        seen.append({"url": url, "opts": opts});
        return Promise.resolve(response);
    };
    return seen;
}


test "route picks native when the native bridge is present, web otherwise" {
    _clear_env();
    # No native host -> web/remote fetch channel.
    assert __jacRoute("walker", False)["channel"] == "http";
    assert __jacRoute("function", False)["channel"] == "http";

    globalThis.__JAC_NATIVE__ = True;
    globalThis.__jac_invoke = lambda (p: any) -> any { return Promise.resolve({}); };
    assert __jacRoute("walker", False)["channel"] == "native";

    _clear_env();
}


test "route picks the sidecar for uploads only when multipart is available" {
    _clear_env();
    # No sidecar -> upload routes to a structured error.
    up = __jacRoute("walker", True);
    assert up["channel"] == "error" and up["capability"] == "multipart";
    assert not __jacHttpSidecar();
    assert __jacHttpHasCapability("multipart") == False;

    # Sidecar present but without multipart -> still an error.
    _install_sidecar(["openapi"]);
    assert __jacHttpHasCapability("multipart") == False;
    assert __jacRoute("walker", True)["channel"] == "error";

    # Sidecar with multipart -> the upload routes to the sidecar.
    _install_sidecar(["multipart"]);
    assert __jacHttpHasCapability("multipart") == True;
    assert __jacRoute("walker", True)["channel"] == "sidecar";
    assert __jacHttpSidecar()["base"] == "http://127.0.0.1:9099";

    _clear_env();
}


test "capability error is a structured 415/501 envelope naming [desktop.http]" {
    multi = __jacCapabilityError("multipart");
    assert multi["ok"] == False;
    assert multi["http_status"] == 415;
    assert multi["error"]["code"] == "CAPABILITY_NOT_AVAILABLE";
    assert multi["error"]["capability"] == "multipart";
    assert multi["error"]["hint"].includes("[desktop.http]");

    hook = __jacCapabilityError("webhooks");
    assert hook["http_status"] == 501;
}


test "jacUploadFile fails with the capability error in lean mode (no sidecar)" {
    _clear_env();
    raised = False;
    msg = "";
    try {
        await jacUploadFile("save_upload", {"label": "x"}, {"file": "data"});
    } except Exception as e {
        raised = True;
        msg = String(e);
    }
    assert raised == True;
    assert msg.includes("[desktop.http]") and msg.includes("multipart");

    _clear_env();
}


test "jacUploadFile posts multipart to the sidecar with both tokens" {
    _clear_env();
    _install_sidecar(["multipart"]);
    __setLocalStorage("jac_token", "user-tok");
    seen = _install_fetch(
        {
            "ok": True,
            "status": 200,
            "json": lambda -> any { return Promise.resolve({"data": {"size": 4}}); }
        }
    );

    out = await jacUploadFile(
        "save_upload", {"label": "avatar"}, {"file": "blob"}, "n-3"
    );
    assert out["size"] == 4 , "unwrapped data should be returned";
    assert len(seen) == 1;
    call = seen[0];
    # Node-scoped upload -> /walker/{name}/{nodeId} on the sidecar base.
    assert call["url"] == "http://127.0.0.1:9099/walker/save_upload/n-3";
    opts = call["opts"];
    assert opts["method"] == "POST";
    headers = opts["headers"];
    # Sidecar gate token + user identity token both ride the request.
    assert headers["X-Jac-Sidecar-Token"] == "sidecar-tok";
    assert headers["Authorization"] == "Bearer user-tok";
    # The body is a FormData (multipart), not a JSON string.
    assert opts["body"] is not None;

    _clear_env();
}
