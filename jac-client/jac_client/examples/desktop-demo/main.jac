cl {
    def:pub app -> JsxElement {
        has count: int = 0,
            msg: str = "Ready";

        def do_notify {
            window.__jac.invoke(
                "jac.notification", "send", {"title": "Test", "body": "Hello!"}
            ).then(
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
