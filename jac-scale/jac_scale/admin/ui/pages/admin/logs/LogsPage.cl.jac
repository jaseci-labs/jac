"""Pod logs page for the admin dashboard (A-05a).

Replaces the Jac-walker logs page that used to live here (compiled
artifacts under .jac/client/compiled still reference the old shape;
source had been removed before M-14 work). This rewrite targets
**Loki pod logs** via the new /admin/logs/* endpoints, scoped to the
deployed app_name namespace.

UX choices that distinguish this from raw Grafana:
- Service color coding via a stable name->hash->Tailwind palette
- Level badge (DEBUG/INFO/WARN/ERROR), not regex on text
- Click a trace_id chip -> trace explorer view shows every line for
  that request across all services in causal order
- Pre-scoped to the deployed namespace; never the all-cluster firehose
- Service dropdown auto-populated from microservices.routes config
"""

import from "lucide-react" { ScrollText, RefreshCw, AlertTriangle, X }

import from react { useEffect }
import from ....components.common.Button { Button }
import from ....components.common.Input { Input }
import from ....components.common.Select { Select }
import from ....context.AuthContext { useAuth }
import from ....services.logsService { getLogServices, getLogs, getTraceLogs }

def:pub LogsPage -> JsxElement {
    has isLoading: bool = True,
        isLoadingMore: bool = False,
        lines: list = [],
        services: list = [],
        filterService: str = "",
        filterLevel: str = "",
        filterSearch: str = "",
        filterSince: str = "15m",
        limit: int = 200,
        # Cursor for the next "load older" page. Empty when no
        # more pages are available (server returns `null` once a
        # short page comes back).
        nextBefore: str = "",
        autoRefresh: bool = False,
        errorMsg: str = "",
        backendOffline: bool = False,
        # Side panel state. panelIdx = -1 means the drawer is closed.
        # When a row is clicked we copy the line dict into panelLine
        # for the header section, and if the line has a trace_id we
        # kick off loadTrace() to populate the journey list below.
        panelIdx: int = -1,
        panelLine: dict = {},
        traceId: str = "",
        traceLines: list = [],
        traceServices: list = [],
        traceLoading: bool = False;

    auth = useAuth();

    async def loadServices {
        try {
            result = await getLogServices(auth["authToken"]);
            if result["ok"] and result["data"] {
                services = result["data"]["services"] or [];
            }
        } except Exception as e {
            console.error("loadServices error:", e);
        }
    }

    async def loadLogs {
        isLoading = True;
        backendOffline = False;
        nextBefore = "";
        try {
            result = await getLogs(
                auth["authToken"],
                filterService,
                filterLevel,
                filterSearch,
                "",
                filterSince,
                limit,
                ""
            );
            if result["ok"] and result["data"] {
                lines = result["data"]["lines"] or [];
                nextBefore = String(result["data"]["next_before"] or "");
                errorMsg = "";
            } elif result["error"] {
                errorMsg = result["error"]["message"] or "Failed to load logs";
                # 502 = Loki unreachable. Distinguish so we can show a
                # helpful hint about logs.enabled / observability stack.
                if "unavailable" in (errorMsg or "").toLowerCase() {
                    backendOffline = True;
                }
            }
        } except Exception as e {
            console.error("loadLogs error:", e);
            errorMsg = "Error loading logs: " + String(e);
        }
        isLoading = False;
    }

    async def loadMore {
        if not nextBefore or isLoadingMore {
            return;
        }
        isLoadingMore = True;
        try {
            result = await getLogs(
                auth["authToken"],
                filterService,
                filterLevel,
                filterSearch,
                "",
                filterSince,
                limit,
                nextBefore
            );
            if result["ok"] and result["data"] {
                older = result["data"]["lines"] or [];
                # Append: newer page is already at the top, older
                # entries land beneath - the display stays
                # newest-first end-to-end.
                lines = lines.concat(older);
                nextBefore = String(result["data"]["next_before"] or "");
            }
        } except Exception as e {
            console.error("loadMore error:", e);
        }
        isLoadingMore = False;
    }

    async def loadTrace(tid: str) {
        traceId = tid;
        traceLoading = True;
        traceLines = [];
        traceServices = [];
        try {
            result = await getTraceLogs(auth["authToken"], tid);
            if result["ok"] and result["data"] {
                traceLines = result["data"]["lines"] or [];
                traceServices = result["data"]["services_touched"] or [];
            } elif result["error"] {
                errorMsg = result["error"]["message"] or "Failed to load trace";
            }
        } except Exception as e {
            console.error("loadTrace error:", e);
        }
        traceLoading = False;
    }

    def openPanel(idx: int, line: dict) {
        panelIdx = idx;
        panelLine = line;
        tid = String(line["trace_id"] or "");
        if tid {
            loadTrace(tid);
        } else {
            traceId = "";
            traceLines = [];
            traceServices = [];
            traceLoading = False;
        }
    }

    def closePanel {
        panelIdx = -1;
        panelLine = {};
        traceId = "";
        traceLines = [];
        traceServices = [];
    }

    useEffect(
        lambda {
            loadServices();
            loadLogs();
        },
        []
    );

    # Auto-apply dropdown filters. Debounced 250ms so dragging through
    # the <select> options doesn't fire a request per option. Search
    # is intentionally excluded - it stays Enter-to-submit to avoid
    # hammering Loki on every keystroke.
    useEffect(
        lambda -> any {
            timer = setTimeout(lambda { loadLogs(); }, 250);
            return lambda { clearTimeout(timer); };
        },
        [filterService, filterLevel, filterSince]
    );

    useEffect(
        lambda -> any {
            if not autoRefresh {
                return undefined;
            }
            interval = setInterval(lambda { loadLogs(); }, 10000);
            return lambda { clearInterval(interval); };
        },
        [autoRefresh]
    );

    # ---- helpers -----------------------------------------------------
    # Stable hash-based color for a service name. Same name always
    # gets the same Tailwind text class so users build muscle memory.
    def serviceColor(name: str) -> str {
        if not name {
            return "text-muted";
        }
        palette = [
            "text-sky-400",
            "text-emerald-400",
            "text-amber-400",
            "text-purple-400",
            "text-pink-400",
            "text-cyan-400",
            "text-accent",
            "text-lime-400",
            "text-rose-400",
            "text-indigo-400"
        ];
        hash: int = 0;
        i: int = 0;
        while i < len(name) {
            hash = ((hash << 5) - hash + name.charCodeAt(i)) | 0;
            i += 1;
        }
        return palette[Math.abs(hash) % len(palette)];
    }

    def levelBadge(level: str) -> str {
        base = "px-1.5 py-0.5 rounded text-[10px] font-semibold border border-line ";
        lvl = (level or "INFO").toUpperCase();
        if lvl == "ERROR" or lvl == "CRITICAL" {
            return base + "bg-danger-weak text-danger";
        }
        if lvl == "WARNING" or lvl == "WARN" {
            return base + "bg-warning-weak text-warning";
        }
        if lvl == "DEBUG" {
            return base + "bg-surface-2 text-faint";
        }
        return base + "bg-surface-2 text-muted";
    }

    def shortTime(ts: str) -> str {
        if not ts {
            return "";
        }
        d = Reflect.construct(Date, [ts]);
        if isNaN(d.getTime()) {
            return ts.slice(11, 19);
        }
        hh = String(d.getHours()).padStart(2, "0");
        mm = String(d.getMinutes()).padStart(2, "0");
        ss = String(d.getSeconds()).padStart(2, "0");
        ms = String(d.getMilliseconds()).padStart(3, "0");
        return hh + ":" + mm + ":" + ss + "." + ms;
    }

    def shortTrace(t: str) -> str {
        if not t {
            return "";
        }
        s = String(t);
        return s.slice(0, 8);
    }

    # ---- render: main logs view ------------------------------------
    return
        <div className="space-y-4">
            <div className="flex items-center gap-2.5">
                <ScrollText className="w-5 h-5 text-accent"/>
                <h1 className="text-lg font-semibold text-fg">Logs</h1>
            </div>
            <div className="flex items-end gap-3 flex-wrap">
                <div>
                    <div className="text-xs text-faint mb-1">Service</div>
                    <select
                        className="bg-bg border border-line rounded-lg px-3 py-1.5 text-fg text-sm focus:outline-none focus:border-accent-line transition-colors"
                        value={filterService}
                        onChange={lambda (e: any) { filterService = e.target.value; }}
                    >
                        <option value="">All services</option>
                        {[<option key={s} value={s}>{s}</option> for s in services]}
                    </select>
                </div>
                <div>
                    <div className="text-xs text-faint mb-1">Level</div>
                    <select
                        className="bg-bg border border-line rounded-lg px-3 py-1.5 text-fg text-sm focus:outline-none focus:border-accent-line transition-colors"
                        value={filterLevel}
                        onChange={lambda (e: any) { filterLevel = e.target.value; }}
                    >
                        <option value="">All levels</option>
                        <option value="DEBUG">DEBUG</option>
                        <option value="INFO">INFO</option>
                        <option value="WARNING">WARNING</option>
                        <option value="ERROR">ERROR</option>
                    </select>
                </div>
                <div>
                    <div className="text-xs text-faint mb-1">Time</div>
                    <select
                        className="bg-bg border border-line rounded-lg px-3 py-1.5 text-fg text-sm focus:outline-none focus:border-accent-line transition-colors"
                        value={filterSince}
                        onChange={lambda (e: any) { filterSince = e.target.value; }}
                    >
                        <option value="5m">Last 5 min</option>
                        <option value="15m">Last 15 min</option>
                        <option value="1h">Last 1 hour</option>
                        <option value="6h">Last 6 hours</option>
                        <option value="1d">Last 24 hours</option>
                    </select>
                </div>
                <div className="flex-1 min-w-48">
                    <div className="text-xs text-faint mb-1">Search</div>
                    <input
                        type="text"
                        className="w-full bg-bg border border-line rounded-lg px-3 py-1.5 text-fg text-sm focus:outline-none focus:border-accent-line transition-colors"
                        placeholder="grep text..."
                        value={filterSearch}
                        onChange={lambda (e: any) { filterSearch = e.target.value; }}
                        onKeyDown={lambda (e: any) { if e.key == "Enter" {
                            loadLogs();
                        }}}
                    />
                </div>
                <Button onClick={lambda { loadLogs(); }} variant="secondary">
                    <RefreshCw className="w-3.5 h-3.5"/>
                    Refresh
                </Button>
                <label className="flex items-center gap-2 text-sm text-muted">
                    <input
                        type="checkbox"
                        checked={autoRefresh}
                        onChange={lambda (e: any) { autoRefresh = e.target.checked; }}
                    />
                    Auto-refresh (10s)
                </label>
            </div>
            {backendOffline
            and <div
                className="flex items-start gap-2 bg-warning-weak border border-line rounded-lg p-3 text-sm text-muted"
            >
                <AlertTriangle className="w-4 h-4 text-warning shrink-0 mt-0.5"/>
                <span>
                    Log backend unreachable. Make sure
                    <code className="mx-1 font-mono text-fg">
                        [plugins.scale.microservices.logs].enabled
                    </code>
                    is true and the Loki + Alloy stack is running in the deployment namespace.
                </span>
            </div>}
            {errorMsg
            and not backendOffline
            and <div
                className="flex items-start gap-2 bg-danger-weak border border-line rounded-lg p-3 text-sm text-danger"
            >
                <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5"/>
                <span>{errorMsg}</span>
            </div>}
            {isLoading
            and <div className="flex items-center justify-center h-32">
                <div className="text-accent">Loading logs...</div>
            </div>}
            {not isLoading
            and lines.length == 0
            and not errorMsg
            and <div
                className="bg-surface border border-line rounded-lg p-8 text-faint text-center"
            >
                No logs in the selected window. Try a longer time range or hit your gateway to generate some traffic.
            </div>}
            {not isLoading
            and lines.length > 0
            and <div className="text-xs text-faint">
                {lines.length} log {lines.length == 1 and "line" or "lines"}
            </div>}
            {not isLoading
            and lines.length > 0
            and <div
                className="bg-surface border border-line rounded-lg font-mono text-sm overflow-x-auto max-h-[70vh] overflow-y-auto shadow-sm"
            >
                {lines.map(
                    lambda (line: dict, idx: int) { return
                        <div
                            key={idx}
                            className={"flex items-start gap-3 px-3 py-1.5 border-b border-line hover:bg-surface-2 cursor-pointer transition-colors " + (
                                panelIdx == idx
                                and "bg-accent-weak border-l-2 border-l-accent"
                                or ""
                            )}
                            onClick={lambda { openPanel(idx, line); }}
                        >
                            <span className="text-faint text-xs whitespace-nowrap">
                                {shortTime(line["ts"] or "")}
                            </span>
                            <span
                                className={"text-xs font-bold whitespace-nowrap " + serviceColor(
                                    line["service"] or ""
                                )}
                            >
                                {line["service"] or "?"}
                            </span>
                            <span className={levelBadge(line["level"] or "INFO")}>
                                {(line["level"] or "INFO").toUpperCase()}
                            </span>
                            <span className="text-fg break-all flex-1">
                                {line["msg"] or ""}
                            </span>
                            {line["trace_id"]
                            and <span
                                className="text-xs font-mono text-accent px-1.5 py-0.5 rounded border border-accent-line whitespace-nowrap"
                                title="Click row to view full trace"
                            >
                                trace:{shortTrace(String(line["trace_id"]))}
                            </span>}
                        </div>; }
                )}
            </div>}
            {not isLoading
            and lines.length > 0
            and nextBefore
            and <div className="flex justify-center pt-1">
                <Button
                    onClick={lambda { loadMore(); }}
                    variant="secondary"
                    disabled={isLoadingMore}
                >
                    {isLoadingMore and "Loading older..." or "Load older"}
                </Button>
            </div>}
            {panelIdx >= 0
            and <div
                className="fixed inset-y-0 right-0 w-full sm:w-[480px] md:w-[560px] lg:w-[640px] bg-surface border-l border-line shadow-sm flex flex-col z-50"
            >
                <div
                    className="flex items-center justify-between px-4 py-3 border-b border-line"
                >
                    <div className="flex items-center gap-2">
                        <span
                            className={"text-sm font-bold " + serviceColor(
                                panelLine["service"] or ""
                            )}
                        >
                            {panelLine["service"] or "?"}
                        </span>
                        <span className={levelBadge(panelLine["level"] or "INFO")}>
                            {(panelLine["level"] or "INFO").toUpperCase()}
                        </span>
                        <span className="text-xs text-faint font-mono">
                            {shortTime(panelLine["ts"] or "")}
                        </span>
                    </div>
                    <button
                        className="text-muted hover:text-fg"
                        onClick={lambda { closePanel(); }}
                        title="Close"
                    >
                        <X className="w-4 h-4"/>
                    </button>
                </div>
                <div className="flex-1 overflow-y-auto px-4 py-3 text-xs space-y-3">
                    <div>
                        <div
                            className="text-faint text-[10px] uppercase tracking-wide mb-1"
                        >
                            Message
                        </div>
                        <div
                            className="text-fg font-mono break-all whitespace-pre-wrap bg-surface border border-line rounded p-2"
                        >
                            {panelLine["msg"] or ""}
                        </div>
                    </div>
                    <div className="grid grid-cols-[7rem_1fr] gap-y-1">
                        <div className="text-faint">Timestamp</div>
                        <div className="text-fg font-mono break-all">
                            {panelLine["ts"] or "-"}
                        </div>
                        {panelLine["pod"] and <div className="text-faint">Pod</div>}
                        {panelLine["pod"]
                        and <div className="text-fg font-mono break-all">
                            {panelLine["pod"]}
                        </div>}
                        {panelLine["trace_id"]
                        and <div className="text-faint">Trace ID</div>}
                        {panelLine["trace_id"]
                        and <div className="text-accent font-mono break-all">
                            {panelLine["trace_id"]}
                        </div>}
                    </div>
                    {panelLine["extras"]
                    and <div>
                        <div
                            className="text-faint text-[10px] uppercase tracking-wide mb-1"
                        >
                            Extras
                        </div>
                        <pre
                            className="bg-surface border border-line rounded p-2 text-fg overflow-x-auto"
                        >
                            {JSON.stringify(panelLine["extras"], None, 2)}
                        </pre>
                    </div>}
                    {panelLine["trace_id"]
                    and <div className="pt-2 border-t border-line">
                        <div
                            className="text-faint text-[10px] uppercase tracking-wide mb-2 flex items-center gap-2"
                        >
                            <span>Trace journey</span>
                            {traceServices.length > 0
                            and <span className="text-faint">·</span>}
                            {traceServices.length > 0
                            and [
                                <span
                                    key={s}
                                    className={"font-mono " + serviceColor(s)}
                                >
                                    {s}
                                </span> for s in traceServices
                            ]}
                        </div>
                        {traceLoading
                        and <div className="text-muted text-center py-3">
                            Loading trace lines...
                        </div>}
                        {not traceLoading
                        and traceLines.length == 0
                        and <div className="text-faint text-center py-3">
                            No other log lines found for this trace.
                        </div>}
                        {not traceLoading
                        and traceLines.length > 0
                        and <div
                            className="bg-surface border border-line rounded font-mono overflow-x-auto"
                        >
                            {traceLines.map(
                                lambda (tl: dict, ti: int) { return
                                    <div
                                        key={ti}
                                        className="flex items-start gap-2 px-2 py-1 border-b border-line last:border-b-0"
                                    >
                                        <span
                                            className="text-faint text-[10px] whitespace-nowrap"
                                        >
                                            {shortTime(tl["ts"] or "")}
                                        </span>
                                        <span
                                            className={"text-[10px] font-bold whitespace-nowrap " + serviceColor(
                                                tl["service"] or ""
                                            )}
                                        >
                                            {tl["service"] or "?"}
                                        </span>
                                        <span className="text-fg break-all">
                                            {tl["msg"] or ""}
                                        </span>
                                    </div>; }
                            )}
                        </div>}
                    </div>}
                </div>
            </div>}
        </div>;
}
