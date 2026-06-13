"""CEF desktop-cef smoke test UI.

Exercises jac-desktop infrastructure:
  - window.__JAC_DESKTOP__ / window.__JAC_BROKER__ bootstrap injection
  - loopback broker routes at /__jac/*
  - localStorage on a stable loopback origin
"""
cl {
    def:pub app -> JsxElement {
        has desktopFlag: any = None,
            brokerPrefix: str = "",
            origin: str = "",
            health: any = None,
            session: any = None,
            lsNote: str = "",
            error: str = "",
            tick: int = 0;

        async def refreshBroker {
            prefix = window.__JAC_BROKER__ or "/__jac";
            brokerPrefix = str(prefix);
            try {
                healthRes = await fetch(brokerPrefix + "/health");
                health = await healthRes.json();
                sessionRes = await fetch(brokerPrefix + "/session");
                session = await sessionRes.json();
                error = "";
            } except e {
                error = "broker probe failed: " + str(e);
            }
            tick = tick + 1;
        }

        can with tick entry {
            if tick == 0 {
                desktopFlag = window.__JAC_DESKTOP__;
                origin = window.location.origin;
                lsNote = localStorage.getItem("cef_smoke_note") or "";
                refreshBroker();
            }
        }

        return (
            <div
                style={{
                    fontFamily: "system-ui, sans-serif",
                    padding: "1.5rem",
                    maxWidth: "760px"
                }}
            >
                <h1>CEF desktop-cef smoke test</h1>
                <p style={{color: "#555"}}>
                    Built with{" "}
                    <code>jac build --client desktop-cef</code>
                </p>
                <section style={{marginTop: "1rem"}}>
                    <h2>Bootstrap</h2>
                    <pre
                        style={{
                            background: "#f4f4f4",
                            padding: "0.75rem",
                            borderRadius: "8px"
                        }}
                    >
                        {JSON.stringify(
                            {
                                "__JAC_DESKTOP__": desktopFlag,
                                "__JAC_BROKER__": brokerPrefix,
                                "origin": origin
                            },
                            None,
                            2
                        )}
                    </pre>
                </section>
                <section style={{marginTop: "1rem"}}>
                    <h2>Broker</h2>
                    <button onClick={lambda e: any { refreshBroker(); }}>
                        Refresh /__jac/*
                    </button>
                    <pre
                        style={{
                            background: "#f4f4f4",
                            padding: "0.75rem",
                            borderRadius: "8px"
                        }}
                    >
                        {JSON.stringify(
                            {"health": health, "session": session, "error": error},
                            None,
                            2
                        )}
                    </pre>
                </section>
                <section style={{marginTop: "1rem"}}>
                    <h2>localStorage (stable origin)</h2>
                    <input
                        value={lsNote}
                        placeholder="note to persist across restarts"
                        onChange={lambda e: any { lsNote = e.target.value; }}
                        style={{
                            width: "100%",
                            padding: "0.5rem",
                            marginBottom: "0.5rem"
                        }}
                    />
                    <button
                        onClick={lambda e: any { localStorage.setItem(
                            "cef_smoke_note", lsNote
                        ); }}
                    >
                        Save note
                    </button>
                </section>
            </div>
        );
    }
}
