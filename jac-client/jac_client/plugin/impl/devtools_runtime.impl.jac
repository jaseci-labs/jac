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

    toggleButton =
        <button
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
    (activeTab, setActiveTab) = reactUseState("env");
    (minimized, setMinimized) = reactUseState(False);
    (left, setLeft) = reactUseState(window.innerWidth - 384);
    (top, setTop) = reactUseState(Math.max(16, window.innerHeight - 468));
    (dragging, setDragging) = reactUseState(False);
    dragRef = reactUseRef({"dx": 0, "dy": 0});
    posRef = reactUseRef({"left": 0, "top": 0});

    # Load any persisted position once on mount.
    reactUseEffect(lambda {
        sl = window.localStorage.getItem("__jac_devtools_left");
        st = window.localStorage.getItem("__jac_devtools_top");
        if sl and st {
            setLeft(parseFloat(sl));
            setTop(parseFloat(st));
        }
        return lambda {  };
    }, []);

    # Window-level drag listeners are attached only while a drag is in progress.
    reactUseEffect(lambda {
        if not dragging {
            return lambda {  };
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
            window.localStorage.setItem("__jac_devtools_top", f"{posRef.current.top}");
        };
        window.addEventListener("mousemove", onMove);
        window.addEventListener("mouseup", onUp);
        return lambda {
            window.removeEventListener("mousemove", onMove);
            window.removeEventListener("mouseup", onUp);
        };
    }, [dragging]);

    onHeaderMouseDown = lambda e: any {
        dragRef.current = {"dx": e.clientX - left, "dy": e.clientY - top};
        posRef.current = {"left": left, "top": top};
        setDragging(True);
        e.preventDefault();
    };

    # Panel registry: add future panels here (id, label, component).
    panels = [{"id": "env", "label": "Environment", "render": EnvPanel}];

    headerBtnStyle = {
        background: "none",
        border: "none",
        color: c["muted"],
        cursor: "pointer",
        fontSize: 15,
        padding: "0 4px"
    };
    header =
        <div
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
                <button onClick={lambda { onClose(); }} title="Close" style={headerBtnStyle}>
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
        return <div style={shellStyle}>{header}</div>;
    }

    tabBar =
        <div
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
                </button>
                for p in panels
            ]}
        </div>;

    activeRender = EnvPanel;
    for p in panels {
        if p["id"] == activeTab {
            activeRender = p["render"];
        }
    }

    return <div style={shellStyle}>
        {header}
        {tabBar}
        <div style={{padding: 12, overflow: "auto"}}>
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
    return <div style={{display: "flex", flexDirection: "column", gap: 6}}>
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
                <span style={{color: c["white"], textAlign: "right", wordBreak: "break-all"}}>
                    {r["v"]}
                </span>
            </div>
            for r in rows
        ]}
    </div>;
}
