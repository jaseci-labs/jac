"""Implementation of the Jac client devtools overlay runtime."""

impl _jacColors -> dict {
    return {
        "orange": "#F97316",
        "orangeDark": "#EA580C",
        "panel": "#171717",
        "header": "#0f0f0f",
        "white": "#f5f5f5",
        "muted": "#a3a3a3",
        "border": "#2a2a2a",
        "black": "#0a0a0a"
    };
}

impl mountDevtools -> None {
    # Idempotent: never mount twice (e.g. across HMR re-runs of the entry script).
    if window.__jacDevtoolsMounted {
        return;
    }
    window.__jacDevtoolsMounted = True;

    # Start capturing walker/function network calls as early as possible.
    _installNetworkCapture();

    host = document.createElement("div");
    host.id = "__jac_devtools_host";
    document.body.appendChild(host);

    # Shadow DOM: full style isolation from the host app in both directions.
    shadow = host.attachShadow({"mode": "open"});
    container = document.createElement("div");
    shadow.appendChild(container);

    reactRoot = ReactDOM.createRoot(container);
    reactRoot.render(React.createElement(DevtoolsOverlay, None));
}

impl DevtoolsOverlay -> JsxElement {
    (isOpen, setIsOpen) = reactUseState(False);
    c = _jacColors();

    toggleButton = <button
        onClick={lambda { setIsOpen(not isOpen); }}
        title="Jac devtools"
        style={{
            position: "fixed",
            bottom: 16,
            right: 16,
            padding: "7px 12px",
            borderRadius: 6,
            border: "none",
            background: (c["orangeDark"] if isOpen else c["orange"]),
            color: c["black"],
            fontSize: 11,
            fontWeight: "bold",
            letterSpacing: "0.08em",
            fontFamily: "system-ui, -apple-system, sans-serif",
            cursor: "pointer",
            zIndex: 2147483647,
            boxShadow: "0 2px 8px rgba(0,0,0,0.35)"
        }}
    >
        {"DEBUG"}
    </button>;

    if not isOpen {
        return toggleButton;
    }

    return React.createElement(
        React.Fragment,
        None,
        toggleButton,
        React.createElement(
            DevtoolsPanelShell, {"onClose": lambda { setIsOpen(False); }}
        )
    );
}

impl DevtoolsPanelShell(props: dict) -> JsxElement {
    onClose = props.onClose;
    c = _jacColors();
    (activeTab, setActiveTab) = reactUseState("network");
    (minimized, setMinimized) = reactUseState(False);
    (left, setLeft) = reactUseState(window.innerWidth - 384);
    (top, setTop) = reactUseState(Math.max(16, window.innerHeight - 468));
    (dragging, setDragging) = reactUseState(False);
    dragRef = reactUseRef({"dx": 0, "dy": 0});
    posRef = reactUseRef({"left": 0, "top": 0});

    # Load any persisted position once on mount.
    reactUseEffect(
        lambda {
            sl = window.localStorage.getItem("__jac_devtools_left");
            st = window.localStorage.getItem("__jac_devtools_top");
            if sl and st {
                setLeft(parseFloat(sl));
                setTop(parseFloat(st));
            }
            return lambda { };
        },
        []
    );

    # Window-level drag listeners are attached only while a drag is in progress.
    reactUseEffect(
        lambda {
            if not dragging {
                return lambda { };
            }
            onMove = lambda e: any {
                nl = Math.min(
                    Math.max(0, e.clientX - dragRef.current.dx), window.innerWidth - 120
                );
                nt = Math.min(
                    Math.max(0, e.clientY - dragRef.current.dy), window.innerHeight - 40
                );
                posRef.current = {"left": nl, "top": nt};
                setLeft(nl);
                setTop(nt);
            };
            onUp = lambda e: any {
                setDragging(False);
                window.localStorage.setItem(
                    "__jac_devtools_left", f"{posRef.current.left}"
                );
                window.localStorage.setItem(
                    "__jac_devtools_top", f"{posRef.current.top}"
                );
            };
            window.addEventListener("mousemove", onMove);
            window.addEventListener("mouseup", onUp);
            return lambda {
                window.removeEventListener("mousemove", onMove);
                window.removeEventListener("mouseup", onUp);
            };
        },
        [dragging]
    );

