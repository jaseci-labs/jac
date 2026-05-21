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

cl {
    import from react { useEffect }
    import from ....components.common.Button { Button }
    import from ....components.common.Input { Input }
    import from ....components.common.Select { Select }
    import from ....context.AuthContext { useAuth }
    import from ....services.logsService { getLogServices, getLogs, getTraceLogs }

    def:pub LogsPage -> JsxElement {
        has isLoading: bool = True,
            lines: list = [],
            services: list = [],
            filterService: str = "",
            filterLevel: str = "",
            filterSearch: str = "",
            filterSince: str = "15m",
            limit: int = 200,
            autoRefresh: bool = False,
            errorMsg: str = "",
            backendOffline: bool = False,
            # Trace explorer state - when set, switch to the trace view
            traceMode: bool = False,
            traceId: str = "",
            traceLines: list = [],
            traceServices: list = [],
            traceLoading: bool = False,
            expandedIdx: int = -1;

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
            try {
                result = await getLogs(
                    auth["authToken"],
                    filterService,
                    filterLevel,
                    filterSearch,
                    "",
                    filterSince,
                    limit
                );
                if result["ok"] and result["data"] {
                    lines = result["data"]["lines"] or [];
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

        async def loadTrace(tid: str) {
            traceMode = True;
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

        def closeTrace {
            traceMode = False;
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

        useEffect(
            lambda -> any {
                if not autoRefresh or traceMode {
                    return undefined;
                }
                interval = setInterval(lambda { loadLogs(); }, 10000);
                return lambda { clearInterval(interval); };
            },
            [
                autoRefresh,
                traceMode,
                filterService,
                filterLevel,
                filterSearch,
                filterSince
            ]
        );

        # ---- helpers -----------------------------------------------------
        # Stable hash-based color for a service name. Same name always
        # gets the same Tailwind text class so users build muscle memory.
        def serviceColor(name: str) -> str {
            if not name {
                return "text-slate-400";
            }
            palette = [
                "text-sky-400",
                "text-emerald-400",
                "text-amber-400",
                "text-purple-400",
                "text-pink-400",
                "text-cyan-400",
                "text-orange-400",
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
            base = "px-1.5 py-0.5 rounded text-xs font-bold border ";
            lvl = (level or "INFO").toUpperCase();
            if lvl == "ERROR" or lvl == "CRITICAL" {
                return base + "bg-red-500/20 text-red-300 border-red-500/40";
            }
            if lvl == "WARNING" or lvl == "WARN" {
                return base + "bg-amber-500/20 text-amber-300 border-amber-500/40";
            }
            if lvl == "DEBUG" {
                return base + "bg-slate-700/40 text-slate-400 border-slate-600";
            }
            return base + "bg-sky-500/20 text-sky-300 border-sky-500/40";
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

        # ---- render: trace explorer ------------------------------------
        if traceMode {
            return
                <div className="space-y-4">
                    <div className="flex items-center gap-3">
                        <Button onClick={closeTrace} variant="secondary">
                            ← Back to Logs
                        </Button>
                        <div>
                            <div className="text-xs text-slate-500">Trace</div>
                            <div className="font-mono text-white text-sm">
                                {traceId}
                            </div>
                        </div>
                        {traceServices.length > 0
                        and <div className="ml-auto flex items-center gap-2">
                            <span className="text-xs text-slate-500">touched:</span>
                            {traceServices.map(
                                lambda (s: str) { return
                                    <span
                                        key={s}
                                        className={"text-xs font-mono " + serviceColor(
                                            s
                                        )}
                                    >
                                        {s}
                                    </span>; }
                            )}
                        </div>}
                    </div>
                    {traceLoading
                    and <div className="flex items-center justify-center h-32">
                        <div className="text-sky-400">Loading trace lines...</div>
                    </div>}
                    {not traceLoading
                    and traceLines.length == 0
                    and <div
                        className="bg-slate-900 border border-slate-800 rounded p-6 text-slate-500 text-center"
                    >
                        No log lines found for this trace in the last 24 hours.
                    </div>}
                    {not traceLoading
                    and traceLines.length > 0
                    and <div
                        className="bg-slate-900 border border-slate-800 rounded font-mono text-sm overflow-x-auto"
                    >
                        {traceLines.map(
                            lambda (line: dict, idx: int) { return
                                <div
                                    key={idx}
                                    className="flex items-start gap-3 px-3 py-1.5 border-b border-slate-800/50 hover:bg-slate-800/30"
                                >
                                    <span
                                        className="text-slate-500 text-xs whitespace-nowrap"
                                    >
                                        {shortTime(line["ts"] or "")}
                                    </span>
                                    <span
                                        className={"text-xs font-bold whitespace-nowrap " + serviceColor(
                                            line["service"] or ""
                                        )}
                                    >
                                        {line["service"] or "?"}
                                    </span>
                                    <span
                                        className={levelBadge(line["level"] or "INFO")}
                                    >
                                        {(line["level"] or "INFO").toUpperCase()}
                                    </span>
                                    <span className="text-slate-200 break-all">
                                        {line["msg"] or ""}
                                    </span>
                                </div>; }
                        )}
                    </div>}
                </div>;
        }

        # ---- render: main logs view ------------------------------------
        return
            <div className="space-y-4">
                <div className="flex items-end gap-3 flex-wrap">
                    <div>
                        <div className="text-xs text-slate-500 mb-1">Service</div>
                        <select
                            className="bg-slate-900 border border-slate-700 rounded px-3 py-1.5 text-white text-sm"
                            value={filterService}
                            onChange={lambda (e: any) { filterService = e.target.value; }}
                        >
                            <option value="">All services</option>
                            {services.map(
                                lambda (s: str) { return
                                    <option key={s} value={s}>{s}</option>; }
                            )}
                        </select>
                    </div>
                    <div>
                        <div className="text-xs text-slate-500 mb-1">Level</div>
                        <select
                            className="bg-slate-900 border border-slate-700 rounded px-3 py-1.5 text-white text-sm"
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
                        <div className="text-xs text-slate-500 mb-1">Time</div>
                        <select
                            className="bg-slate-900 border border-slate-700 rounded px-3 py-1.5 text-white text-sm"
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
                        <div className="text-xs text-slate-500 mb-1">Search</div>
                        <input
                            type="text"
                            className="w-full bg-slate-900 border border-slate-700 rounded px-3 py-1.5 text-white text-sm"
                            placeholder="grep text..."
                            value={filterSearch}
                            onChange={lambda (e: any) { filterSearch = e.target.value; }}
                            onKeyDown={lambda (e: any) { if e.key == "Enter" {
                                loadLogs();
                            }}}
                        />
                    </div>
                    <Button onClick={lambda { loadLogs(); }} variant="primary">
                        Refresh
                    </Button>
                    <label className="flex items-center gap-2 text-sm text-slate-400">
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
                    className="bg-amber-500/10 border border-amber-500/40 rounded p-3 text-sm text-amber-300"
                >
                    Log backend unreachable. Make sure
                    <code className="mx-1 font-mono">
                        [plugins.scale.microservices.logs].enabled
                    </code>
                    is true and the Loki + Alloy stack is running in the deployment namespace. (M-14.a observability stack.)
                </div>}
                {errorMsg
                and not backendOffline
                and <div
                    className="bg-red-500/10 border border-red-500/40 rounded p-3 text-sm text-red-300"
                >
                    {errorMsg}
                </div>}
                {isLoading
                and <div className="flex items-center justify-center h-32">
                    <div className="text-sky-400">Loading logs...</div>
                </div>}
                {not isLoading
                and lines.length == 0
                and not errorMsg
                and <div
                    className="bg-slate-900 border border-slate-800 rounded p-8 text-slate-500 text-center"
                >
                    No logs in the selected window. Try a longer time range or hit your gateway to generate some traffic.
                </div>}
                {not isLoading
                and lines.length > 0
                and <div className="text-xs text-slate-500">
                    {lines.length} log {lines.length == 1 and "line" or "lines"}
                </div>}
                {not isLoading
                and lines.length > 0
                and <div
                    className="bg-slate-900 border border-slate-800 rounded font-mono text-sm overflow-x-auto max-h-[70vh] overflow-y-auto"
                >
                    {lines.map(
                        lambda (line: dict, idx: int) { return
                            <div
                                key={idx}
                                className="flex items-start gap-3 px-3 py-1.5 border-b border-slate-800/50 hover:bg-slate-800/30 cursor-pointer"
                                onClick={lambda { expandedIdx = idx
                                    if expandedIdx != idx
                                    else -1; }}
                            >
                                <span
                                    className="text-slate-500 text-xs whitespace-nowrap"
                                >
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
                                <span className="text-slate-200 break-all flex-1">
                                    {line["msg"] or ""}
                                </span>
                                {line["trace_id"]
                                and <button
                                    className="text-xs font-mono text-purple-300 hover:text-purple-200 px-1.5 py-0.5 rounded border border-purple-500/30 hover:bg-purple-500/10 whitespace-nowrap"
                                    onClick={lambda (e: any) {
                                        e.stopPropagation();
                                        loadTrace(String(line["trace_id"]));
                                    }}
                                    title="View full trace across all services"
                                >
                                    trace:{shortTrace(String(line["trace_id"]))}
                                </button>}
                            </div>; }
                    )}
                </div>}
            </div>;
    }
}
