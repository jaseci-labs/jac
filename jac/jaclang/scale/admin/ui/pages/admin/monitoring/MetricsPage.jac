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
    AlertTriangle
}

import from "react" { useEffect, useRef }
import from ....components.common.Button { Button }
import from ....components.common.PageHeader { PageHeader }
import from ....context.AuthContext { useAuth }
import from ....services.metricsService { getMetrics }
import from ....utils.format { formatBytes }

def:pub MetricsPage -> JsxElement {
    has isLoading: bool = True,
        metricsEnabled: bool = False,
        summary: dict = {},
        metrics: list = [],
        history: list = [],
        autoRefresh: bool = True,
        windowSecs: int = 60,
        scope: str = "app";

    auth = useAuth();
    # Accumulate the chart history in a ref, not via reading `history` state
    # inside the polling interval -- that lambda captures a stale `history`
    # (closure), so the chart froze after the first few points. The ref is
    # stable across renders, so .current always reads the latest buffer.
    histRef = useRef([]);

    def scopeFailed(s: dict) -> int {
        return (s["server_errors"] or 0) + (s["client_errors"] or 0);
    }

    async def loadMetrics {
        result = await getMetrics(auth["authToken"]);
        if result["ok"] and result["data"] {
            metricsEnabled = result["data"]["enabled"];
            summary = result["data"]["summary"] or {};
            metrics = result["data"]["metrics"] or [];
            prevBuf = histRef.current or [];
            scopes = summary["scopes"] or {};
            appScope = scopes["app"] or {};
            otherScope = scopes["other"] or {};
            allScope = scopes["all"] or {};
            newPoint = {
                "time": Date.now(),
                "app": appScope["requests"] or 0,
                "other": otherScope["requests"] or 0,
                "all": allScope["requests"] or 0,
                "appErr": scopeFailed(appScope),
                "otherErr": scopeFailed(otherScope),
                "allErr": scopeFailed(allScope)
            };
            # Read/write through histRef (stable across renders) so the polling
            # interval accumulates instead of freezing on a stale `history`
            # closure. Avoid a negative slice ([-400:]) too -- the client
            # transpiler mishandles it (returns []).
            combined = prevBuf + [newPoint];
            startIdx = max(0, len(combined) - 400);
            trimmed = [];
            idx = 0;
            for p in combined {
                if idx >= startIdx {
                    trimmed.append(p);
                }
                idx += 1;
            }
            histRef.current = trimmed;
            history = trimmed;
        }
        isLoading = False;
    }

    useEffect(
        lambda {
            loadMetrics();
            return;
        },
        []
    );

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

    def getBarHeight(value: float, maxVal: float, minPct: int = 0) -> str {
        if maxVal == 0 {
            return "0%";
        }
        pct = min(100.0, (value / maxVal) * 100);
        # Floor any non-zero value to a visible sliver so a busy interval
        # never rounds away to 0% when a single tall bar dominates the scale.
        if value > 0 and pct < minPct {
            pct = minPct;
        }
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

    def formatSpan(secs: float) -> str {
        if secs < 60 {
            return str(int(secs)) + "s";
        }
        if secs < 3600 {
            return str(int(secs / 60)) + "m " + str(int(secs % 60)) + "s";
        }
        hours = int(secs / 3600);
        mins = int((secs % 3600) / 60);
        return str(hours) + "h " + str(mins) + "m";
    }

    def formatUptime(startTimeVal: float) -> str {
        if startTimeVal == 0 {
            return "N/A";
        }
        return formatSpan(Date.now() / 1000 - startTimeVal);
    }

    def formatLatency(secs: float) -> str {
        if secs <= 0 {
            return "0ms";
        }
        if secs < 0.001 {
            return str(Math.round(secs * 1000000)) + "us";
        }
        if secs < 1 {
            ms = secs * 1000;
            if ms < 10 {
                return str(Math.round(ms * 10) / 10) + "ms";
            }
            return str(Math.round(ms)) + "ms";
        }
        return str(Math.round(secs * 100) / 100) + "s";
    }

    def formatPercentile(p: dict) -> str {
        if not p["known"] {
            return "--";
        }
        if p["over"] {
            return "> " + formatLatency(p["value"]);
        }
        return formatLatency(p["value"]);
    }

    def niceCeil(v: float) -> float {
        if v <= 1 {
            return 1.0;
        }
        if v <= 2 {
            return 2.0;
        }
        if v <= 5 {
            return 5.0;
        }
        return Math.ceil(v / 10) * 10.0;
    }

    def chartLine(points: list, maxV: float) -> str {
        n = len(points);
        if n == 0 {
            return "";
        }
        mv = maxV;
        if mv <= 0 {
            mv = 1.0;
        }
        out = "";
        i = 0;
        for p in points {
            x = 44.0 + 294.0;
            if n > 1 {
                x = 44.0 + (i / (n - 1) * 588.0);
            }
            y = 96.0 - ((p["rate"] or 0.0) / mv * 86.0);
            if out {
                out = out + " ";
            }
            out = out + str(round(x, 1)) + "," + str(round(y, 1));
            i = i + 1;
        }
        return out;
    }

    def errorMarks(points: list, maxE: float) -> list {
        n = len(points);
        out = [];
        if n == 0 or maxE <= 0 {
            return out;
        }
        i = 0;
        for p in points {
            errs = p["errs"] or 0;
            if errs > 0 {
                x = 44.0 + 294.0;
                if n > 1 {
                    x = 44.0 + (i / (n - 1) * 588.0);
                }
                out.append(
                    {"x": round(x, 1), "h": round(4.0 + (errs / maxE) * 7.0, 1)}
                );
            }
            i = i + 1;
        }
        return out;
    }

    def chartArea(points: list, maxV: float) -> str {
        line = chartLine(points, maxV);
        if not line {
            return "";
        }
        return "44.0,96.0 " + line + " 632.0,96.0";
    }

    def windowLabel -> str {
        if windowSecs >= 900 {
            return "15m";
        }
        if windowSecs >= 300 {
            return "5m";
        }
        return "60s";
    }

    def getEndpointRows -> list {
        rows = [];
        for r in (summary["endpoints"] or []) {
            isApp = r["kind"] == "app";
            if scope == "all"
                or (scope == "app" and isApp)
                or (scope == "other" and not isApp) {
                rows.append(r);
            }
        }
        return rows;
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

    activeReqs = summary["active_requests"] or 0;

    scopeKey = "app";
    scopeErrKey = "appErr";
    if scope == "all" {
        scopeKey = "all";
        scopeErrKey = "allErr";
    } elif scope == "other" {
        scopeKey = "other";
        scopeErrKey = "otherErr";
    }

    windowStartMs = Date.now() - (windowSecs * 1000);
    windowPoints = [];
    for h in history {
        if h["time"] >= windowStartMs {
            windowPoints.append(h);
        }
    }

    ratePoints = [];
    maxRate = 0.0;
    ptIdx = 0;
    for h in windowPoints {
        if ptIdx > 0 {
            prevPt = windowPoints[ptIdx - 1];
            dt = (h["time"] - prevPt["time"]) / 1000.0;
            if dt > 0 {
                dReq = h[scopeKey] - prevPt[scopeKey];
                dErr = h[scopeErrKey] - prevPt[scopeErrKey];
                if dReq < 0 {
                    dReq = 0;
                }
                if dErr < 0 {
                    dErr = 0;
                }
                rate = dReq / dt;
                ratePoints.append({"rate": rate, "errs": dErr});
                if rate > maxRate {
                    maxRate = rate;
                }
            }
        }
        ptIdx += 1;
    }

    windowReqs = 0;
    elapsedSecs = 0.0;
    nWin = len(windowPoints);
    if nWin > 1 {
        firstPt = windowPoints[0];
        lastPt = windowPoints[nWin - 1];
        windowReqs = lastPt[scopeKey] - firstPt[scopeKey];
        if windowReqs < 0 {
            windowReqs = 0;
        }
        elapsedSecs = (lastPt["time"] - firstPt["time"]) / 1000.0;
    }
    throughput = 0.0;
    if elapsedSecs > 0 {
        throughput = windowReqs / elapsedSecs;
    }
    throughputDisplay = Math.round(throughput * 10) / 10;
    maxIntervalErrs = 0;
    for rp in ratePoints {
        if rp["errs"] > maxIntervalErrs {
            maxIntervalErrs = rp["errs"];
        }
    }
    chartMax = niceCeil(maxRate);
    errMarks = errorMarks(ratePoints, maxIntervalErrs);
    chartLinePts = chartLine(ratePoints, chartMax);
    chartAreaPts = chartArea(ratePoints, chartMax);
    chartIsEmpty = len(ratePoints) == 0 or maxRate <= 0;
    collecting = nWin < 2;
    bufferAgeSecs = 0.0;
    if len(history) > 0 {
        bufferAgeSecs = (Date.now() - history[0]["time"]) / 1000.0;
    }
    spanLabel = windowLabel();
    if bufferAgeSecs < windowSecs {
        spanLabel = formatSpan(elapsedSecs);
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

    gcTotal = gcGen0 + gcGen1 + gcGen2;
    gcNote = "No GC collections recorded yet.";
    if gcTotal > 0 {
        gcBusiest = "gen 0 (young)";
        if gcGen2 >= gcGen1 and gcGen2 >= gcGen0 {
            gcBusiest = "gen 2 (old)";
        } elif gcGen1 >= gcGen0 {
            gcBusiest = "gen 1 (mid)";
        }
        gcNote = str(gcTotal)
            + " objects collected since start; "
            + gcBusiest
            + " accounts for the most.";
    }

    endpointRows = getEndpointRows();
    allScopes = summary["scopes"] or {};
    scopeStats = allScopes[scopeKey] or {};
    unknownP = {"value": 0.0, "over": False, "known": False};
    scopeP50 = scopeStats["p50"] or unknownP;
    scopeP95 = scopeStats["p95"] or unknownP;
    scopeP99 = scopeStats["p99"] or unknownP;
    histGroups = scopeStats["distribution"] or [];
    maxGroupCount = 1.0;
    for g in histGroups {
        if g["count"] > maxGroupCount {
            maxGroupCount = g["count"];
        }
    }

    scopeReqs = scopeStats["requests"] or 0;
    scopeServerErrs = scopeStats["server_errors"] or 0;
    scopeClientErrs = scopeStats["client_errors"] or 0;
    scopeFailedCount = scopeServerErrs + scopeClientErrs;
    maxRowCount = 1;
    for r in endpointRows {
        if r["count"] > maxRowCount {
            maxRowCount = r["count"];
        }
    }
    scopeErrRate = 0.0;
    if scopeReqs > 0 {
        scopeErrRate = (scopeFailedCount / scopeReqs) * 100;
    }
    scopeErrDisplay = Math.round(scopeErrRate * 10) / 10;

    memUsagePercent = 0;
    if virtualMem > 0 {
        memUsagePercent = int((residentMem / virtualMem) * 100);
    }

    scopeOptions = [
        {"key": "app", "label": "App", "title": "Your app's routes"},
        {
            "key": "other",
            "label": "Platform",
            "title": "Admin portal, health probes, /metrics, /docs and /openapi.json"
        },
        {"key": "all", "label": "All", "title": "Everything this process served"}
    ];
    windowOptions = [
        {"secs": 60, "label": "60s"},
        {"secs": 300, "label": "5m"},
        {"secs": 900, "label": "15m"}
    ];

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

    <div className="space-y-6">
        <PageHeader icon={Activity} title="Metrics" live={True} right={headerRight}/>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="bg-surface border border-line rounded-lg p-4 shadow-sm">
                <div className="flex items-center justify-between">
                    <span className="text-xs text-faint">Throughput</span>
                    <Globe className="w-4 h-4 text-faint"/>
                </div>
                <div className="text-2xl font-semibold text-fg mt-2 tabular-nums">
                    {throughputDisplay}
                    <span className="text-base text-faint"> req/s</span>
                </div>
                <div className="text-xs text-faint mt-1">
                    {"collecting first sample"
                        if collecting
                        else (str(windowReqs) + " in last " + spanLabel)}
                </div>
            </div>
            <div className="bg-surface border border-line rounded-lg p-4 shadow-sm">
                <div className="flex items-center justify-between">
                    <span className="text-xs text-faint">p95 latency</span>
                    <Clock className="w-4 h-4 text-faint"/>
                </div>
                <div
                    className={"text-2xl font-semibold mt-2 tabular-nums "
                        + ("text-warning" if scopeP95["value"] > 1 else "text-fg")}
                >
                    {formatPercentile(scopeP95)}
                </div>
                <div className="text-xs text-faint mt-1">
                    {"p50 "
                        + formatPercentile(scopeP50)
                        + " · p99 "
                        + formatPercentile(scopeP99)}
                </div>
            </div>
            <div className="bg-surface border border-line rounded-lg p-4 shadow-sm">
                <div className="flex items-center justify-between">
                    <span className="text-xs text-faint">Error rate</span>
                    <AlertTriangle className="w-4 h-4 text-faint"/>
                </div>
                <div
                    className={"text-2xl font-semibold mt-2 tabular-nums "
                        + ("text-danger" if scopeFailedCount > 0 else "text-fg")}
                >
                    {scopeErrDisplay}
                    <span className="text-base text-faint">%</span>
                </div>
                <div className="text-xs text-faint mt-1">
                    {"5xx "
                        + str(scopeServerErrs)
                        + " · 4xx "
                        + str(scopeClientErrs)
                        + " of "
                        + str(scopeReqs)
                        + " since restart"}
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
                <div className="bg-surface border border-line rounded-lg p-5 shadow-sm">
                    <div className="flex items-center justify-between gap-3 mb-4">
                        <div className="flex items-center gap-2">
                            <Globe className="w-4 h-4 text-muted"/>
                            <span className="text-sm font-medium text-fg">
                                HTTP traffic
                            </span>
                        </div>
                        <div className="flex items-center gap-3">
                            <div className="flex gap-1">
                                {[
                                    <button
                                        key={opt["key"]}
                                        title={opt["title"]}
                                        onClick={lambda { scope = opt["key"]; }}
                                        className={"px-2 py-0.5 rounded text-[11px] border transition-colors "
                                            + (
                                                "bg-accent-weak border-accent-line text-accent"
                                                    if scope == opt["key"]
                                                    else "border-line text-muted hover:text-fg"
                                            )}
                                    >
                                        {opt["label"]}
                                    </button> for opt in scopeOptions
                                ]}
                            </div>
                            <div className="flex gap-1">
                                {[
                                    <button
                                        key={str(opt["secs"])}
                                        onClick={lambda { windowSecs = int(
                                            opt["secs"]
                                        ); }}
                                        className={"px-2 py-0.5 rounded text-[11px] border transition-colors "
                                            + (
                                                "bg-accent-weak border-accent-line text-accent"
                                                    if windowSecs == opt["secs"]
                                                    else "border-line text-muted hover:text-fg"
                                            )}
                                    >
                                        {opt["label"]}
                                    </button> for opt in windowOptions
                                ]}
                            </div>
                        </div>
                    </div>
                    <div className="flex items-baseline justify-between mb-1">
                        <span
                            className="text-[10px] uppercase tracking-wider text-faint"
                        >
                            Throughput · req/s · last {spanLabel}
                        </span>
                        <span className="text-[11px] text-faint">
                            {str(activeReqs) + " in flight"}
                        </span>
                    </div>
                    {chartIsEmpty
                        and <div
                            className="border border-dashed border-line rounded-lg px-4 py-6 text-center"
                        >
                            <div className="text-xs font-medium text-fg">
                                {"Collecting, first sample in a few seconds"
                                    if collecting
                                    else ("No traffic in the last " + spanLabel)}
                            </div>
                            <div className="text-[11px] text-faint mt-1">
                                {"A rate needs two samples."
                                    if collecting
                                    else "Counters are alive; this window is empty."}
                            </div>
                        </div>}
                    {not chartIsEmpty
                        and <svg
                            viewBox="0 0 640 140"
                            className="w-full h-32 overflow-visible"
                            preserveAspectRatio="none"
                        >
                            <line
                                x1="44"
                                y1="10"
                                x2="632"
                                y2="10"
                                stroke="var(--line)"
                                strokeWidth="1"
                            ></line>
                            <line
                                x1="44"
                                y1="53"
                                x2="632"
                                y2="53"
                                stroke="var(--line)"
                                strokeWidth="1"
                            ></line>
                            <line
                                x1="44"
                                y1="96"
                                x2="632"
                                y2="96"
                                stroke="var(--line-strong)"
                                strokeWidth="1"
                            ></line>
                            <text
                                x="38"
                                y="14"
                                textAnchor="end"
                                fill="var(--faint)"
                                fontSize="9"
                            >
                                {chartMax}
                            </text>
                            <text
                                x="38"
                                y="99"
                                textAnchor="end"
                                fill="var(--faint)"
                                fontSize="9"
                            >
                                0
                            </text>
                            <text x="44" y="112" fill="var(--faint)" fontSize="9">
                                {"-" + spanLabel}
                            </text>
                            <text
                                x="632"
                                y="110"
                                textAnchor="end"
                                fill="var(--faint)"
                                fontSize="9"
                            >
                                now
                            </text>
                            <polygon
                                points={chartAreaPts}
                                fill="var(--accent)"
                                opacity="0.13"
                            ></polygon>
                            <polyline
                                points={chartLinePts}
                                fill="none"
                                stroke="var(--accent)"
                                strokeWidth="2"
                                strokeLinejoin="round"
                                strokeLinecap="round"
                            ></polyline>
                            <text
                                x="38"
                                y="134"
                                textAnchor="end"
                                fill="var(--faint)"
                                fontSize="9"
                            >
                                err
                            </text>
                            <line
                                x1="44"
                                y1="136"
                                x2="632"
                                y2="136"
                                stroke="var(--line)"
                                strokeWidth="1"
                            ></line>
                            {[
                                <rect
                                    key={str(mk["x"])}
                                    x={mk["x"] - 1.5}
                                    y={136 - mk["h"]}
                                    width="3"
                                    height={mk["h"]}
                                    rx="1.5"
                                    fill="var(--danger)"
                                ></rect> for mk in errMarks
                            ]}
                        </svg>}
                    <div className="border-t border-line pt-4 mt-4">
                        <div className="flex items-baseline justify-between mb-3">
                            <span
                                className="text-[10px] uppercase tracking-wider text-faint"
                            >
                                Latency distribution · since restart
                            </span>
                            <span className="text-[11px] text-faint">
                                {str(scopeReqs) + " requests"}
                            </span>
                        </div>
                        <div className="space-y-1.5">
                            {[
                                <div
                                    key={g["label"]}
                                    className="flex items-center gap-3 text-[11px]"
                                >
                                    <span
                                        className="w-24 text-right font-mono text-muted shrink-0"
                                    >
                                        {g["label"]}
                                    </span>
                                    <div
                                        className="flex-1 bg-surface-2 rounded h-3.5 overflow-hidden"
                                    >
                                        <div
                                            className="bg-accent h-3.5 rounded"
                                            style={{
                                                "width": getBarHeight(
                                                    g["count"], maxGroupCount
                                                )
                                            }}
                                        ></div>
                                    </div>
                                    <span
                                        className="w-10 text-right font-mono text-fg tabular-nums"
                                    >
                                        {int(g["count"])}
                                    </span>
                                </div> for g in histGroups
                            ]}
                        </div>
                    </div>
                    <div className="border-t border-line pt-4 mt-4">
                        <div className="flex items-baseline justify-between mb-3">
                            <span
                                className="text-[10px] uppercase tracking-wider text-faint"
                            >
                                {str(len(endpointRows)) + " endpoints · since restart"}
                            </span>
                            <span className="text-[11px] text-faint">
                                sorted by p95
                            </span>
                        </div>
                        <div
                            className="flex items-center gap-3 text-[10px] uppercase tracking-wider text-faint pb-2 border-b border-line"
                        >
                            <span className="flex-1">Endpoint</span>
                            <span className="w-12 text-right">Reqs</span>
                            <span className="w-12 text-right">Err %</span>
                            <span className="w-14 text-right">p50</span>
                            <span className="w-14 text-right">p95</span>
                            <span className="w-16"></span>
                        </div>
                        <div className="space-y-2 max-h-72 overflow-y-auto pr-2 pt-2">
                            {[
                                <div
                                    key={req["method"] + " " + req["path"]}
                                    className="flex items-center gap-3 text-xs"
                                >
                                    <span
                                        className="flex-1 flex items-center gap-2 min-w-0"
                                    >
                                        <span className={getMethodBadge(req["method"])}>
                                            {req["method"]}
                                        </span>
                                        <span className="font-mono text-muted truncate">
                                            {req["path"]}
                                        </span>
                                    </span>
                                    <span
                                        className="w-12 text-right font-mono text-fg tabular-nums"
                                    >
                                        {req["count"]}
                                    </span>
                                    <span
                                        className={"w-12 text-right font-mono tabular-nums "
                                            + (
                                                "text-danger"
                                                    if req["failed"] > 0
                                                    else "text-faint"
                                            )}
                                    >
                                        {Math.round(
                                            (req["failed"] / req["count"]) * 1000
                                        )
                                            / 10
                                            if req["count"] > 0
                                            else 0}
                                    </span>
                                    <span
                                        className="w-14 text-right font-mono text-muted tabular-nums"
                                    >
                                        {formatPercentile(req["p50"])}
                                    </span>
                                    <span
                                        className={"w-14 text-right font-mono tabular-nums "
                                            + (
                                                "text-warning"
                                                    if req["p95"]["value"] > 1
                                                    else "text-fg"
                                            )}
                                    >
                                        {formatPercentile(req["p95"])}
                                    </span>
                                    <div className="w-16 bg-surface-2 rounded-full h-1">
                                        <div
                                            className="bg-accent h-1 rounded-full"
                                            style={{
                                                "width": getBarHeight(
                                                    req["count"], maxRowCount
                                                )
                                            }}
                                        ></div>
                                    </div>
                                </div> for req in endpointRows
                            ]}
                        </div>
                    </div>
                </div>
                <div className="bg-surface border border-line rounded-lg p-5 shadow-sm">
                    <div className="flex items-center gap-2 mb-4">
                        <Recycle className="w-4 h-4 text-muted"/>
                        <span className="text-sm font-medium text-fg">
                            Garbage collection
                        </span>
                    </div>
                    <div className="grid grid-cols-3 gap-6">
                        <div className="text-center">
                            <div className="h-32 flex items-end justify-center mb-2">
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
                            <div className="h-32 flex items-end justify-center mb-2">
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
                            <div className="h-32 flex items-end justify-center mb-2">
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
                            <span className="text-muted">{gcNote}</span>
                        </div>
                    </div>
                </div>
            </div>
            <div className="space-y-6">
                <div className="bg-surface border border-line rounded-lg p-5 shadow-sm">
                    <div className="flex items-center gap-2 mb-4">
                        <MemoryStick className="w-4 h-4 text-muted"/>
                        <span className="text-sm font-medium text-fg">Memory</span>
                    </div>
                    <div className="relative w-32 h-32 mx-auto mb-4">
                        <svg className="w-full h-full -rotate-90" viewBox="0 0 100 100">
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
                <div className="bg-surface border border-line rounded-lg p-5 shadow-sm">
                    <div className="flex items-center gap-2 mb-4">
                        <Cpu className="w-4 h-4 text-muted"/>
                        <span className="text-sm font-medium text-fg">CPU time</span>
                    </div>
                    <div className="text-center">
                        <div
                            className="text-3xl font-semibold text-fg font-mono tabular-nums"
                        >
                            {str(int(cpuSeconds * 100) / 100)}s
                        </div>
                        <div className="text-xs text-faint mt-2">Total CPU seconds</div>
                    </div>
                </div>
                <div className="bg-surface border border-line rounded-lg p-5 shadow-sm">
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
                            <span className="text-faint text-lg">/{int(maxFds)}</span>
                        </div>
                        <div className="text-xs text-faint mt-2">Open / max</div>
                    </div>
                </div>
                <div className="bg-surface border border-line rounded-lg p-5 shadow-sm">
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
    </div>
}
