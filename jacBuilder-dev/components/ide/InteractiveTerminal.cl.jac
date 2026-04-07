"""Interactive terminal component using xterm.js.
Connects to the terminal_stream WebSocket walker for a real PTY shell."""

import from react { useRef, useEffect, useState, useCallback }
import from "...services.ideService" { sendTermRequest, closeTermWs }
import from "...lib.utils" { cn }
import from "@xterm/xterm" { Terminal as XTerminal }
import from "@xterm/addon-fit" { FitAddon }

glob _NL: str = String.fromCharCode(10);

"""Interactive PTY terminal backed by xterm.js."""
def:pub InteractiveTerminal(props: Any) -> Any {
    userId = props.userId or "";
    projectId = props.projectId or "";
    isVisible = props.isVisible;

    has termReady: bool = False;
    has termStatus: str = "idle";

    termRef = useRef(None);
    xtermRef = useRef(None);
    fitAddonRef = useRef(None);
    pollTimerRef = useRef(None);
    isPollingRef = useRef(False);
    mountedRef = useRef(True);

    def stopPolling() -> None {
        isPollingRef.current = False;
        if pollTimerRef.current {
            clearTimeout(pollTimerRef.current);
            pollTimerRef.current = None;
        }
    }

    idleCountRef = useRef(0);

    def pollOutput() -> None {
        if not isPollingRef.current or not mountedRef.current { return; }
        if not userId or not projectId { return; }

        sendTermRequest("output", userId, projectId, "", 80, 24, lambda(resp: Any) -> None {
            if not mountedRef.current or not isPollingRef.current { return; }
            hasData = False;
            if resp and resp.data and resp.data.success and resp.data.chunks and resp.data.chunks.length > 0 {
                hasData = True;
                xt = xtermRef.current;
                if xt {
                    for chunk in resp.data.chunks {
                        try {
                            decoded = atob(chunk);
                            xt.write(decoded);
                        } except Exception {
                            ;
                        }
                    }
                }
            }
            if isPollingRef.current and mountedRef.current {
                if hasData {
                    idleCountRef.current = 0;
                    pollTimerRef.current = setTimeout(pollOutput, 50);
                } else {
                    idleCountRef.current = (idleCountRef.current or 0) + 1;
                    delay = 50;
                    if idleCountRef.current > 5 { delay = 200; }
                    if idleCountRef.current > 20 { delay = 500; }
                    if idleCountRef.current > 50 { delay = 1000; }
                    pollTimerRef.current = setTimeout(pollOutput, delay);
                }
            }
        });
    }

    def startPolling() -> None {
        if isPollingRef.current { return; }
        isPollingRef.current = True;
        pollOutput();
    }

    def startTerminal() -> None {
        if not userId or not projectId { return; }
        termStatus = "starting";
        sendTermRequest("start", userId, projectId, "", 80, 24, lambda(resp: Any) -> None {
            if not mountedRef.current { return; }
            if resp and resp.data and resp.data.success {
                termStatus = "running";
                startPolling();
                # Send initial resize based on actual terminal size
                xtInst = xtermRef.current;
                if xtInst {
                    sendTermRequest("resize", userId, projectId, "", xtInst.cols, xtInst.rows, lambda(_: Any) -> None { ; });
                }
            } else {
                termStatus = "error";
                xtErr = xtermRef.current;
                errMsg = "Failed to start terminal";
                if resp and resp.data and resp.data.error {
                    errMsg = resp.data.error;
                }
                if xtErr {
                    xtErr.writeln(errMsg);
                }
            }
        });
    }

    # Initialize xterm.js on mount
    useEffect(lambda -> Any {
        mountedRef.current = True;

        if not termRef.current { return lambda { mountedRef.current = False; }; }

        xTermInstance = Reflect.construct(XTerminal, [{
            "cursorBlink": True,
            "fontSize": 13,
            "fontFamily": "'JetBrains Mono', 'Fira Code', 'Cascadia Code', Menlo, Monaco, 'Courier New', monospace",
            "lineHeight": 1.2,
            "scrollback": 5000,
            "theme": {
                "background": "#09090b",
                "foreground": "#fafafa",
                "cursor": "#f97316",
                "selectionBackground": "#f9731640",
                "black": "#09090b",
                "red": "#ef4444",
                "green": "#22c55e",
                "yellow": "#f97316",
                "blue": "#3b82f6",
                "magenta": "#a855f7",
                "cyan": "#06b6d4",
                "white": "#fafafa",
                "brightBlack": "#71717a",
                "brightRed": "#f87171",
                "brightGreen": "#4ade80",
                "brightYellow": "#fb923c",
                "brightBlue": "#60a5fa",
                "brightMagenta": "#c084fc",
                "brightCyan": "#22d3ee",
                "brightWhite": "#ffffff"
            }
        }]);

        fit = Reflect.construct(FitAddon, []);
        xTermInstance.loadAddon(fit);
        xTermInstance.open(termRef.current);
        fit.fit();

        xtermRef.current = xTermInstance;
        fitAddonRef.current = fit;
        termReady = True;

        # Send keystrokes to backend
        pId = projectId;
        uId = userId;
        xTermInstance.onData(lambda(data: Any) -> None {
            if not pId or not uId { return; }
            idleCountRef.current = 0;
            sendTermRequest("input", uId, pId, data, 80, 24, lambda(_: Any) -> None { ; });
        });

        # Handle terminal resize
        xTermInstance.onResize(lambda(size: Any) -> None {
            if not pId or not uId { return; }
            sendTermRequest("resize", uId, pId, "", size.cols, size.rows, lambda(_: Any) -> None { ; });
        });

        # Fit on container resize
        observer = Reflect.construct(ResizeObserver, [lambda(_: Any) -> None {
            if fitAddonRef.current {
                try { fitAddonRef.current.fit(); } except Exception { ; }
            }
        }]);
        observer.observe(termRef.current);

        return lambda {
            mountedRef.current = False;
            stopPolling();
            observer.disconnect();
            xTermInstance.dispose();
            xtermRef.current = None;
            fitAddonRef.current = None;
        };
    }, []);

    # Start terminal when projectId changes
    prevProjectRef = useRef("");

    useEffect(lambda -> Any {
        if not projectId or not userId or not termReady { return; }

        # Stop old terminal for previous project
        oldPid = prevProjectRef.current;
        if oldPid and oldPid != projectId {
            sendTermRequest("stop", userId, oldPid, "", 80, 24, lambda(_: Any) -> None { ; });
        }
        prevProjectRef.current = projectId;

        # Clear terminal display on project switch
        xtClear = xtermRef.current;
        if xtClear {
            xtClear.clear();
        }

        startTerminal();

        return lambda {
            stopPolling();
            # Kill terminal PTY when unmounting or switching projects
            if projectId {
                sendTermRequest("stop", userId, projectId, "", 80, 24, lambda(_: Any) -> None { ; });
            }
        };
    }, [projectId, userId, termReady]);

    # Stop polling when hidden, resume when visible
    useEffect(lambda {
        if isVisible {
            if fitAddonRef.current {
                setTimeout(lambda { fitAddonRef.current.fit(); }, 50);
            }
            if termStatus == "running" and not isPollingRef.current {
                idleCountRef.current = 0;
                startPolling();
            }
        } else {
            stopPolling();
        }
        }
    , [isVisible]);

    return <div className={cn("flex flex-col h-full bg-[#09090b] overflow-hidden", ("hidden" if not isVisible else ""))}>
        <div
            ref={termRef}
            className="flex-1 min-h-0"
            style={{"padding": "4px 8px"}}
        />
    </div>;
}
