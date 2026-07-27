"""Service detail panel: one service's pods + resource history.

Rendered by ServicesPage when a service card is clicked. Receives the already
filtered data (the service's workload row, its pods, and its CPU/memory series)
as props so it stays presentational and does no fetching of its own.

Resource charts use a dependency-free SVG approach (path strings built by
str-returning helpers, since cl mode drops args to JSX-returning helpers).
Per-service traffic (req/s, error %, latency) is not
yet available from Prometheus, so the Traffic card renders placeholders until
that lands.
"""

cl import from "lucide-react" { ChevronLeft, Boxes, Activity, Gauge }

cl {
    import from ....utils.format { formatBytes, formatCores, formatAge }

    def:pub ServiceDetail(
        service: dict,
        pods: list[dict],
        cpu: list[dict],
        memory: list[dict],
        onBack: any
    ) -> JsxElement {
        def maxOf(points: list[dict]) -> float {
            mv = 0.0;
            for p in points {
                v = p["v"] or 0;
                if v > mv {
                    mv = v;
                }
            }
            return mv;
        }

        def lastOf(points: list[dict]) -> float {
            n = len(points);
            if n == 0 {
                return 0.0;
            }
            return points[n - 1]["v"] or 0;
        }

        # Drawing area inside the 900x240 viewBox: x:[90,880] y:[20,210].
        def chartLine(points: list[dict], maxV: float) -> str {
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
                x = 90.0 + 395.0;
                if n > 1 {
                    x = 90.0 + (i / (n - 1) * 790.0);
                }
                y = 210.0 - ((p["v"] or 0) / mv * 190.0);
                if out {
                    out = out + " ";
                }
                out = out + str(round(x, 1)) + "," + str(round(y, 1));
                i = i + 1;
            }
            return out;
        }

        def chartArea(points: list[dict], maxV: float) -> str {
            line = chartLine(points, maxV);
            if not line {
                return "";
            }
            return "90.0,210.0 " + line + " 880.0,210.0";
        }

        statusClasses = {
            "Healthy": "bg-success-weak text-success border-success/40",
            "Starting": "bg-warning-weak text-warning border-warning/40",
            "Unstable": "bg-warning-weak text-warning border-warning/40",
            "Broken": "bg-danger-weak text-danger border-danger/40"
        };
        statusDotClasses = {
            "Healthy": "bg-success",
            "Starting": "bg-warning",
            "Unstable": "bg-warning",
            "Broken": "bg-danger"
        };
        phaseToStatus = {
            "Running": "Healthy",
            "Pending": "Starting",
            "Succeeded": "Healthy",
            "Failed": "Broken",
            "Unknown": "Unknown"
        };

        name = service["name"] or "";
        kind = service["kind"] or "Workload";
        status = service["status"] or "Unknown";
        readyN = service["replicas_ready"] or 0;
        desiredN = service["replicas_desired"] or 0;
        restarts = service["restarts_last_hour"] or 0;

        cpuMaxV = maxOf(cpu);
        memMaxV = maxOf(memory);
        cpuLine = chartLine(cpu, cpuMaxV);
        cpuArea = chartArea(cpu, cpuMaxV);
        memLine = chartLine(memory, memMaxV);
        memArea = chartArea(memory, memMaxV);
        sparse = len(cpu) < 5;

        gridStroke = "var(--line)";
        gridStrongStroke = "var(--line-strong)";
        axisFill = "var(--muted)";
        cpuLineColor = "#0d9488";
        cpuAreaFill = "rgba(13,148,136,0.15)";
        memLineColor = "#7c3aed";
        memAreaFill = "rgba(124,58,237,0.15)";

        headerStats = [
            {"label": "Kind", "value": kind},
            {"label": "Replicas", "value": str(readyN) + " / " + str(desiredN)},
            {"label": "CPU", "value": formatCores(service["cpu_cores"] or 0)},
            {"label": "Memory", "value": formatBytes(service["memory_bytes"] or 0)},
            {"label": "Restarts (1h)", "value": str(restarts)},
            {"label": "Age", "value": formatAge(service["created"] or 0)}
        ];

        traffic = service["traffic"] or {};
        isRouted = traffic["routed"] or False;
        trafficStats = [
            {
                "label": "Requests",
                "value": (str(traffic["requests_per_sec"] or 0) + " r/s")
                    if isRouted
                    else "-",
                "sub": "per second"
            },
            {
                "label": "Errors",
                "value": (str(traffic["error_rate_pct"] or 0) + "%")
                    if isRouted
                    else "-",
                "sub": "of requests"
            },
            {
                "label": "Response time",
                "value": (str(traffic["p95_latency_ms"] or 0) + " ms")
                    if isRouted
                    else "-",
                "sub": "p95 latency"
            }
        ];

        return
            <div className="space-y-4">
                <div className="flex items-center gap-3">
                    <button
                        onClick={onBack}
                        className="inline-flex items-center gap-1 text-sm text-muted hover:text-fg transition-colors"
                    >
                        <ChevronLeft className="w-4 h-4"/>
                        Services
                    </button>
                    <span className="text-faint">/</span>
                    <div className="flex items-center gap-2">
                        <Boxes className="w-4 h-4 text-accent"/>
                        <h1 className="text-lg font-semibold text-fg">{name}</h1>
                    </div>
                    <span
                        className={"inline-flex items-center gap-1.5 px-2 py-0.5 rounded text-xs font-medium border " + str(
                            statusClasses[status]
                            or "bg-surface-2 text-muted border-line"
                        )}
                    >
                        <span
                            className={"w-1.5 h-1.5 rounded-full " + str(
                                statusDotClasses[status] or "bg-faint"
                            )}
                        ></span>
                        {status}
                    </span>
                </div>
                <div className="grid grid-cols-2 md:grid-cols-6 gap-3">
                    {[
                        <div
                            key={s["label"]}
                            className="bg-surface border border-line rounded-lg p-3 shadow-sm"
                        >
                            <p className="text-xs text-faint uppercase tracking-wider">
                                {s["label"]}
                            </p>
                            <p
                                className="text-base font-semibold text-fg mt-1 tabular-nums"
                            >
                                {s["value"]}
                            </p>
                        </div> for s in headerStats
                    ]}
                </div>
                <div className="bg-surface border border-line rounded-lg p-4 shadow-sm">
                    <div className="flex items-center gap-2 mb-3">
                        <Gauge className="w-4 h-4 text-faint"/>
                        <h2 className="text-sm font-medium text-fg">Traffic</h2>
                        <span
                            className="ml-auto text-[11px] text-faint border border-line rounded-full px-2 py-0.5"
                        >
                            {"Live (last 60s)" if isRouted else "No gateway traffic"}
                        </span>
                    </div>
                    <div className="grid grid-cols-3 gap-3">
                        {[
                            <div key={t["label"]}>
                                <p
                                    className="text-xs text-faint uppercase tracking-wider"
                                >
                                    {t["label"]}
                                </p>
                                <p
                                    className={"text-2xl font-semibold mt-1 tabular-nums " + (
                                        "text-fg" if isRouted else "text-faint"
                                    )}
                                >
                                    {t["value"]}
                                </p>
                                <p className="text-xs text-faint mt-1">{t["sub"]}</p>
                            </div> for t in trafficStats
                        ]}
                    </div>
                </div>
                {sparse
                and <div
                    className="bg-warning-weak border border-warning/30 rounded-lg px-4 py-3"
                >
                    <p className="text-xs text-warning">
                        Collecting data. CPU and memory history fills in over the next several minutes.
                    </p>
                </div>}
                <div className="bg-surface border border-line rounded-lg p-4 shadow-sm">
                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                        <div>
                            <div className="flex items-center justify-between mb-1">
                                <span className="text-xs font-medium text-muted">
                                    CPU
                                </span>
                                <span
                                    className="text-xs font-mono tabular-nums"
                                    style={{"color": cpuLineColor}}
                                >
                                    {formatCores(lastOf(cpu))}
                                </span>
                            </div>
                            <svg viewBox="0 0 900 240" className="w-full" role="img">
                                <line
                                    x1="90"
                                    y1="20"
                                    x2="880"
                                    y2="20"
                                    stroke={gridStroke}
                                    strokeWidth="1"
                                />
                                <line
                                    x1="90"
                                    y1="115"
                                    x2="880"
                                    y2="115"
                                    stroke={gridStroke}
                                    strokeWidth="1"
                                />
                                <line
                                    x1="90"
                                    y1="210"
                                    x2="880"
                                    y2="210"
                                    stroke={gridStrongStroke}
                                    strokeWidth="1"
                                />
                                <text
                                    x="82"
                                    y="24"
                                    textAnchor="end"
                                    fill={axisFill}
                                    fontSize="15"
                                >
                                    {formatCores(cpuMaxV)}
                                </text>
                                <text
                                    x="82"
                                    y="214"
                                    textAnchor="end"
                                    fill={axisFill}
                                    fontSize="15"
                                >
                                    0
                                </text>
                                <text x="90" y="234" fill={axisFill} fontSize="15">
                                    1h ago
                                </text>
                                <text
                                    x="880"
                                    y="234"
                                    textAnchor="end"
                                    fill={axisFill}
                                    fontSize="15"
                                >
                                    now
                                </text>
                                <polygon
                                    points={cpuArea}
                                    fill={cpuAreaFill}
                                    stroke="none"
                                />
                                <polyline
                                    points={cpuLine}
                                    fill="none"
                                    stroke={cpuLineColor}
                                    strokeWidth="2.5"
                                />
                            </svg>
                        </div>
                        <div>
                            <div className="flex items-center justify-between mb-1">
                                <span className="text-xs font-medium text-muted">
                                    Memory
                                </span>
                                <span
                                    className="text-xs font-mono tabular-nums"
                                    style={{"color": memLineColor}}
                                >
                                    {formatBytes(lastOf(memory))}
                                </span>
                            </div>
                            <svg viewBox="0 0 900 240" className="w-full" role="img">
                                <line
                                    x1="90"
                                    y1="20"
                                    x2="880"
                                    y2="20"
                                    stroke={gridStroke}
                                    strokeWidth="1"
                                />
                                <line
                                    x1="90"
                                    y1="115"
                                    x2="880"
                                    y2="115"
                                    stroke={gridStroke}
                                    strokeWidth="1"
                                />
                                <line
                                    x1="90"
                                    y1="210"
                                    x2="880"
                                    y2="210"
                                    stroke={gridStrongStroke}
                                    strokeWidth="1"
                                />
                                <text
                                    x="82"
                                    y="24"
                                    textAnchor="end"
                                    fill={axisFill}
                                    fontSize="15"
                                >
                                    {formatBytes(memMaxV)}
                                </text>
                                <text
                                    x="82"
                                    y="214"
                                    textAnchor="end"
                                    fill={axisFill}
                                    fontSize="15"
                                >
                                    0
                                </text>
                                <text x="90" y="234" fill={axisFill} fontSize="15">
                                    1h ago
                                </text>
                                <text
                                    x="880"
                                    y="234"
                                    textAnchor="end"
                                    fill={axisFill}
                                    fontSize="15"
                                >
                                    now
                                </text>
                                <polygon
                                    points={memArea}
                                    fill={memAreaFill}
                                    stroke="none"
                                />
                                <polyline
                                    points={memLine}
                                    fill="none"
                                    stroke={memLineColor}
                                    strokeWidth="2.5"
                                />
                            </svg>
                        </div>
                    </div>
                </div>
                <div
                    className="bg-surface border border-line rounded-lg overflow-hidden shadow-sm"
                >
                    <div
                        className="flex items-center gap-2 px-4 py-3 border-b border-line"
                    >
                        <Activity className="w-4 h-4 text-faint"/>
                        <h2 className="text-sm font-medium text-fg">Pods</h2>
                        <span className="text-xs text-faint">({len(pods)})</span>
                    </div>
                    {len(pods) == 0
                    and <div className="p-6 text-center text-sm text-faint">
                        No pods for this service.
                    </div>}
                    {len(pods) > 0
                    and <div className="overflow-x-auto">
                        <table className="w-full text-sm">
                            <thead
                                className="text-xs text-faint uppercase tracking-wider bg-surface-2"
                            >
                                <tr>
                                    <th className="text-left px-4 py-2 font-medium">
                                        Pod
                                    </th>
                                    <th className="text-left px-4 py-2 font-medium">
                                        Phase
                                    </th>
                                    <th className="text-left px-4 py-2 font-medium">
                                        Node
                                    </th>
                                    <th className="text-left px-4 py-2 font-medium">
                                        CPU
                                    </th>
                                    <th className="text-left px-4 py-2 font-medium">
                                        Memory
                                    </th>
                                    <th className="text-left px-4 py-2 font-medium">
                                        Restarts (1h)
                                    </th>
                                    <th className="text-left px-4 py-2 font-medium">
                                        Age
                                    </th>
                                </tr>
                            </thead>
                            <tbody>
                                {[
                                    <tr
                                        key={p["name"]}
                                        className="border-t border-line"
                                    >
                                        <td className="px-4 py-2 text-fg">
                                            {p["name"]}
                                        </td>
                                        <td className="px-4 py-2">
                                            <span
                                                className={"inline-flex items-center gap-1.5 px-2 py-0.5 rounded text-xs font-medium border " + str(
                                                    statusClasses[
                                                        phaseToStatus[p["phase"]]
                                                        or p["phase"]
                                                    ]
                                                    or "bg-surface-2 text-muted border-line"
                                                )}
                                            >
                                                <span
                                                    className={"w-1.5 h-1.5 rounded-full " + str(
                                                        statusDotClasses[
                                                            phaseToStatus[p["phase"]]
                                                            or p["phase"]
                                                        ]
                                                        or "bg-faint"
                                                    )}
                                                ></span>
                                                {phaseToStatus[p["phase"]]
                                                or p["phase"]}
                                            </span>
                                        </td>
                                        <td className="px-4 py-2 text-muted">
                                            {p["node"]}
                                        </td>
                                        <td
                                            className="px-4 py-2 text-muted tabular-nums"
                                        >
                                            {formatCores(p["cpu_cores"] or 0)}
                                        </td>
                                        <td
                                            className="px-4 py-2 text-muted tabular-nums"
                                        >
                                            {formatBytes(p["memory_bytes"] or 0)}
                                        </td>
                                        <td
                                            className="px-4 py-2 text-muted tabular-nums"
                                        >
                                            {p["restarts_last_hour"]}
                                        </td>
                                        <td
                                            className="px-4 py-2 text-muted tabular-nums"
                                        >
                                            {formatAge(p["created"] or 0)}
                                        </td>
                                    </tr> for p in pods
                                ]}
                            </tbody>
                        </table>
                    </div>}
                </div>
            </div>;
    }
}
