import from react { useEffect }

glob _SCRIPT: list[dict] = [
         {"k": "cmd", "t": "jac create trailmate --use jac-shadcn"},
         {"k": "out", "t": "  Themed starter ready (nova / orange / geist)"},
         {"k": "cmd", "t": "jac scale deploy"},
         {"k": "ok", "t": "✔ REST API · auth · Swagger · graph persistence"},
         {"k": "ok", "t": "✔ React client compiled from Jac"},
         {"k": "ok", "t": "✔ Kubernetes: images built, cluster provisioned"},
         {"k": "out", "t": "  Serving on http://localhost:8000  —  0 lines of YAML"},

     ];

def:pub TerminalDemo(className: str = "") -> JsxElement {
    has shown: list[dict] = [];

    useEffect(
        lambda {
            si = 0;
            ci = 0;
            pause = 18;
            done: list[dict] = [];
            interval = setInterval(
                lambda {
                    if pause > 0 {
                        pause = pause - 1;
                        return None;
                    }
                    if si >= len(_SCRIPT) {
                        pause = 200;
                        si = 0;
                        ci = 0;
                        done = [];
                        return None;
                    }
                    st = _SCRIPT[si];
                    kind = st["k"] as str;
                    full = st["t"] as str;
                    if kind == "cmd" {
                        if ci < len(full) {
                            ci = ci + 2;
                            if ci > len(full) {
                                ci = len(full);
                            }
                            cur = "";
                            j = 0;
                            while j < ci {
                                cur = cur + full[j];
                                j = j + 1;
                            }
                            shown = done + [{"k": "cmd", "t": cur, "live": True}];
                        } else {
                            done = done + [{"k": "cmd", "t": full, "live": False}];
                            shown = done;
                            si = si + 1;
                            ci = 0;
                            pause = 14;
                        }
                    } else {
                        done = done + [st];
                        shown = done;
                        si = si + 1;
                        pause = 7;
                    }
                    return None;
                },
                28
            );
            return lambda { clearInterval(interval); };
        },
        []
    );

    return
        <div
            className={"code-window rounded-xl overflow-hidden text-left " + className}
        >
            <div
                className="code-titlebar flex items-center gap-2 pl-4 pr-4 pt-2.5 pb-2.5"
            >
                <span className="size-2.5 rounded-full bg-white/15"></span>
                <span className="size-2.5 rounded-full bg-white/15"></span>
                <span className="size-2.5 rounded-full bg-white/15"></span>
                <span className="ml-2 font-mono text-xs text-white/45">
                    ~/trailmate
                </span>
            </div>
            <div
                className="min-h-[13.5rem] pt-4 pb-5 pl-5 pr-5 font-mono text-[13px] leading-relaxed"
            >
                {for (i, ln) in enumerate(shown) {
                    <div key={str(i)} className="min-h-[1.5em] whitespace-pre-wrap">
                        {if ln["k"] == "cmd" {
                            <span className="sh-prompt select-none">{"$ "}</span>
                            <span className="sh-cmd">{ln["t"]}</span>
                            if ln["live"] {
                                <span className="caret ml-1"></span>
                            }
                        } elif ln["k"] == "ok" {
                            <span className="sh-ok">{ln["t"]}</span>
                        } else {
                            <span className="sh-out">{ln["t"]}</span>
                        }  }
                    </div>
                }}
                {if len(shown) == 0 {
                    <div>
                        <span className="sh-prompt">{"$ "}</span>
                        <span className="caret"></span>
                    </div>
                }}
            </div>
        </div>;
}
