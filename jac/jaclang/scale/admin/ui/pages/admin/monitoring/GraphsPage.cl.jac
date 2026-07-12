"""Usage page: CPU + memory history per workload.

Pulls /admin/workloads/timeseries (one bulk call returning cpu+memory series
for every workload) and renders dependency-free SVG line charts with labeled
axes (Y value scale, X time range) and gridlines. A time-range dropdown
(1h / 6h / 24h / 7d) re-fetches at a coarser step.

Charts use a wide viewBox (900x260) and w-full with auto height so they scale
to the full card width without letterboxing. One workload per row keeps each
chart large and readable. Path strings are built by str-returning helpers
because cl mode drops args to JSX-returning helper functions.
"""

cl import from "lucide-react" { TrendingUp, Activity }

cl {
    import from react { useEffect }
    import from ....components.common.PageHeader { PageHeader }
    import from ....context.AuthContext { useAuth }
    import from ....services.workloadsService { getWorkloadsTimeseries }

    def:pub GraphsPage -> JsxElement {
        has isLoading: bool = True,
            metricsAvailable: bool = True,
            unavailableReason: str = "",
            workloads: list = [],
            rangeMinutes: int = 60;

        auth = useAuth();

        async def loadAll {
            res = await getWorkloadsTimeseries(auth["authToken"], rangeMinutes);
            data = {};
            if res["ok"] and res["data"] {
                data = res["data"];
            }
            metricsAvailable = bool(data["metrics_available"]);
            unavailableReason = data["reason"] or "";
            workloads = data["workloads"] or [];
            isLoading = False;
        }

        useEffect(lambda { loadAll(); }, [rangeMinutes]);

        useEffect(
            lambda -> any {
                interval = setInterval(lambda { loadAll(); }, 30000);
                return lambda { clearInterval(interval); };
            },
            [rangeMinutes]
        );

        def maxOf(points: list) -> float {
            mv = 0.0;
            for p in points {
                if p["v"] > mv {
                    mv = p["v"];
                }
            }
            return mv;
        }

        def lastOf(points: list) -> float {
            n = len(points);
            if n == 0 {
                return 0.0;
            }
            return points[n - 1]["v"];
        }

        # Drawing area inside the 900x240 viewBox: x:[90,880] y:[20,210].
        # Left margin (90) holds Y labels, bottom margin holds X labels.
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
                x = 90.0 + 395.0;
                if n > 1 {
                    x = 90.0 + (i / (n - 1) * 790.0);
                }
                y = 210.0 - (p["v"] / mv * 190.0);
                if out {
                    out = out + " ";
                }
                out = out + str(round(x, 1)) + "," + str(round(y, 1));
                i = i + 1;
            }
            return out;
        }

        def chartArea(points: list, maxV: float) -> str {
            line = chartLine(points, maxV);
            if not line {
                return "";
            }
            return "90.0,210.0 " + line + " 880.0,210.0";
        }

        def formatBytes(b: float) -> str {
            if b >= 1073741824 {
                return str(int(b / 10737418.24) / 100) + " GB";
            }
            if b >= 1048576 {
                return str(int(b / 10485.76) / 100) + " MB";
            }
            if b >= 1024 {
                return str(int(b / 10.24) / 100) + " KB";
            }
            return str(int(b)) + " B";
        }

        def formatCores(c: float) -> str {
            if c < 1 {
                return str(int(c * 1000)) + "m";
            }
            return str(int(c * 100) / 100) + " cores";
        }

        def rangeLabel(mins: int) -> str {
            if mins >= 1440 {
                return str(int(mins / 1440)) + "d ago";
            }
            if mins >= 60 {
                return str(int(mins / 60)) + "h ago";
            }
            return str(mins) + "m ago";
        }

        if isLoading {
            return
                <div
                    className="bg-surface border border-line rounded-lg p-8 text-center shadow-sm"
                >
                    <p className="text-sm text-muted">Loading usage...</p>
                </div>;
        }

        if not metricsAvailable {
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
                        Usage is off
                    </h2>
                    <p className="text-sm text-muted">
                        Enable in jac.toml:
                        <span className="font-mono text-fg ml-1">
                            [scale.monitoring] enabled = true
                        </span>
                    </p>
                </div>;
        }

        maxPoints = 0;
        for w in workloads {
            np = len(w["cpu"]);
            if np > maxPoints {
                maxPoints = np;
            }
        }
        sparse = maxPoints < 5;

        cards = [];
        for w in workloads {
            cpuMaxV = maxOf(w["cpu"]);
            memMaxV = maxOf(w["memory"]);
            cards.append(
                {
                    "name": w["name"],
                    "cpuLast": lastOf(w["cpu"]),
                    "memLast": lastOf(w["memory"]),
                    "cpuMaxLabel": formatCores(cpuMaxV),
                    "cpuMidLabel": formatCores(cpuMaxV / 2),
                    "memMaxLabel": formatBytes(memMaxV),
                    "memMidLabel": formatBytes(memMaxV / 2),
                    "cpuLine": chartLine(w["cpu"], cpuMaxV),
                    "cpuArea": chartArea(w["cpu"], cpuMaxV),
                    "memLine": chartLine(w["memory"], memMaxV),
                    "memArea": chartArea(w["memory"], memMaxV)
                }
            );
        }
        startLabel = rangeLabel(rangeMinutes);

        # SVG-only stroke/fill colors. Browsers resolve var(...) inside SVG
        # presentation attributes, so the chart adapts to light/dark via the
        # same tokens as the rest of the page.
        gridStroke = "var(--line)";
        gridStrongStroke = "var(--line-strong)";
        axisFill = "var(--muted)";
        cpuLineColor = "#0d9488";
        cpuAreaFill = "rgba(13,148,136,0.15)";
        memLineColor = "#7c3aed";
        memAreaFill = "rgba(124,58,237,0.15)";

        rangeSelect = <select
            value={str(rangeMinutes)}
            onChange={lambda (e: any) { rangeMinutes = int(e.target.value); }}
            className="bg-surface border border-line rounded px-2 py-1.5 text-sm text-fg"
        >
            <option value="60">Last 1 hour</option>
            <option value="360">Last 6 hours</option>
            <option value="1440">Last 24 hours</option>
            <option value="10080">Last 7 days</option>
        </select>;

        return
            <div className="space-y-4">
                <PageHeader
                    icon={TrendingUp}
                    title="Resource usage"
                    live={True}
                    right={rangeSelect}
                />
                {sparse
                and <div
                    className="bg-warning-weak border border-warning/30 rounded-lg px-4 py-3"
                >
                    <p className="text-xs text-warning">
                        Collecting data. History builds up as the cluster runs, so graphs fill in over the next several minutes. (Prometheus history also resets if its pod restarts.)
                    </p>
                </div>}
                <div className="space-y-3">
                    {[
                        <div
                            key={c["name"]}
                            className="bg-surface border border-line rounded-lg p-4 shadow-sm"
                        >
                            <p className="text-sm font-medium text-fg mb-3">
                                {c["name"]}
                            </p>
                            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                                <div>
                                    <div
                                        className="flex items-center justify-between mb-1"
                                    >
                                        <span
                                            className="text-xs font-medium text-muted"
                                        >
                                            CPU
                                        </span>
                                        <span
                                            className="text-xs font-mono tabular-nums"
                                            style={{"color": cpuLineColor}}
                                        >
                                            {formatCores(c["cpuLast"])}
                                        </span>
                                    </div>
                                    <svg
                                        viewBox="0 0 900 240"
                                        className="w-full"
                                        role="img"
                                    >
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
                                            {c["cpuMaxLabel"]}
                                        </text>
                                        <text
                                            x="82"
                                            y="119"
                                            textAnchor="end"
                                            fill={axisFill}
                                            fontSize="15"
                                        >
                                            {c["cpuMidLabel"]}
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
                                        <text
                                            x="90"
                                            y="234"
                                            fill={axisFill}
                                            fontSize="15"
                                        >
                                            {startLabel}
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
                                            points={c["cpuArea"]}
                                            fill={cpuAreaFill}
                                            stroke="none"
                                        />
                                        <polyline
                                            points={c["cpuLine"]}
                                            fill="none"
                                            stroke={cpuLineColor}
                                            strokeWidth="2.5"
                                        />
                                    </svg>
                                </div>
                                <div>
                                    <div
                                        className="flex items-center justify-between mb-1"
                                    >
                                        <span
                                            className="text-xs font-medium text-muted"
                                        >
                                            Memory
                                        </span>
                                        <span
                                            className="text-xs font-mono tabular-nums"
                                            style={{"color": memLineColor}}
                                        >
                                            {formatBytes(c["memLast"])}
                                        </span>
                                    </div>
                                    <svg
                                        viewBox="0 0 900 240"
                                        className="w-full"
                                        role="img"
                                    >
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
                                            {c["memMaxLabel"]}
                                        </text>
                                        <text
                                            x="82"
                                            y="119"
                                            textAnchor="end"
                                            fill={axisFill}
                                            fontSize="15"
                                        >
                                            {c["memMidLabel"]}
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
                                        <text
                                            x="90"
                                            y="234"
                                            fill={axisFill}
                                            fontSize="15"
                                        >
                                            {startLabel}
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
                                            points={c["memArea"]}
                                            fill={memAreaFill}
                                            stroke="none"
                                        />
                                        <polyline
                                            points={c["memLine"]}
                                            fill="none"
                                            stroke={memLineColor}
                                            strokeWidth="2.5"
                                        />
                                    </svg>
                                </div>
                            </div>
                        </div> for c in cards
                    ]}
                </div>
            </div>;
    }
}
