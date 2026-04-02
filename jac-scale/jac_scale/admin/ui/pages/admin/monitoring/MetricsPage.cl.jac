"""Metrics monitoring page - Cyber-Grid futuristic dashboard."""

cl {
    import from react { useEffect }
    import from ....components.common.Button { Button }
    import from ....context.AuthContext { useAuth }
    import from ....services.metricsService { getMetrics }

    def:pub MetricsPage -> JsxElement {
        has isLoading: bool = True,
            metricsEnabled: bool = False,
            summary: dict = {},
            metrics: list = [],
            history: list = [],
            autoRefresh: bool = True;

        auth = useAuth();

        async def loadMetrics {
            result = await getMetrics(auth["authToken"]);
            if result["ok"] and result["data"] {
                metricsEnabled = result["data"]["enabled"];
                summary = result["data"]["summary"] or {};
                metrics = result["data"]["metrics"] or [];
                newPoint = {
                    "time": Date.now(),
                    "requests": summary["total_requests"] or 0,
                    "active": summary["active_requests"] or 0,
                    "errors": summary["error_count"] or 0,
                    "latency": summary["avg_latency_ms"] or 0
                };
                history = (history + [newPoint])[-20:];
            }
            isLoading = False;
        }

        useEffect(lambda { loadMetrics();}, []);

        useEffect(
            lambda -> any { if not autoRefresh {
                return undefined;
            }interval = setInterval(lambda { loadMetrics();}, 3000);return lambda { clearInterval(
                interval
            );}; },
            [autoRefresh]
        );

        def getBarHeight(value: float, maxVal: float) -> str {
            if maxVal == 0 {
                return "0%";
            }
            pct = min(100, (value / maxVal) * 100);
            return str(int(pct)) + "%";
        }

        def getMetricByName(name: str) -> dict {
            for m in metrics {
                if m["name"] == name {
                    return m;
                }
            }
            return {};
        }

        def getMetricValue(name: str, labelKey: str = "", labelVal: str = "") -> float {
            m = getMetricByName(name);
            if not m or not m["values"] {
                return 0.0;
            }
            for v in m["values"] {
                if not labelKey {
                    return v["value"] or 0.0;
                }
                labels = v["labels"] or {};
                if labels[labelKey] == labelVal {
                    return v["value"] or 0.0;
                }
            }
            return 0.0;
        }

        def formatBytes(bytesVal: float) -> str {
            if bytesVal >= 1073741824 {
                val = int(bytesVal / 10737418.24) / 100;
                return str(val) + " GB";
            }
            if bytesVal >= 1048576 {
                val = int(bytesVal / 10485.76) / 100;
                return str(val) + " MB";
            }
            if bytesVal >= 1024 {
                val = int(bytesVal / 10.24) / 100;
                return str(val) + " KB";
            }
            return str(int(bytesVal)) + " B";
        }

        def formatUptime(startTimeVal: float) -> str {
            if startTimeVal == 0 {
                return "N/A";
            }
            nowSecs = Date.now() / 1000;
            uptimeSecs = nowSecs - startTimeVal;
            if uptimeSecs < 60 {
                return str(int(uptimeSecs)) + "s";
            }
            if uptimeSecs < 3600 {
                return str(int(uptimeSecs / 60)) + "m " + str(int(uptimeSecs % 60)) + "s";
            }
            hours = int(uptimeSecs / 3600);
            mins = int((uptimeSecs % 3600) / 60);
            return str(hours) + "h " + str(mins) + "m";
        }

        def getHttpRequestsData -> list {
            m = getMetricByName("default_http_requests_total");
            if not m or not m["values"] {
                return [];
            }
            result = [];
            for v in m["values"] {
                labels = v["labels"] or {};
                result.append(
                    {
                        "method": labels["method"] or "?",
                        "path": labels["path"] or "?",
                        "status": labels["status_code"] or "?",
                        "count": int(v["value"] or 0)
                    }
                );
            }
            return sorted(result, key=lambda x: any { return -x["count"]; });
        }

        def getLatencyForPath(path: str) -> float {
            m = getMetricByName("default_http_request_duration_seconds");
            if not m or not m["values"] {
                return 0.0;
            }
            sumVal = 0.0;
            countVal = 0.0;
            for v in m["values"] {
                labels = v["labels"] or {};
                if labels["path"] == path {
                    if v["suffix"] == "_sum" {
                        sumVal = v["value"] or 0.0;
                    }
                    if v["suffix"] == "_count" {
                        countVal = v["value"] or 0.0;
                    }
                }
            }
            if countVal > 0 {
                return sumVal / countVal * 1000;
            }
            return 0.0;
        }

        def getStatusColor(status: str) -> str {
            if status.startswith("2") {
                return "text-teal-400";
            }
            if status.startswith("3") {
                return "text-cyan-400";
            }
            if status.startswith("4") {
                return "text-orange-400";
            }
            if status.startswith("5") {
                return "text-red-400";
            }
            return "text-slate-400";
        }

        def getMethodBadge(method: str) -> str {
            if method == "GET" {
                return "px-2 py-0.5 rounded text-xs font-bold bg-teal-500/30 text-teal-300 border border-teal-500/50";
            }
            if method == "POST" {
                return "px-2 py-0.5 rounded text-xs font-bold bg-lime-500/30 text-lime-300 border border-lime-500/50";
            }
            if method == "PUT" {
                return "px-2 py-0.5 rounded text-xs font-bold bg-orange-500/30 text-orange-300 border border-orange-500/50";
            }
            if method == "DELETE" {
                return "px-2 py-0.5 rounded text-xs font-bold bg-red-500/30 text-red-300 border border-red-500/50";
            }
            return "px-2 py-0.5 rounded text-xs font-bold bg-slate-500/30 text-slate-300 border border-slate-500/50";
        }

        if not metricsEnabled and not isLoading {
            return
                <div
                    className="relative bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950 border border-teal-500/30 rounded-2xl p-8 text-center shadow-2xl shadow-teal-500/10"
                >
                    <div
                        className="absolute inset-0 bg-[radial-gradient(circle_at_50%_50%,rgba(20,184,166,0.1),transparent_70%)] rounded-2xl"
                    ></div>
                    <div className="relative">
                        <div
                            className="w-16 h-16 mx-auto mb-4 rounded-full bg-slate-800 border-2 border-orange-500/50 flex items-center justify-center"
                        >
                            <span className="text-2xl text-orange-400">
                                !
                            </span>
                        </div>
                        <h2 className="text-xl font-bold text-white mb-2 tracking-wide">
                            METRICS OFFLINE
                        </h2>
                        <p className="text-sm text-slate-400 font-mono">
                            Enable in jac.toml: [plugins.scale.monitoring] enabled = true
                        </p>
                    </div>
                </div>;
        }

        totalReqs = summary["total_requests"] or 0;
        activeReqs = summary["active_requests"] or 0;
        errorCount = summary["error_count"] or 0;
        avgLatency = summary["avg_latency_ms"] or 0;
        avgLatencyDisplay = int(avgLatency * 100) / 100;

        maxReqs = 1;
        maxLatency = 1;
        for h in history {
            if h["requests"] > maxReqs {
                maxReqs = h["requests"];
            }
            if h["latency"] > maxLatency {
                maxLatency = h["latency"];
            }
        }

        virtualMem = getMetricValue("process_virtual_memory_bytes");
        residentMem = getMetricValue("process_resident_memory_bytes");
        cpuSeconds = getMetricValue("process_cpu_seconds_total");
        openFds = getMetricValue("process_open_fds");
        maxFds = getMetricValue("process_max_fds");
        startTime = getMetricValue("process_start_time_seconds");

        pythonInfo = getMetricByName("python_info");
        pythonVersion = "N/A";
        if pythonInfo and pythonInfo["values"] and len(pythonInfo["values"]) > 0 {
            pythonLabels = pythonInfo["values"][0]["labels"] or {};
            pythonVersion = pythonLabels["version"] or "N/A";
        }

        gcGen0 = int(
            getMetricValue("python_gc_objects_collected_total", "generation", "0")
        );
        gcGen1 = int(
            getMetricValue("python_gc_objects_collected_total", "generation", "1")
        );
        gcGen2 = int(
            getMetricValue("python_gc_objects_collected_total", "generation", "2")
        );
        maxGc = max(gcGen0, max(gcGen1, gcGen2));
        if maxGc == 0 {
            maxGc = 1;
        }

        httpRequests = getHttpRequestsData();
        maxReqCount = 1;
        if len(httpRequests) > 0 {
            maxReqCount = httpRequests[0]["count"];
        }

        slowestPath = "";
        slowestLatency = 0.0;
        for req in httpRequests {
            lat = getLatencyForPath(req["path"]);
            if lat > slowestLatency {
                slowestLatency = lat;
                slowestPath = req["path"];
            }
        }

        memUsagePercent = 0;
        if virtualMem > 0 {
            memUsagePercent = int((residentMem / virtualMem) * 100);
        }

        return
            <div
                className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950 p-6 space-y-6"
            >
                <div
                    className="absolute inset-0 bg-[url('data:image/svg+xml,%3Csvg%20width%3D%2260%22%20height%3D%2260%22%20viewBox%3D%220%200%2060%2060%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%3E%3Cg%20fill%3D%22none%22%20fill-rule%3D%22evenodd%22%3E%3Cpath%20d%3D%22M36%2034v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6%2034v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6%204V0H4v4H0v2h4v4h2V6h4V4H6z%22%20fill%3D%22%2314b8a6%22%20fill-opacity%3D%220.05%22/%3E%3C/g%3E%3C/svg%3E')] opacity-50 pointer-events-none"
                ></div>
                <div className="relative">
                    <div className="flex items-center justify-between mb-6">
                        <div className="flex items-center gap-4">
                            <div
                                className="w-3 h-3 rounded-full bg-teal-400 animate-pulse shadow-lg shadow-teal-400/50"
                            ></div>
                            <h1
                                className="text-2xl font-bold text-white tracking-wider"
                            >
                                OBSERVABILITY DASHBOARD
                            </h1>
                        </div>
                        <div className="flex items-center gap-4">
                            <label
                                className="flex items-center gap-2 text-xs text-slate-400 font-mono"
                            >
                                <input
                                    type="checkbox"
                                    checked={autoRefresh}
                                    onChange={lambda e: any { autoRefresh = e.target.checked;}}
                                    className="rounded border-teal-500/50 bg-slate-800 text-teal-500 focus:ring-teal-500/50"
                                />
                                LIVE SYNC
                            </label>
                            <Button
                                variant="secondary"
                                onClick={lambda { loadMetrics();}}
                            >
                                REFRESH
                            </Button>
                        </div>
                    </div>
                    <div
                        className="relative bg-gradient-to-br from-slate-900/80 to-slate-950/80 backdrop-blur-xl border border-teal-500/20 rounded-2xl p-6 mb-6 shadow-2xl shadow-teal-500/5"
                    >
                        <div
                            className="absolute top-0 left-1/2 -translate-x-1/2 w-32 h-1 bg-gradient-to-r from-transparent via-teal-500 to-transparent"
                        ></div>
                        <div className="flex items-center justify-center gap-8 mb-6">
                            <div
                                className="w-20 h-20 rounded-full bg-gradient-to-br from-teal-500/20 to-lime-500/20 border-2 border-lime-400 flex items-center justify-center shadow-lg shadow-lime-500/20"
                            >
                                <span className="text-4xl text-lime-400">
                                    ✓
                                </span>
                            </div>
                            <div className="text-center">
                                <div
                                    className="text-xs text-slate-500 font-mono tracking-widest mb-1"
                                >
                                    SYSTEM STATUS
                                </div>
                                <div
                                    className="text-2xl font-bold text-lime-400 tracking-wide"
                                >
                                    ENABLED
                                </div>
                            </div>
                        </div>
                        <div className="grid grid-cols-4 gap-6">
                            <div className="text-center">
                                <div
                                    className="text-4xl font-bold text-teal-400 font-mono"
                                >
                                    {totalReqs}
                                </div>
                                <div className="text-xs text-slate-500 font-mono mt-1">
                                    TOTAL REQUESTS
                                </div>
                            </div>
                            <div className="text-center">
                                <div
                                    className="text-4xl font-bold text-cyan-400 font-mono"
                                >
                                    {activeReqs}
                                </div>
                                <div className="text-xs text-slate-500 font-mono mt-1">
                                    ACTIVE NOW
                                </div>
                            </div>
                            <div className="text-center">
                                <div
                                    className="text-4xl font-bold text-teal-400 font-mono"
                                >
                                    {avgLatencyDisplay}ms
                                </div>
                                <div className="text-xs text-slate-500 font-mono mt-1">
                                    AVG LATENCY
                                </div>
                            </div>
                            <div className="text-center">
                                <div
                                    className="text-lg font-bold text-slate-300 font-mono"
                                >
                                    Python{pythonVersion}
                                </div>
                                <div className="text-xs text-slate-500 font-mono mt-1">
                                    BUILD INFO
                                </div>
                            </div>
                        </div>
                    </div>
                    <div className="grid grid-cols-3 gap-6">
                        <div className="col-span-2 space-y-6">
                            <div
                                className="bg-gradient-to-br from-slate-900/80 to-slate-950/80 backdrop-blur-xl border border-teal-500/20 rounded-2xl p-5 shadow-xl"
                            >
                                <div className="flex items-center justify-between mb-4">
                                    <div className="flex items-center gap-2">
                                        <div
                                            className="w-2 h-2 rounded-full bg-teal-400"
                                        ></div>
                                        <span
                                            className="text-sm font-bold text-white tracking-wide"
                                        >
                                            HTTP TRAFFIC
                                        </span>
                                    </div>
                                    <span className="text-xs text-slate-500 font-mono">
                                        LAST 60s
                                    </span>
                                </div>
                                <div className="h-24 flex items-end gap-1 mb-4">
                                    {[
                                        <div
                                            key={str(h["time"])}
                                            className="flex-1 bg-gradient-to-t from-teal-600 to-cyan-400 rounded-t opacity-80 hover:opacity-100 transition-all"
                                            style={{
                                                "height": getBarHeight(
                                                    h["requests"], maxReqs
                                                )
                                            }}
                                            title={str(h["requests"]) + " requests"}
                                        ></div> for h in history
                                    ]}
                                </div>
                                <div className="border-t border-slate-700/50 pt-4">
                                    <div
                                        className="flex items-center justify-between mb-3"
                                    >
                                        <div
                                            className="text-xs text-slate-400 font-mono"
                                        >
                                            ALL ENDPOINTS ({len(httpRequests)})
                                        </div>
                                    </div>
                                    <div
                                        className="space-y-2 max-h-64 overflow-y-auto pr-2"
                                    >
                                        {[
                                            <div
                                                key={req["path"] + req["status"]}
                                                className="flex items-center gap-3 text-xs"
                                            >
                                                <span
                                                    className={getMethodBadge(
                                                        req["method"]
                                                    )}
                                                >
                                                    {req["method"]}
                                                </span>
                                                <span
                                                    className="font-mono text-slate-300 flex-1 truncate"
                                                >
                                                    {req["path"]}
                                                </span>
                                                <span
                                                    className={getStatusColor(
                                                        req["status"]
                                                    )}
                                                >
                                                    {req["status"]}
                                                </span>
                                                <span
                                                    className="text-teal-400 font-bold w-12 text-right"
                                                >
                                                    {req["count"]}
                                                </span>
                                                <div
                                                    className="w-20 bg-slate-700/50 rounded-full h-1"
                                                >
                                                    <div
                                                        className="bg-teal-400 h-1 rounded-full"
                                                        style={{
                                                            "width": getBarHeight(
                                                                req[
                                                                    "count"
                                                                ],
                                                                maxReqCount
                                                            )
                                                        }}
                                                    ></div>
                                                </div>
                                            </div> for req in httpRequests
                                        ]}
                                    </div>
                                </div>
                                {slowestLatency > 1000
                                and <div
                                    className="mt-4 p-3 bg-orange-500/10 border border-orange-500/30 rounded-lg"
                                >
                                    <div className="flex items-center gap-2 text-xs">
                                        <span className="text-orange-400">
                                            ⚠
                                        </span>
                                        <span className="text-orange-300 font-mono">
                                            SLOWEST PATH:
                                        </span>
                                        <span
                                            className="text-slate-300 font-mono flex-1 truncate"
                                        >
                                            {slowestPath}
                                        </span>
                                        <span className="text-orange-400 font-bold">
                                            {int(slowestLatency / 100) / 10}s
                                        </span>
                                    </div>
                                </div>}
                            </div>
                            <div
                                className="bg-gradient-to-br from-slate-900/80 to-slate-950/80 backdrop-blur-xl border border-teal-500/20 rounded-2xl p-5 shadow-xl"
                            >
                                <div className="flex items-center gap-2 mb-4">
                                    <div className="w-2 h-2 rounded-full bg-orange-400"></div>
                                    <span
                                        className="text-sm font-bold text-white tracking-wide"
                                    >
                                        PYTHON GARBAGE COLLECTION
                                    </span>
                                </div>
                                <div className="grid grid-cols-3 gap-6">
                                    <div className="text-center">
                                        <div
                                            className="h-32 flex items-end justify-center mb-2"
                                        >
                                            <div
                                                className="w-16 bg-gradient-to-t from-teal-600 to-teal-400 rounded-t"
                                                style={{
                                                    "height": getBarHeight(
                                                        gcGen0, maxGc
                                                    )
                                                }}
                                            ></div>
                                        </div>
                                        <div
                                            className="text-lg font-bold text-teal-400 font-mono"
                                        >
                                            {gcGen0}
                                        </div>
                                        <div
                                            className="text-xs text-slate-500 font-mono"
                                        >
                                            GEN 0 (YOUNG)
                                        </div>
                                    </div>
                                    <div className="text-center">
                                        <div
                                            className="h-32 flex items-end justify-center mb-2"
                                        >
                                            <div
                                                className="w-16 bg-gradient-to-t from-teal-600 to-cyan-400 rounded-t"
                                                style={{
                                                    "height": getBarHeight(
                                                        gcGen1, maxGc
                                                    )
                                                }}
                                            ></div>
                                        </div>
                                        <div
                                            className="text-lg font-bold text-cyan-400 font-mono"
                                        >
                                            {gcGen1}
                                        </div>
                                        <div
                                            className="text-xs text-slate-500 font-mono"
                                        >
                                            GEN 1 (MID)
                                        </div>
                                    </div>
                                    <div className="text-center">
                                        <div
                                            className="h-32 flex items-end justify-center mb-2"
                                        >
                                            <div
                                                className="w-16 bg-gradient-to-t from-orange-600 to-orange-400 rounded-t"
                                                style={{
                                                    "height": getBarHeight(
                                                        gcGen2, maxGc
                                                    )
                                                }}
                                            ></div>
                                        </div>
                                        <div
                                            className="text-lg font-bold text-orange-400 font-mono"
                                        >
                                            {gcGen2}
                                        </div>
                                        <div
                                            className="text-xs text-slate-500 font-mono"
                                        >
                                            GEN 2 (OLD)
                                        </div>
                                    </div>
                                </div>
                                <div
                                    className="mt-4 p-3 bg-teal-500/10 border border-teal-500/30 rounded-lg"
                                >
                                    <div className="flex items-center gap-2 text-xs">
                                        <span className="text-teal-400">
                                            💡
                                        </span>
                                        <span className="text-teal-300">
                                            Gen 2 is doing the heavy lifting — no memory leaks detected.
                                        </span>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div className="space-y-6">
                            <div
                                className="bg-gradient-to-br from-slate-900/80 to-slate-950/80 backdrop-blur-xl border border-teal-500/20 rounded-2xl p-5 shadow-xl"
                            >
                                <div className="flex items-center gap-2 mb-4">
                                    <div className="w-2 h-2 rounded-full bg-cyan-400"></div>
                                    <span
                                        className="text-sm font-bold text-white tracking-wide"
                                    >
                                        MEMORY
                                    </span>
                                </div>
                                <div className="relative w-32 h-32 mx-auto mb-4">
                                    <svg
                                        className="w-full h-full -rotate-90"
                                        viewBox="0 0 100 100"
                                    >
                                        <circle
                                            cx="50"
                                            cy="50"
                                            r="40"
                                            fill="none"
                                            stroke="#1e293b"
                                            strokeWidth="8"
                                        ></circle>
                                        <circle
                                            cx="50"
                                            cy="50"
                                            r="40"
                                            fill="none"
                                            stroke="url(#memGradient)"
                                            strokeWidth="8"
                                            strokeLinecap="round"
                                            strokeDasharray={str(
                                                memUsagePercent * 2.51
                                            ) + " 251"}
                                        ></circle>
                                        <defs>
                                            <linearGradient
                                                id="memGradient"
                                                x1="0%"
                                                y1="0%"
                                                x2="100%"
                                                y2="0%"
                                            >
                                                <stop offset="0%" stopColor="#14b8a6"></stop>
                                                <stop offset="100%" stopColor="#22d3ee"></stop>
                                            </linearGradient>
                                        </defs>
                                    </svg>
                                    <div
                                        className="absolute inset-0 flex items-center justify-center"
                                    >
                                        <span className="text-xl font-bold text-white">
                                            {memUsagePercent}%
                                        </span>
                                    </div>
                                </div>
                                <div className="space-y-2 text-xs">
                                    <div className="flex justify-between">
                                        <span className="text-slate-400 font-mono">
                                            VIRTUAL
                                        </span>
                                        <span className="text-cyan-400 font-mono">
                                            {formatBytes(virtualMem)}
                                        </span>
                                    </div>
                                    <div className="flex justify-between">
                                        <span className="text-slate-400 font-mono">
                                            RESIDENT
                                        </span>
                                        <span className="text-teal-400 font-mono">
                                            {formatBytes(residentMem)}
                                        </span>
                                    </div>
                                </div>
                            </div>
                            <div
                                className="bg-gradient-to-br from-slate-900/80 to-slate-950/80 backdrop-blur-xl border border-teal-500/20 rounded-2xl p-5 shadow-xl"
                            >
                                <div className="flex items-center gap-2 mb-4">
                                    <div className="w-2 h-2 rounded-full bg-lime-400"></div>
                                    <span
                                        className="text-sm font-bold text-white tracking-wide"
                                    >
                                        CPU TIME
                                    </span>
                                </div>
                                <div className="text-center">
                                    <div
                                        className="text-4xl font-bold text-lime-400 font-mono"
                                    >
                                        {str(int(cpuSeconds * 100) / 100)}s
                                    </div>
                                    <div
                                        className="text-xs text-slate-500 font-mono mt-2"
                                    >
                                        TOTAL CPU SECONDS
                                    </div>
                                </div>
                            </div>
                            <div
                                className="bg-gradient-to-br from-slate-900/80 to-slate-950/80 backdrop-blur-xl border border-teal-500/20 rounded-2xl p-5 shadow-xl"
                            >
                                <div className="flex items-center gap-2 mb-4">
                                    <div className="w-2 h-2 rounded-full bg-purple-400"></div>
                                    <span
                                        className="text-sm font-bold text-white tracking-wide"
                                    >
                                        FILE DESCRIPTORS
                                    </span>
                                </div>
                                <div className="text-center">
                                    <div
                                        className="text-2xl font-bold text-purple-400 font-mono"
                                    >
                                        {int(openFds)}
                                        <span className="text-slate-500 text-lg">
                                            /{int(maxFds)}
                                        </span>
                                    </div>
                                    <div
                                        className="text-xs text-slate-500 font-mono mt-2"
                                    >
                                        OPEN / MAX
                                    </div>
                                </div>
                            </div>
                            <div
                                className="bg-gradient-to-br from-slate-900/80 to-slate-950/80 backdrop-blur-xl border border-teal-500/20 rounded-2xl p-5 shadow-xl"
                            >
                                <div className="flex items-center gap-2 mb-3">
                                    <div className="w-2 h-2 rounded-full bg-slate-400"></div>
                                    <span
                                        className="text-sm font-bold text-white tracking-wide"
                                    >
                                        UPTIME
                                    </span>
                                </div>
                                <div className="text-center">
                                    <div
                                        className="text-xl font-bold text-slate-300 font-mono"
                                    >
                                        {formatUptime(startTime)}
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>;
    }
}
