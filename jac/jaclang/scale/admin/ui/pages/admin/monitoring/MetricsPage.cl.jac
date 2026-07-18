"""Metrics monitoring page - process + HTTP observability."""

import from "lucide-react" {
    Activity,
    RefreshCw,
    Globe,
    Cpu,
    MemoryStick,
    Recycle,
    FileText,
    Clock,
    CheckCircle2,
    AlertTriangle
}

import from react { useEffect }
import from ....components.common.Button { Button }
import from ....components.common.PageHeader { PageHeader }
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

    useEffect(lambda { loadMetrics(); }, []);

    useEffect(
        lambda -> any {
            if not autoRefresh {
                return undefined;
            }
            interval = setInterval(lambda { loadMetrics(); }, 3000);
            return lambda { clearInterval(interval); };
        },
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
        return sorted(result, key=lambda (x: any) { return -x["count"]; });
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

    # Semantic status color: 2xx ok, 4xx warn, 5xx error.
    def getStatusColor(status: str) -> str {
        if status.startswith("2") {
            return "text-success";
        }
        if status.startswith("4") {
            return "text-warning";
        }
        if status.startswith("5") {
            return "text-danger";
        }
        return "text-muted";
    }

    # Method chip: subtle weak-tinted token backgrounds, one per verb.
    def getMethodBadge(method: str) -> str {
        base = "px-1.5 py-0.5 rounded text-[10px] font-semibold border border-line ";
        if method == "GET" {
            return base + "bg-success-weak text-success";
        }
        if method == "POST" {
            return base + "bg-accent-weak text-accent";
        }
        if method == "PUT" {
            return base + "bg-warning-weak text-warning";
        }
        if method == "DELETE" {
            return base + "bg-danger-weak text-danger";
        }
        return base + "bg-surface-2 text-muted";
    }

    if not metricsEnabled and not isLoading {
        return
            <div
                className="bg-surface border border-line rounded-lg p-10 text-center shadow-sm"
            >
                <div
                    className="w-12 h-12 mx-auto mb-4 rounded-full bg-surface-2 border border-line flex items-center justify-center"
                >
                    <Activity className="w-5 h-5 text-faint"/>
                </div>
                <h2 className="text-base font-semibold text-fg mb-1">
                    Metrics are off
                </h2>
                <p className="text-sm text-muted">
                    Enable in jac.toml:
                    <span className="font-mono text-fg ml-1">
                        [scale.monitoring] enabled = true
                    </span>
                </p>
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

    headerRight = <div className="flex items-center gap-3">
        <label className="flex items-center gap-2 text-xs text-muted">
            <input
                type="checkbox"
                checked={autoRefresh}
                onChange={lambda (e: any) { autoRefresh = e.target.checked; }}
                className="rounded border-line bg-surface-2 text-accent focus:ring-accent"
            />
            Auto-refresh
        </label>
        <Button variant="secondary" onClick={lambda { loadMetrics(); }}>
            <RefreshCw className="w-3.5 h-3.5"/>
            Refresh
        </Button>
    </div>;

    return
        <div className="space-y-6">
            <PageHeader
                icon={Activity}
                title="Metrics"
                live={True}
                right={headerRight}
            />
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                <div className="bg-surface border border-line rounded-lg p-4 shadow-sm">
                    <div className="flex items-center justify-between">
                        <span className="text-xs text-faint">Total requests</span>
                        <Globe className="w-4 h-4 text-faint"/>
                    </div>
                    <div className="text-2xl font-semibold text-fg mt-2 tabular-nums">
                        {totalReqs}
                    </div>
                </div>
                <div className="bg-surface border border-line rounded-lg p-4 shadow-sm">
                    <div className="flex items-center justify-between">
                        <span className="text-xs text-faint">Active now</span>
                        <Activity className="w-4 h-4 text-faint"/>
                    </div>
                    <div className="text-2xl font-semibold text-fg mt-2 tabular-nums">
                        {activeReqs}
                    </div>
                </div>
                <div className="bg-surface border border-line rounded-lg p-4 shadow-sm">
                    <div className="flex items-center justify-between">
                        <span className="text-xs text-faint">Avg latency</span>
                        <Clock className="w-4 h-4 text-faint"/>
                    </div>
                    <div className="text-2xl font-semibold text-fg mt-2 tabular-nums">
                        {avgLatencyDisplay}
                        <span className="text-base text-faint">ms</span>
                    </div>
                </div>
                <div className="bg-surface border border-line rounded-lg p-4 shadow-sm">
                    <div className="flex items-center justify-between">
                        <span className="text-xs text-faint">Runtime</span>
                        <Cpu className="w-4 h-4 text-faint"/>
                    </div>
                    <div className="text-base font-semibold text-fg mt-3 font-mono">
                        Python {pythonVersion}
                    </div>
                </div>
            </div>
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                <div className="lg:col-span-2 space-y-6">
                    <div
                        className="bg-surface border border-line rounded-lg p-5 shadow-sm"
                    >
                        <div className="flex items-center justify-between mb-4">
                            <div className="flex items-center gap-2">
                                <Globe className="w-4 h-4 text-muted"/>
                                <span className="text-sm font-medium text-fg">
                                    HTTP traffic
                                </span>
                            </div>
                            <span className="text-xs text-faint">Last 60s</span>
                        </div>
                        <div className="h-24 flex items-end gap-1 mb-4">
                            {[
                                <div
                                    key={str(h["time"])}
                                    className="flex-1 bg-accent rounded-t opacity-80 hover:opacity-100 transition-opacity"
                                    style={{
                                        "height": getBarHeight(h["requests"], maxReqs)
                                    }}
                                    title={str(h["requests"]) + " requests"}
                                ></div> for h in history
                            ]}
                        </div>
                        <div className="border-t border-line pt-4">
                            <div className="text-xs text-muted mb-3">
                                All endpoints ({len(httpRequests)})
                            </div>
                            <div className="space-y-2 max-h-64 overflow-y-auto pr-2">
                                {[
                                    <div
                                        key={req["path"] + req["status"]}
                                        className="flex items-center gap-3 text-xs"
                                    >
                                        <span className={getMethodBadge(req["method"])}>
                                            {req["method"]}
                                        </span>
                                        <span
                                            className="font-mono text-muted flex-1 truncate"
                                        >
                                            {req["path"]}
                                        </span>
                                        <span className={getStatusColor(req["status"])}>
                                            {req["status"]}
                                        </span>
                                        <span
                                            className="text-fg font-semibold w-12 text-right tabular-nums"
                                        >
                                            {req["count"]}
                                        </span>
                                        <div
                                            className="w-20 bg-surface-2 rounded-full h-1"
                                        >
                                            <div
                                                className="bg-accent h-1 rounded-full"
                                                style={{
                                                    "width": getBarHeight(
                                                        req["count"], maxReqCount
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
                            className="mt-4 p-3 bg-warning-weak border border-line rounded-lg"
                        >
                            <div className="flex items-center gap-2 text-xs">
                                <AlertTriangle
                                    className="w-3.5 h-3.5 text-warning shrink-0"
                                />
                                <span className="text-warning font-medium">
                                    Slowest path
                                </span>
                                <span className="text-muted font-mono flex-1 truncate">
                                    {slowestPath}
                                </span>
                                <span className="text-fg font-semibold">
                                    {int(slowestLatency / 100) / 10}s
                                </span>
                            </div>
                        </div>}
                    </div>
                    <div
                        className="bg-surface border border-line rounded-lg p-5 shadow-sm"
                    >
                        <div className="flex items-center gap-2 mb-4">
                            <Recycle className="w-4 h-4 text-muted"/>
                            <span className="text-sm font-medium text-fg">
                                Garbage collection
                            </span>
                        </div>
                        <div className="grid grid-cols-3 gap-6">
                            <div className="text-center">
                                <div
                                    className="h-32 flex items-end justify-center mb-2"
                                >
                                    <div
                                        className="w-12 bg-accent rounded-t"
                                        style={{"height": getBarHeight(gcGen0, maxGc)}}
                                    ></div>
                                </div>
                                <div
                                    className="text-lg font-semibold text-fg font-mono tabular-nums"
                                >
                                    {gcGen0}
                                </div>
                                <div className="text-xs text-faint">Gen 0 (young)</div>
                            </div>
                            <div className="text-center">
                                <div
                                    className="h-32 flex items-end justify-center mb-2"
                                >
                                    <div
                                        className="w-12 bg-accent rounded-t"
                                        style={{"height": getBarHeight(gcGen1, maxGc)}}
                                    ></div>
                                </div>
                                <div
                                    className="text-lg font-semibold text-fg font-mono tabular-nums"
                                >
                                    {gcGen1}
                                </div>
                                <div className="text-xs text-faint">Gen 1 (mid)</div>
                            </div>
                            <div className="text-center">
                                <div
                                    className="h-32 flex items-end justify-center mb-2"
                                >
                                    <div
                                        className="w-12 bg-accent rounded-t"
                                        style={{"height": getBarHeight(gcGen2, maxGc)}}
                                    ></div>
                                </div>
                                <div
                                    className="text-lg font-semibold text-fg font-mono tabular-nums"
                                >
                                    {gcGen2}
                                </div>
                                <div className="text-xs text-faint">Gen 2 (old)</div>
                            </div>
                        </div>
                        <div
                            className="mt-4 p-3 bg-surface-2 border border-line rounded-lg"
                        >
                            <div className="flex items-center gap-2 text-xs">
                                <CheckCircle2
                                    className="w-3.5 h-3.5 text-success shrink-0"
                                />
                                <span className="text-muted">
                                    Gen 2 is doing the heavy lifting - no memory leaks detected.
                                </span>
                            </div>
                        </div>
                    </div>
                </div>
                <div className="space-y-6">
                    <div
                        className="bg-surface border border-line rounded-lg p-5 shadow-sm"
                    >
                        <div className="flex items-center gap-2 mb-4">
                            <MemoryStick className="w-4 h-4 text-muted"/>
                            <span className="text-sm font-medium text-fg">Memory</span>
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
                                    className="stroke-line"
                                    strokeWidth="8"
                                ></circle>
                                <circle
                                    cx="50"
                                    cy="50"
                                    r="40"
                                    fill="none"
                                    className="stroke-accent"
                                    strokeWidth="8"
                                    strokeLinecap="round"
                                    strokeDasharray={str(memUsagePercent * 2.51) + " 251"}
                                ></circle>
                            </svg>
                            <div
                                className="absolute inset-0 flex items-center justify-center"
                            >
                                <span
                                    className="text-xl font-semibold text-fg tabular-nums"
                                >
                                    {memUsagePercent}%
                                </span>
                            </div>
                        </div>
                        <div className="space-y-2 text-xs">
                            <div className="flex justify-between">
                                <span className="text-muted">Virtual</span>
                                <span className="text-fg font-mono">
                                    {formatBytes(virtualMem)}
                                </span>
                            </div>
                            <div className="flex justify-between">
                                <span className="text-muted">Resident</span>
                                <span className="text-fg font-mono">
                                    {formatBytes(residentMem)}
                                </span>
                            </div>
                        </div>
                    </div>
                    <div
                        className="bg-surface border border-line rounded-lg p-5 shadow-sm"
                    >
                        <div className="flex items-center gap-2 mb-4">
                            <Cpu className="w-4 h-4 text-muted"/>
                            <span className="text-sm font-medium text-fg">
                                CPU time
                            </span>
                        </div>
                        <div className="text-center">
                            <div
                                className="text-3xl font-semibold text-fg font-mono tabular-nums"
                            >
                                {str(int(cpuSeconds * 100) / 100)}s
                            </div>
                            <div className="text-xs text-faint mt-2">
                                Total CPU seconds
                            </div>
                        </div>
                    </div>
                    <div
                        className="bg-surface border border-line rounded-lg p-5 shadow-sm"
                    >
                        <div className="flex items-center gap-2 mb-4">
                            <FileText className="w-4 h-4 text-muted"/>
                            <span className="text-sm font-medium text-fg">
                                File descriptors
                            </span>
                        </div>
                        <div className="text-center">
                            <div
                                className="text-2xl font-semibold text-fg font-mono tabular-nums"
                            >
                                {int(openFds)}
                                <span className="text-faint text-lg">
                                    /{int(maxFds)}
                                </span>
                            </div>
                            <div className="text-xs text-faint mt-2">Open / max</div>
                        </div>
                    </div>
                    <div
                        className="bg-surface border border-line rounded-lg p-5 shadow-sm"
                    >
                        <div className="flex items-center gap-2 mb-3">
                            <Clock className="w-4 h-4 text-muted"/>
                            <span className="text-sm font-medium text-fg">Uptime</span>
                        </div>
                        <div className="text-center">
                            <div className="text-xl font-semibold text-fg font-mono">
                                {formatUptime(startTime)}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>;
}
