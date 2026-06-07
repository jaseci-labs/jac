"""Distributed Traces page for the admin dashboard.

Queries Tempo via /admin/traces/* and renders:

- a TraceQL search bar (service / errors-only / min-duration / window),
- a list of matching traces (root service + name, duration), and
- a flame-graph / span waterfall for the selected trace: one bar per
  span, positioned by start offset and sized by duration, nested by
  parent_span_id, colored by service.

The trace_id here is the same id the logs page surfaces, so the two
views cross-link directly.
"""

cl {
    import from react { useEffect }
    import from ....context.AuthContext { useAuth }
    import from ....services.tracesService { getTraceServices, searchTraces, getTrace }

    def:pub TracesPage -> JsxElement {
        has isLoading: bool = False,
            isLoadingTrace: bool = False,
            traces: list = [],
            services: list = [],
            filterService: str = "",
            filterStatus: str = "",
            filterMinDuration: int = 0,
            filterSince: str = "1h",
            errorMsg: str = "",
            backendOffline: bool = False,
            selectedTraceId: str = "",
            spans: list = [],
            traceStartNs: int = 0,
            traceTotalMs: float = 0.0;

        auth = useAuth();

        async def loadServices {
            try {
                result = await getTraceServices(auth["authToken"]);
                if result["ok"] and result["data"] {
                    services = result["data"]["services"] or [];
                }
            } except Exception as e {
                console.error("loadServices error:", e);
            }
        }

        async def loadTraces {
            isLoading = True;
            backendOffline = False;
            try {
                result = await searchTraces(
                    auth["authToken"],
                    filterService,
                    filterStatus,
                    filterMinDuration,
                    filterSince,
                    50
                );
                if result["ok"] and result["data"] {
                    traces = result["data"]["traces"] or [];
                    errorMsg = "";
                } elif result["error"] {
                    errorMsg = result["error"]["message"] or "Failed to load traces";
                    if "unavailable" in (errorMsg or "").toLowerCase() {
                        backendOffline = True;
                    }
                }
            } except Exception as e {
                console.error("loadTraces error:", e);
                errorMsg = "Error loading traces: " + String(e);
            }
            isLoading = False;
        }

        async def openTrace(tid: str) {
            selectedTraceId = tid;
            isLoadingTrace = True;
            spans = [];
            try {
                result = await getTrace(auth["authToken"], tid);
                if result["ok"] and result["data"] {
                    spans = result["data"]["spans"] or [];
                    traceStartNs = result["data"]["start_ns"] or 0;
                    traceTotalMs = result["data"]["total_ms"] or 0.0;
                } elif result["error"] {
                    errorMsg = result["error"]["message"] or "Failed to load trace";
                }
            } except Exception as e {
                console.error("openTrace error:", e);
            }
            isLoadingTrace = False;
        }

        def closeTrace {
            selectedTraceId = "";
            spans = [];
            traceStartNs = 0;
            traceTotalMs = 0.0;
        }

        useEffect(
            lambda {
                loadServices();
                loadTraces();
            },
            []
        );

        # Re-search when the dropdown filters change (debounced 250ms so
        # dragging through <select> options doesn't fire a request each).
        useEffect(
            lambda -> any {
                timer = setTimeout(lambda { loadTraces(); }, 250);
                return lambda { clearTimeout(timer); };
            },
            [filterService, filterStatus, filterSince, filterMinDuration]
        );

        # ---- helpers -----------------------------------------------------
        # Stable hash-based color per service (matches LogsPage palette so
        # a service reads the same color across the logs + traces pages).
        def serviceColorBar(name: str) -> str {
            palette = [
                "bg-sky-500",
                "bg-emerald-500",
                "bg-amber-500",
                "bg-purple-500",
                "bg-pink-500",
                "bg-cyan-500",
                "bg-orange-500",
                "bg-lime-500",
                "bg-rose-500",
                "bg-indigo-500"
            ];
            if not name {
                return "bg-slate-500";
            }
            hash: int = 0;
            i: int = 0;
            while i < len(name) {
                hash = ((hash << 5) - hash + name.charCodeAt(i)) | 0;
                i += 1;
            }
            return palette[Math.abs(hash) % len(palette)];
        }

        # Span depth from the parent_span_id chain, so the waterfall can
        # indent children. Capped to avoid a cycle in malformed data.
        def spanDepth(span: dict, byId: dict) -> int {
            depth: int = 0;
            parent = String(span["parent_span_id"] or "");
            guard: int = 0;
            while parent and byId[parent] and guard < 64 {
                depth += 1;
                parent = String(byId[parent]["parent_span_id"] or "");
                guard += 1;
            }
            return depth;
        }

        def buildById -> dict {
            byId: dict = {};
            for s in spans {
                byId[String(s["span_id"] or "")] = s;
            }
            return byId;
        }

        # Percent offset + width of a span bar within the trace window.
        def barLeft(span: dict) -> float {
            if traceTotalMs <= 0 {
                return 0.0;
            }
            offset_ms = (Number(span["start_ns"] or 0) - traceStartNs) / 1000000.0;
            pct = offset_ms / traceTotalMs * 100.0;
            if pct < 0 {
                return 0.0;
            }
            return pct;
        }

        def barWidth(span: dict) -> float {
            if traceTotalMs <= 0 {
                return 100.0;
            }
            pct = Number(span["duration_ms"] or 0) / traceTotalMs * 100.0;
            # Floor so sub-millisecond spans stay visible.
            if pct < 0.5 {
                return 0.5;
            }
            return pct;
        }

        def fmtMs(ms: any) -> str {
            n = Number(ms or 0);
            if n >= 1000 {
                return String(Math.round(n / 100.0) / 10.0) + "s";
            }
            return String(Math.round(n * 10.0) / 10.0) + "ms";
        }

        # ---- render ------------------------------------------------------
        byIdMap = buildById();

        return
            <div className="space-y-4">
                <div className="flex items-center justify-between">
                    <h2 className="text-lg font-semibold text-slate-100">
                        Distributed Traces
                    </h2>
                    <button
                        className="px-3 py-1.5 text-sm rounded bg-slate-800 text-slate-200 border border-slate-700 hover:bg-slate-700"
                        onClick={lambda { loadTraces(); }}
                    >
                        Refresh
                    </button>
                </div>
                <div className="flex flex-wrap gap-3 items-end">
                    <select
                        value={filterService}
                        onChange={lambda e: any { filterService = e.target.value; }}
                        className="bg-slate-900 border border-slate-700 rounded px-2 py-1.5 text-sm text-slate-200"
                    >
                        <option value="">All services</option>
                        {[<option key={s} value={s}>{s}</option> for s in services]}
                    </select>
                    <select
                        value={filterStatus}
                        onChange={lambda e: any { filterStatus = e.target.value; }}
                        className="bg-slate-900 border border-slate-700 rounded px-2 py-1.5 text-sm text-slate-200"
                    >
                        <option value="">All statuses</option>
                        <option value="error">Errors only</option>
                    </select>
                    <select
                        value={String(filterMinDuration)}
                        onChange={lambda e: any { filterMinDuration = Number(
                            e.target.value
                        ); }}
                        className="bg-slate-900 border border-slate-700 rounded px-2 py-1.5 text-sm text-slate-200"
                    >
                        <option value="0">Any duration</option>
                        <option value="100">{">"} 100ms</option>
                        <option value="500">{">"} 500ms</option>
                        <option value="1000">{">"} 1s</option>
                    </select>
                    <select
                        value={filterSince}
                        onChange={lambda e: any { filterSince = e.target.value; }}
                        className="bg-slate-900 border border-slate-700 rounded px-2 py-1.5 text-sm text-slate-200"
                    >
                        <option value="15m">Last 15 min</option>
                        <option value="1h">Last 1 hour</option>
                        <option value="6h">Last 6 hours</option>
                        <option value="1d">Last 24 hours</option>
                    </select>
                </div>
                {<div
                    className="text-amber-300 text-sm bg-amber-500/10 border border-amber-500/30 rounded p-3"
                >
                    Trace backend unavailable. Enable tracing with [plugins.scale.microservices.tracing].enabled = true and redeploy so Tempo + the Alloy OTLP lane come up.
                </div>
                    if backendOffline
                    else None}
                {<div className="text-red-300 text-sm">{errorMsg}</div>
                    if (errorMsg and not backendOffline)
                    else None}
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
                    <div className="lg:col-span-1 space-y-2">
                        <div className="text-xs uppercase tracking-wide text-slate-500">
                            Traces ({len(traces)})
                        </div>
                        {<div className="text-slate-500 text-sm">Loading...</div>
                            if isLoading
                            else None}
                        {[
                            <div
                                key={t["trace_id"]}
                                className={"p-2 rounded border cursor-pointer " + (
                                    "border-sky-500 bg-sky-500/10"
                                        if (t["trace_id"] == selectedTraceId)
                                        else "border-slate-800 bg-slate-900 hover:bg-slate-800"
                                )}
                                onClick={lambda { openTrace(t["trace_id"]); }}
                            >
                                <div className="flex items-center justify-between">
                                    <span
                                        className="text-sm font-medium text-slate-200"
                                    >
                                        {t["root_service"] or "unknown"}
                                    </span>
                                    <span className="text-xs text-slate-400">
                                        {fmtMs(t["duration_ms"])}
                                    </span>
                                </div>
                                <div className="text-xs text-slate-500 truncate">
                                    {t["root_name"] or t["trace_id"]}
                                </div>
                            </div> for t in traces
                        ]}
                        {<div className="text-slate-500 text-sm">
                            No traces in this window.
                        </div>
                            if (not isLoading and len(traces) == 0)
                            else None}
                    </div>
                    <div className="lg:col-span-2">
                        {<div className="text-slate-500 text-sm">Loading trace...</div>
                            if isLoadingTrace
                            else None}{<div className="space-y-1">
                            <div className="flex items-center justify-between mb-2">
                                <span
                                    className="text-xs font-mono text-slate-400 truncate"
                                >
                                    {selectedTraceId}
                                </span>
                                <button
                                    className="text-xs text-slate-400 hover:text-slate-200"
                                    onClick={closeTrace}
                                >
                                    close
                                </button>
                            </div>
                            {[
                                <div
                                    key={sp["span_id"]}
                                    className="flex items-center gap-2 text-xs"
                                >
                                    <div
                                        className="w-1/3 truncate text-slate-300"
                                        style={{
                                            "paddingLeft": String(
                                                spanDepth(sp, byIdMap) * 12
                                            ) + "px"
                                        }}
                                    >
                                        <span className="text-slate-500">
                                            {sp["service"]}
                                        </span>{" "}
                                        {sp["name"]}
                                    </div>
                                    <div
                                        className="flex-1 relative h-4 bg-slate-900 rounded"
                                    >
                                        <div
                                            className={"absolute h-4 rounded " + (
                                                serviceColorBar(sp["service"])
                                            ) + (
                                                " ring-1 ring-red-400"
                                                    if (
                                                        sp["status"] == "STATUS_CODE_ERROR"
                                                        or sp["status"] == "2"
                                                    )
                                                    else ""
                                            )}
                                            style={{
                                                "left": String(barLeft(sp)) + "%",
                                                "width": String(barWidth(sp)) + "%"
                                            }}
                                            title={sp["name"] + " " + fmtMs(
                                                sp["duration_ms"]
                                            )}
                                        ></div>
                                    </div>
                                    <div className="w-16 text-right text-slate-400">
                                        {fmtMs(sp["duration_ms"])}
                                    </div>
                                </div> for sp in spans
                            ]}
                            {<div className="text-slate-500 text-sm">
                                No spans for this trace.
                            </div>
                                if (not isLoadingTrace and len(spans) == 0)
                                else None}
                        </div>
                            if selectedTraceId
                            else <div className="text-slate-500 text-sm">
                                Select a trace to view its flame graph.
                            </div>}
                    </div>
                </div>
            </div>;
    }
}