    onHeaderMouseDown = lambda e: any {
        dragRef.current = {"dx": e.clientX - left, "dy": e.clientY - top};
        posRef.current = {"left": left, "top": top};
        setDragging(True);
        e.preventDefault();
    };

    # Panel registry: add future panels here (id, label, component).
    panels = [
        {"id": "network", "label": "Network", "render": NetworkPanel},
        {"id": "env", "label": "Environment", "render": EnvPanel}
    ];

    headerBtnStyle = {
        background: "none",
        border: "none",
        color: c["muted"],
        cursor: "pointer",
        fontSize: 15,
        padding: "0 4px"
    };
    header = <div
        onMouseDown={onHeaderMouseDown}
        style={{
            padding: "8px 12px",
            background: c["header"],
            borderBottom: "1px solid " + c["border"],
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            cursor: "move",
            userSelect: "none"
        }}
    >
        <span
            style={{
                fontWeight: "bold",
                fontSize: 13,
                letterSpacing: "0.08em",
                color: c["orange"]
            }}
        >
            {"DEBUG"}
        </span>
        <span style={{display: "flex", gap: 2}}>
            <button
                onClick={lambda { setMinimized(not minimized); }}
                title="Minimize"
                style={headerBtnStyle}
            >
                {("▸" if minimized else "▾")}
            </button>
            <button
                onClick={lambda { onClose(); }}
                title="Close"
                style={headerBtnStyle}
            >
                {"×"}
            </button>
        </span>
    </div>;

    shellStyle = {
        position: "fixed",
        left: left,
        top: top,
        width: 360,
        maxHeight: "70vh",
        background: c["panel"],
        color: c["white"],
        fontFamily: "system-ui, -apple-system, sans-serif",
        fontSize: 13,
        borderRadius: 10,
        border: "1px solid " + c["border"],
        boxShadow: "0 10px 28px rgba(0,0,0,0.5)",
        zIndex: 2147483647,
        overflow: "hidden",
        display: "flex",
        flexDirection: "column"
    };

    if minimized {
        return
            <div style={shellStyle}>{header}</div>;
    }

    tabBar = <div
        style={{
            display: "flex",
            borderBottom: "1px solid " + c["border"],
            background: c["header"]
        }}
    >
        {[
            <button
                key={p["id"]}
                onClick={lambda { setActiveTab(p["id"]); }}
                style={{
                    background: "none",
                    border: "none",
                    borderBottom: (
                        "2px solid " + c["orange"]
                            if p["id"] == activeTab
                            else "2px solid transparent"
                    ),
                    color: (c["orange"] if p["id"] == activeTab else c["muted"]),
                    cursor: "pointer",
                    fontSize: 12,
                    padding: "8px 12px"
                }}
            >
                {p["label"]}
            </button> for p in panels
        ]}
    </div>;

    activeRender = EnvPanel;
    for p in panels {
        if p["id"] == activeTab {
            activeRender = p["render"];
        }
    }

    return
        <div style={shellStyle}>
            {header}
            {tabBar}
            <div style={{padding: 12, overflow: "auto", flex: 1, minHeight: 0}}>
                {React.createElement(activeRender, None)}
            </div>
        </div>;
}

impl EnvPanel -> JsxElement {
    c = _jacColors();
    initData = {};
    initEl = document.getElementById("__jac_init__");
    if initEl {
        initData = JSON.parse(initEl.textContent);
    }
    rows = [
        {"k": "Route", "v": window.location.pathname},
        {"k": "Module", "v": (initData.module if initData.module else "-")},
        {"k": "Entry", "v": (initData.function if initData.function else "-")},
        {"k": "Viewport", "v": f"{window.innerWidth} × {window.innerHeight}"},
        {"k": "Online", "v": ("yes" if navigator.onLine else "no")},
        {"k": "React", "v": React.version},
        {"k": "User agent", "v": navigator.userAgent}
    ];
    return
        <div style={{display: "flex", flexDirection: "column", gap: 6}}>
            {[
                <div
                    key={r["k"]}
                    style={{
                        display: "flex",
                        justifyContent: "space-between",
                        gap: 12,
                        fontSize: 12,
                        lineHeight: 1.4
                    }}
                >
                    <span style={{color: c["muted"], flexShrink: 0}}>{r["k"]}</span>
                    <span
                        style={{
                            color: c["white"],
                            textAlign: "right",
                            wordBreak: "break-all"
                        }}
                    >
                        {r["v"]}
                    </span>
                </div> for r in rows
            ]}
        </div>;
}

