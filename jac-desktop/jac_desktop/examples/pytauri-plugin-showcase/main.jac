"""Jac + PyTauri demo: dialog, fs, and notification plugins from npm in client code."""

glob NOTE_NAME: str = "jac-pytauri-showcase-note.txt";

walker:pub ping {
    can run with Root entry {
        report {"ok": True, "service": "jac-sidecar"};
    }
}

import from typing { Any }

cl import from "@tauri-apps/api/path" { appConfigDir, join }
cl import from "@tauri-apps/plugin-dialog" { message, confirm }
cl import from "@tauri-apps/plugin-fs" { readTextFile, writeTextFile }
cl import from "@tauri-apps/plugin-notification" {
    isPermissionGranted,
    requestPermission,
    sendNotification,
}

# Client-side UI
to cl:

def:pub app -> JsxElement {
    has noteText: str = "",
        status: str = "",
        backendInfo: str = "";

    async can with entry {
        try {
            result = root spawn ping();
            if result.reports {
                row = result.reports[0];
                payload: Any = row[0] if row else row;
                backendInfo = str(payload);
            }
        } except Exception as e {
            backendInfo = "(backend unavailable: " + str(e) + ")";
        }
    }

    async def showNativeDialog {
        try {
            await message(
                "This is the Tauri dialog plugin opened from Jac client code.",
                {"title": "dialog plugin", "kind": "info"},
            );
            status = "dialog: ok";
        } except Exception as e {
            status = "dialog failed: " + str(e);
        }
    }

    async def saveNote {
        try {
            base = await appConfigDir();
            path = await join(base, NOTE_NAME);
            await writeTextFile(path, noteText);
            status = "fs: saved under app config dir";
        } except Exception as e {
            status = "fs save failed: " + str(e);
        }
    }

    async def loadNote {
        try {
            base = await appConfigDir();
            path = await join(base, NOTE_NAME);
            raw = await readTextFile(path);
            noteText = str(raw);
            status = "fs: loaded note";
        } except Exception as e {
            status = "fs load failed: " + str(e);
        }
    }

    async def maybeNotify {
        try {
            ok = await isPermissionGranted();
            if not ok {
                perm = await requestPermission();
                ok = perm == "granted";
            }
            if not ok {
                status = "notification: permission denied";
                return;
            }
            sendNotification(
                {
                    "title": "From Jac + Tauri",
                    "body": "notification plugin fired (no app Rust).",

                },
            );
            status = "notification: sent";
        } except Exception as e {
            status = "notification failed: " + str(e);
        }
    }

    async def confirmDemo {
        try {
            ok = await confirm(
                "This confirm dialog also uses the Tauri dialog plugin from Jac.",
                {"title": "confirm", "kind": "info"},
            );
            status = "confirm: yes" if ok else "confirm: no";
        } except Exception as e {
            status = "confirm failed: " + str(e);
        }
    }

    cardStyle = {
        "background": "#ffffff",
        "borderRadius": "12px",
        "padding": "20px",
        "marginBottom": "16px",
        "boxShadow": "0 1px 3px rgba(0,0,0,0.08)",
        "border": "1px solid #e5e7eb",

    };
    btn = {
        "marginRight": "8px",
        "marginBottom": "8px",
        "padding": "8px 14px",
        "borderRadius": "8px",
        "border": "none",
        "cursor": "pointer",
        "fontWeight": "600",
        "background": "#2563eb",
        "color": "#fff",

    };

    return
        <div
            style={{
                "fontFamily": "system-ui, sans-serif",
                "maxWidth": "720px",
                "margin": "0 auto",
                "padding": "24px",
                "background": "#f3f4f6",
                "minHeight": "100vh",

            }}
        >
            <h1 style={{"fontSize": "1.5rem", "marginBottom": "8px"}}>
                PyTauri · three native plugins from Jac
            </h1>
            <p style={{"color": "#4b5563", "marginBottom": "20px"}}>
                <strong>dialog</strong>
                ,
                <strong>fs</strong>
                , and
                {" "}
                <strong>notification</strong>
                are declared in
                {" "}
                <code>jac.toml</code>
                as
                <code>[plugins.desktop] tauri_plugins</code>
                and called here via npm imports (no custom Rust).
            </p>
            <div style={cardStyle}>
                <h2 style={{"marginTop": 0}}>Sidecar</h2>
                <pre
                    style={{
                        "background": "#111827",
                        "color": "#e5e7eb",
                        "padding": "12px",
                        "borderRadius": "8px",
                        "overflow": "auto",

                    }}
                >
                    {backendInfo or "(waiting...)"}
                </pre>
            </div>
            <div style={cardStyle}>
                <h2 style={{"marginTop": 0}}>1. Dialog plugin</h2>
                <button style={btn} onClick={showNativeDialog}>
                    Native message box
                </button>
                <button style={{** btn, "background": "#0d9488"}} onClick={confirmDemo}>
                    Native confirm
                </button>
            </div>
            <div style={cardStyle}>
                <h2 style={{"marginTop": 0}}>2. FS plugin</h2>
                <textarea
                    value={noteText}
                    onChange={lambda e: ChangeEvent { noteText = e.target.value; }}
                    placeholder="Type a note — stored via Tauri fs + appConfigDir/join..."
                    rows={6}
                    style={{
                        "width": "100%",
                        "boxSizing": "border-box",
                        "padding": "10px",
                        "borderRadius": "8px",
                        "border": "1px solid #d1d5db",
                        "marginBottom": "10px",
                        "fontFamily": "inherit",

                    }}
                />
                <button style={btn} onClick={saveNote}>Save note</button>
                <button style={{** btn, "background": "#7c3aed"}} onClick={loadNote}>
                    Load note
                </button>
            </div>
            <div style={cardStyle}>
                <h2 style={{"marginTop": 0}}>3. Notification plugin</h2>
                <button style={{** btn, "background": "#ea580c"}} onClick={maybeNotify}>
                    Send desktop notification
                </button>
            </div>
            <div style={{"color": "#374151"}}>
                <strong>Status:</strong>
                {status or "—"}
            </div>
        </div>;
}
