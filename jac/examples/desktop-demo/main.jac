# Desktop Plugin Demo — sends a native OS notification through the typed
# @jac/desktop SDK instead of hand-writing window.__jac.invoke() magic strings.
cl import from "@jac/desktop" { notification }

cl {
    def:pub app -> JsxElement {
        has count: int = 0,
            msg: str = "Ready";

        def do_notify {
            # SDK calls take POSITIONAL args (see desktop_api.cl.jac); they
            # return a promise that resolves on success / rejects with an
            # Error carrying the host's `.code`.
            notification.send("Test", "Hello!").then(
                lambda r: any { msg = "Notification sent!"; }
            ).catch(
                lambda e: any { msg = "Error: " + str(e); }
            );
        }

        return
            <div style={{"padding": "24px", "fontFamily": "system-ui"}}>
                <h1>Desktop Plugin Demo</h1>
                <p>{msg}</p>
                <p>Count: {count}</p>
                <button onClick={lambda e: any { count = count + 1; }}>
                    Increment
                </button>
                <button onClick={lambda e: any { do_notify(); }}>
                    Test Notification
                </button>
            </div>;
    }
}