impl _installNetworkCapture -> None {
    if window.__jacDevtoolsFetchPatched {
        return;
    }
    window.__jacDevtoolsFetchPatched = True;
    window.__jacDevtoolsNetwork = [];
    window.__jacDevtoolsSeq = 0;
    window.__jacOrigFetch = window.fetch.bind(window);
    window.fetch = _jacDevtoolsFetch;
    # Runtime hook for cache hits (calls that never reach fetch).
    window.__jacDevtoolsOnCall = _jacDevtoolsOnCall;
}

impl _jacDevtoolsOnCall(info: dict) -> None {
    key = info["endpoint_key"];
    name = key;
    parts = key.split(":");
    if parts.length >= 2 {
        name = parts.slice(1).join(":");
    }
    _recordNetworkEntry(
        {
            "method": "CACHE",
            "name": name,
            "url": key,
            "status": "cache",
            "ok": True,
            "duration": 0,
            "reports": None,
            "cached": True
        }
    );
}

impl _jacCallName(url: str) -> str {
    clean = url.split("?")[0];
    if clean.includes("/walker/") {
        return clean.split("/walker/")[1];
    }
    if clean.includes("/function/") {
        return clean.split("/function/")[1];
    }
    return clean;
}

impl _dispatchNetworkUpdate -> None {
    window.dispatchEvent(Reflect.construct(CustomEvent, ["jac:devtools:network"]));
}

impl _recordNetworkEntry(rec: dict) -> None {
    buf = window.__jacDevtoolsNetwork;
    if not buf {
        buf = [];
        window.__jacDevtoolsNetwork = buf;
    }
    window.__jacDevtoolsSeq = (window.__jacDevtoolsSeq or 0) + 1;
    rec["id"] = window.__jacDevtoolsSeq;
    rec["ts"] = Date.now();
    buf.push(rec);
    # Cap the buffer so a long session cannot grow unbounded.
    if buf.length > 100 {
        buf.shift();
    }
    _dispatchNetworkUpdate();
}

impl _jacDevtoolsFetch(input: any, opts: any = None) -> any {
    orig = window.__jacOrigFetch;
    url = input;
    if input and input.url {
        url = input.url;
    }
    url = String(url);
    if not (url.includes("/walker/") or url.includes("/function/")) {
        # Not a Jac call: pass straight through, untouched and unrecorded.
        return orig(input, opts);
    }
    method = "GET";
    if opts and opts.method {
        method = opts.method;
    }
    rec = {
        "method": method,
        "name": _jacCallName(url),
        "url": url,
        "status": 0,
        "ok": False,
        "duration": 0,
        "reports": None
    };
    start = performance.now();
    promise = orig(input, opts);
    promise.then(
        lambda resp: any {
            rec["status"] = resp.status;
            rec["ok"] = resp.ok;
            rec["duration"] = Math.round(performance.now() - start);
            _recordNetworkEntry(rec);
            # Best-effort: fill in the report count from a clone (never blocks the app).
            resp.clone().json().then(
                lambda data: any {
                    payload = data.data if (data and data.data) else None;
                    if payload {
                        if payload.reports {
                            rec["reports"] = payload.reports.length;
                        }
                        # byllm calls the server attached to this request (dev only).
                        if payload.llm_calls {
                            rec["llm_calls"] = payload.llm_calls;
                        }
                        _dispatchNetworkUpdate();
                    }
                }
            ).catch(
                lambda err: any { }
            );
        }
    ).catch(
        lambda err: any {
            rec["status"] = "ERR";
            rec["ok"] = False;
            rec["error"] = String(err);
            rec["duration"] = Math.round(performance.now() - start);
            _recordNetworkEntry(rec);
        }
    );
    # Return the ORIGINAL promise unchanged: pure pass-through.
    return promise;
}

impl NetworkPanel -> JsxElement {
    c = _jacColors();
    (entries, setEntries) = reactUseState([]);
    (expanded, setExpanded) = reactUseState(None);

    reactUseEffect(
        lambda {
            refresh = lambda {
                src = window.__jacDevtoolsNetwork;
                setEntries((src if src else []).slice());
            };
            refresh();
            window.addEventListener("jac:devtools:network", refresh);
            return lambda { window.removeEventListener(
                "jac:devtools:network", refresh
            ); };
        },
        []
    );

