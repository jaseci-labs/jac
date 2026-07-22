"""Notes app UI for the CEF desktop target.

A small but real notes app that doubles as the CEF desktop smoke test. It
exercises jac-desktop infrastructure end-to-end:
  - window.__JAC_DESKTOP__ / window.__JAC_BROKER__ bootstrap injection
  - loopback broker routes at /__jac/* (health + session)
  - localStorage on a stable loopback origin (notes persist across restarts)

The bootstrap/broker diagnostics live behind a collapsible "Diagnostics"
drawer in the footer so they keep working as a smoke probe without dominating
the UI.
"""
def:pub app -> JsxElement {
    has notes: list = [],
        activeId: str = "",
        query: str = "",
        diagnosticsOpen: bool = False,
        desktopFlag: any = None,
        brokerPrefix: str = "",
        origin: str = "",
        health: any = None,
        session: any = None,
        brokerError: str = "",
        tick: int = 0;

    # ---- persistence -------------------------------------------------
    STORAGE_KEY = "notes_app_notes_v2";

    def loadNotes -> any {
        raw = localStorage.getItem(STORAGE_KEY);
        if not raw {
            return [];
        }
        try {
            return JSON.parse(raw);
        } except Exception { }
        return [];
    }

    def persist {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(notes));
    }

    # ---- note operations --------------------------------------------
    def newNote {
        id = "n_" + str(Date.now()) + "_" + str(tick);
        note = {
            "id": id,
            "title": "Untitled note",
            "body": "",
            "updatedAt": Date.now()
        };
        notes = [note] + notes;
        activeId = id;
        persist();
    }

    def selectNote(id: str) {
        activeId = id;
    }

    def deleteNote(id: str) {
        notes = [
            n
            for n in notes
            if n["id"] != id
        ];
        if activeId == id {
            activeId = notes[0]["id"] if len(notes) > 0 else "";
        }
        persist();
    }

    def patchActive(title: str, body: str) {
        if activeId == "" {
            return;
        }
        now = Date.now();
        rebuilt = [];
        for n in notes {
            if n["id"] == activeId {
                rebuilt.append(
                    {"id": n["id"], "title": title, "body": body, "updatedAt": now}
                );
            } else {
                rebuilt.append(n);
            }
        }
        notes = rebuilt;
        persist();
    }

    # ---- derived helpers --------------------------------------------
    def activeNote -> any {
        if activeId == "" {
            return None;
        }
        for n in notes {
            if n["id"] == activeId {
                return n;
            }
        }
        return None;
    }

    def filteredNotes -> list {
        q = query.strip().lower();
        if q == "" {
            return notes;
        }
        return [
            n
            for n in notes
            if q in str(n["title"]).lower() or q in str(n["body"]).lower()
        ];
    }

    def preview(body: str) -> str {
        flat = str(body).replace("\n", " ").strip();
        if len(flat) > 70 {
            return flat[:70] + "...";
        }
        return flat;
    }

    def relTime(ts: any) -> str {
        try {
            ms = int(ts);
        } except Exception {
            return "";
        }
        diff = Date.now() - ms;
        s = int(diff / 1000);
        if s < 60 {
            return "just now";
        }
        m = int(s / 60);
        if m < 60 {
            return str(m) + "m ago";
        }
        h = int(m / 60);
        if h < 24 {
            return str(h) + "h ago";
        }
        d = int(h / 24);
        if d < 7 {
            return str(d) + "d ago";
        }
        return Date(ms).toLocaleDateString();
    }

    def wordCount(body: str) -> int {
        t = str(body).strip();
        if t == "" {
            return 0;
        }
        return len(t.split());
    }

    # ---- broker probe (kept for the CEF smoke test) -----------------
    async def refreshBroker {
        prefix = window.__JAC_BROKER__ or "/__jac";
        brokerPrefix = str(prefix);
        try {
            healthRes = await fetch(brokerPrefix + "/health");
            health = await healthRes.json();
            sessionRes = await fetch(brokerPrefix + "/session");
            session = await sessionRes.json();
            brokerError = "";
        } except e {
            brokerError = "broker probe failed: " + str(e);
        }
        tick = tick + 1;
    }

    # ---- mount -------------------------------------------------------
    can with entry {
        desktopFlag = window.__JAC_DESKTOP__;
        origin = window.location.origin;
        notes = loadNotes();
        if len(notes) == 0 {
            newNote();
        } else {
            activeId = notes[0]["id"];
        }
        refreshBroker();
    }

    # ---- style tokens -----------------------------------------------
    accent = "#f97316";
    sidebarBg = "#1f1d1b";
    sidebarItem = "#2a2724";
    sidebarItemActive = "#33302c";
    muted = "#a8a29e";
    mutedDark = "#78716c";
    border = "#e7e5e4";

    # ---- render ------------------------------------------------------
    cur = activeNote();
    items = filteredNotes();

    return (
        <div
            style={{
                "display": "flex",
                "flexDirection": "column",
                "height": "100vh",
                "margin": "0",
                "fontFamily": "system-ui, -apple-system, sans-serif",
                "color": "#1c1917",
                "background": "#faf9f7"
            }}
        >
            <div style={{"display": "flex", "flex": "1", "minHeight": "0"}}>
                # ---------- sidebar ----------
                <aside
                    style={{
                        "width": "300px",
                        "flexShrink": "0",
                        "background": sidebarBg,
                        "color": "#e7e5e4",
                        "display": "flex",
                        "flexDirection": "column",
                        "borderRight": "1px solid #3f3a36"
                    }}
                >
                    <div
                        style={{
                            "padding": "1.25rem 1rem 0.9rem",
                            "display": "flex",
                            "alignItems": "center",
                            "justifyContent": "space-between"
                        }}
                    >
                        <div
                            style={{
                                "display": "flex",
                                "alignItems": "center",
                                "gap": "0.5rem"
                            }}
                        >
                            <div
                                style={{
                                    "width": "22px",
                                    "height": "22px",
                                    "borderRadius": "6px",
                                    "background": accent,
                                    "display": "flex",
                                    "alignItems": "center",
                                    "justifyContent": "center",
                                    "color": "#fff",
                                    "fontWeight": "700",
                                    "fontSize": "13px"
                                }}
                            >
                                N
                            </div>
                            <span style={{"fontWeight": "600", "fontSize": "15px"}}>
                                Notes
                            </span>
                        </div>
                        <button
                            onClick={lambda (e: any) { newNote(); }}
                            style={{
                                "background": accent,
                                "color": "#fff",
                                "border": "none",
                                "borderRadius": "7px",
                                "padding": "0.4rem 0.7rem",
                                "fontSize": "12px",
                                "fontWeight": "600",
                                "cursor": "pointer"
                            }}
                        >
                            + New
                        </button>
                    </div>
                    <div style={{"padding": "0 0.75rem 0.75rem"}}>
                        <input
                            value={query}
                            placeholder="Search notes..."
                            onChange={lambda (e: any) { query = e.target.value; }}
                            style={{
                                "width": "100%",
                                "boxSizing": "border-box",
                                "background": "#2a2724",
                                "border": "1px solid #3f3a36",
                                "borderRadius": "7px",
                                "color": "#e7e5e4",
                                "padding": "0.5rem 0.7rem",
                                "fontSize": "13px",
                                "outline": "none"
                            }}
                        />
                    </div>
                    <div
                        style={{
                            "flex": "1",
                            "overflowY": "auto",
                            "padding": "0.25rem 0.5rem 0.75rem"
                        }}
                    >
                        {[
                            <button
                                key={n["id"]}
                                onClick={lambda (e: any) { selectNote(n["id"]); }}
                                style={{
                                    "display": "block",
                                    "width": "100%",
                                    "textAlign": "left",
                                    "background": (
                                        sidebarItemActive
                                            if n["id"] == activeId
                                            else "transparent"
                                    ),
                                    "border": "none",
                                    "borderLeft": (
                                        "3px solid " + accent
                                            if n["id"] == activeId
                                            else "3px solid transparent"
                                    ),
                                    "borderRadius": "6px",
                                    "padding": "0.6rem 0.7rem",
                                    "marginBottom": "0.2rem",
                                    "cursor": "pointer",
                                    "color": "#e7e5e4"
                                }}
                            >
                                <div
                                    style={{
                                        "fontSize": "13px",
                                        "fontWeight": "600",
                                        "whiteSpace": "nowrap",
                                        "overflow": "hidden",
                                        "textOverflow": "ellipsis"
                                    }}
                                >
                                    {n["title"]}
                                </div>
                                <div
                                    style={{
                                        "fontSize": "11px",
                                        "color": muted,
                                        "marginTop": "0.15rem",
                                        "whiteSpace": "nowrap",
                                        "overflow": "hidden",
                                        "textOverflow": "ellipsis"
                                    }}
                                >
                                    {preview(n["body"])}
                                </div>
                                <div
                                    style={{
                                        "fontSize": "10px",
                                        "color": mutedDark,
                                        "marginTop": "0.2rem"
                                    }}
                                >
                                    {relTime(n["updatedAt"])}
                                </div>
                            </button> for n in items
                        ]}{(
                            <div
                                style={{
                                    "padding": "1.5rem 0.75rem",
                                    "textAlign": "center",
                                    "color": muted,
                                    "fontSize": "12px"
                                }}
                            >
                                {(
                                    "No notes match your search."
                                        if query != ""
                                        else "No notes yet. Click \"+ New\" to start."
                                )}
                            </div>
                                if len(items) == 0
                                else None
                        )}
                    </div>
                    <div
                        style={{
                            "padding": "0.6rem 0.9rem",
                            "borderTop": "1px solid #3f3a36",
                            "fontSize": "11px",
                            "color": mutedDark
                        }}
                    >
                        {str(len(notes)) + " note" + ("s" if len(notes) != 1 else "") + "  ·  saved locally"}
                    </div>
                </aside>
                # ---------- editor ----------
                <main
                    style={{
                        "flex": "1",
                        "display": "flex",
                        "flexDirection": "column",
                        "minWidth": "0",
                        "background": "#ffffff"
                    }}
                >
                    {(
                        <div
                            key="editor"
                            style={{
                                "flex": "1",
                                "display": "flex",
                                "flexDirection": "column",
                                "minHeight": "0"
                            }}
                        >
                            <div
                                style={{
                                    "padding": "1.5rem 2rem 0.75rem",
                                    "borderBottom": "1px solid " + border
                                }}
                            >
                                <input
                                    value={cur["title"]}
                                    onChange={lambda (e: any) { patchActive(
                                        e.target.value, cur["body"]
                                    ); }}
                                    placeholder="Note title"
                                    style={{
                                        "width": "100%",
                                        "boxSizing": "border-box",
                                        "border": "none",
                                        "outline": "none",
                                        "fontSize": "22px",
                                        "fontWeight": "700",
                                        "color": "#1c1917",
                                        "padding": "0",
                                        "background": "transparent"
                                    }}
                                />
                                <div
                                    style={{
                                        "display": "flex",
                                        "justifyContent": "space-between",
                                        "alignItems": "center",
                                        "marginTop": "0.5rem",
                                        "fontSize": "12px",
                                        "color": "#78716c"
                                    }}
                                >
                                    <span>{"Edited " + relTime(cur["updatedAt"])}</span>
                                    <span>
                                        {str(wordCount(cur["body"])) + " words  ·  " + str(
                                            len(str(cur["body"]))
                                        ) + " chars"}
                                    </span>
                                </div>
                            </div>
                            <div
                                style={{
                                    "flex": "1",
                                    "minHeight": "0",
                                    "padding": "1.25rem 2rem",
                                    "overflow": "hidden"
                                }}
                            >
                                <textarea
                                    value={cur["body"]}
                                    onChange={lambda (e: any) { patchActive(
                                        cur["title"], e.target.value
                                    ); }}
                                    placeholder="Start writing..."
                                    style={{
                                        "width": "100%",
                                        "height": "100%",
                                        "boxSizing": "border-box",
                                        "border": "none",
                                        "outline": "none",
                                        "resize": "none",
                                        "fontSize": "15px",
                                        "lineHeight": "1.6",
                                        "color": "#292524",
                                        "fontFamily": "inherit",
                                        "background": "transparent"
                                    }}
                                />
                            </div>
                            <div
                                style={{
                                    "padding": "0.75rem 2rem",
                                    "borderTop": "1px solid " + border,
                                    "display": "flex",
                                    "justifyContent": "flex-end"
                                }}
                            >
                                <button
                                    onClick={lambda (e: any) { deleteNote(cur["id"]); }}
                                    style={{
                                        "background": "transparent",
                                        "color": "#b91c1c",
                                        "border": "1px solid #fecaca",
                                        "borderRadius": "7px",
                                        "padding": "0.4rem 0.85rem",
                                        "fontSize": "12px",
                                        "fontWeight": "600",
                                        "cursor": "pointer"
                                    }}
                                >
                                    Delete note
                                </button>
                            </div>
                        </div>
                            if cur is not None
                            else (
                                <div
                                    key="empty"
                                    style={{
                                        "flex": "1",
                                        "display": "flex",
                                        "alignItems": "center",
                                        "justifyContent": "center",
                                        "color": "#a8a29e",
                                        "fontSize": "14px"
                                    }}
                                >
                                    {(
                                        "Select a note on the left, or create a new one."
                                            if len(notes) > 0
                                            else "Click \"+ New\" to create your first note."
                                    )}
                                </div>
                            )
                    )}
                </main>
            </div>
            # ---------- diagnostics drawer (CEF smoke probe) ----------
            <footer style={{"borderTop": "1px solid " + border, "background": "#fff"}}>
                <button
                    onClick={lambda (e: any) { diagnosticsOpen = not diagnosticsOpen; }}
                    style={{
                        "width": "100%",
                        "boxSizing": "border-box",
                        "padding": "0.6rem 1.25rem",
                        "background": "transparent",
                        "border": "none",
                        "cursor": "pointer",
                        "display": "flex",
                        "justifyContent": "space-between",
                        "alignItems": "center",
                        "fontSize": "12px",
                        "color": "#78716c"
                    }}
                >
                    <span>{"Diagnostics  ·  CEF desktop probe"}</span>
                    <span>{("▾" if not diagnosticsOpen else "▴")}</span>
                </button>
                {(
                    <div
                        key="diag"
                        style={{
                            "padding": "0.75rem 1.25rem 1rem",
                            "display": "grid",
                            "gridTemplateColumns": "1fr 1fr",
                            "gap": "1rem",
                            "fontSize": "12px"
                        }}
                    >
                        <div>
                            <div
                                style={{
                                    "fontWeight": "600",
                                    "marginBottom": "0.4rem",
                                    "color": "#44403c"
                                }}
                            >
                                Bootstrap
                            </div>
                            <pre
                                style={{
                                    "background": "#f5f5f4",
                                    "padding": "0.6rem",
                                    "borderRadius": "6px",
                                    "margin": "0",
                                    "overflow": "auto",
                                    "maxHeight": "180px"
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
                        </div>
                        <div>
                            <div
                                style={{
                                    "display": "flex",
                                    "alignItems": "center",
                                    "justifyContent": "space-between",
                                    "marginBottom": "0.4rem"
                                }}
                            >
                                <span style={{"fontWeight": "600", "color": "#44403c"}}>
                                    Broker /__jac/*
                                </span>
                                <button
                                    onClick={lambda (e: any) { refreshBroker(); }}
                                    style={{
                                        "background": "#f5f5f4",
                                        "border": "1px solid #e7e5e4",
                                        "borderRadius": "5px",
                                        "padding": "0.2rem 0.5rem",
                                        "fontSize": "11px",
                                        "cursor": "pointer",
                                        "color": "#44403c"
                                    }}
                                >
                                    Refresh
                                </button>
                            </div>
                            <pre
                                style={{
                                    "background": "#f5f5f4",
                                    "padding": "0.6rem",
                                    "borderRadius": "6px",
                                    "margin": "0",
                                    "overflow": "auto",
                                    "maxHeight": "180px"
                                }}
                            >
                                {JSON.stringify(
                                    {
                                        "health": health,
                                        "session": session,
                                        "error": brokerError
                                    },
                                    None,
                                    2
                                )}
                            </pre>
                        </div>
                    </div>
                        if diagnosticsOpen
                        else None
                )}
            </footer>
        </div>
    );
}