    if entries.length == 0 {
        return
            <div style={{color: c["muted"], fontSize: 12, lineHeight: 1.5}}>
                {"No walker or function calls captured yet. Interact with the app to see requests here."}
            </div>;
    }

    ordered = entries.slice().reverse();

    return
        <div style={{display: "flex", flexDirection: "column", gap: 6}}>
            <button
                onClick={lambda {
                    window.__jacDevtoolsNetwork = [];
                    _dispatchNetworkUpdate();
                }}
                style={{
                    alignSelf: "flex-start",
                    background: "none",
                    border: "1px solid " + c["border"],
                    color: c["muted"],
                    borderRadius: 4,
                    fontSize: 11,
                    padding: "2px 8px",
                    cursor: "pointer"
                }}
            >
                {"Clear"}
            </button>
            {[
                <div
                    key={e["id"]}
                    onClick={lambda { setExpanded(
                        None if expanded == e["id"] else e["id"]
                    ); }}
                    style={{
                        border: "1px solid " + c["border"],
                        borderRadius: 6,
                        padding: "6px 8px",
                        cursor: "pointer"
                    }}
                >
                    <div
                        style={{
                            display: "flex",
                            justifyContent: "space-between",
                            gap: 8,
                            alignItems: "center",
                            fontSize: 12
                        }}
                    >
                        <span
                            style={{
                                color: (c["muted"] if e["cached"] else c["orange"]),
                                fontWeight: "bold"
                            }}
                        >
                            {e["method"]}
                        </span>
                        <span
                            style={{
                                color: c["white"],
                                flex: 1,
                                overflow: "hidden",
                                textOverflow: "ellipsis",
                                whiteSpace: "nowrap"
                            }}
                        >
                            {e["name"]}
                        </span>
                        {(
                            <span
                                style={{
                                    color: c["orange"],
                                    fontSize: 11,
                                    whiteSpace: "nowrap"
                                }}
                            >
                                {f"LLM {e['llm_calls'].length}"}
                            </span>
                        )
                            if e["llm_calls"]
                            else None}
                        <span style={{color: (c["muted"] if e["ok"] else "#ef4444")}}>
                            {e["status"]}
                        </span>
                        <span style={{color: c["muted"]}}>{f"{e['duration']}ms"}</span>
                    </div>
                    {(
                        <div
                            style={{
                                marginTop: 6,
                                color: c["muted"],
                                fontSize: 11,
                                wordBreak: "break-all"
                            }}
                        >
                            <div>{f"URL: {e['url']}"}</div>
                            {(<div>{f"Reports: {e['reports']}"}</div>)
                                if e["reports"] != None
                                else None}
                            {(
                                <div style={{color: "#ef4444"}}>
                                    {f"Error: {e['error']}"}
                                </div>
                            )
                                if e["error"]
                                else None}
                            {(
                                <div style={{marginTop: 8}}>
                                    <div
                                        style={{
                                            color: c["orange"],
                                            fontWeight: "bold",
                                            marginBottom: 4
                                        }}
                                    >
                                        {"LLM calls"}
                                    </div>
                                    {[
                                        <div
                                            key={f"{call['caller']}-{call[
                                                'latency_ms'
                                            ]}"}
                                            style={{
                                                marginBottom: 6,
                                                paddingLeft: 6,
                                                borderLeft: "2px solid " + c["orange"]
                                            }}
                                        >
                                            <div style={{color: c["white"]}}>
                                                {f"{call['caller']} · {call['model']} · {call[
                                                    'latency_ms'
                                                ]}ms · {call['status']}"}
                                            </div>
                                            <div
                                                style={{
                                                    color: c["muted"],
                                                    marginTop: 2
                                                }}
                                            >
                                                {f"prompt: {call['prompt']}"}
                                            </div>
                                            <div
                                                style={{
                                                    color: c["muted"],
                                                    marginTop: 2
                                                }}
                                            >
                                                {f"response: {call['response']}"}
                                            </div>
                                        </div> for call in e["llm_calls"]
                                    ]}
                                </div>
                            )
                                if e["llm_calls"]
                                else None}
                        </div>
                    )
                        if expanded == e["id"]
                        else None}
                </div> for e in ordered
            ]}
        </div>;
}
