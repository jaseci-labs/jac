"""Usage page: CPU + memory history per workload.

Pulls /admin/workloads/timeseries (one bulk call returning cpu+memory series
for every workload) and renders dependency-free SVG line charts with labeled
axes (Y value scale, X time range) and gridlines. A time-range dropdown
(1h / 6h / 24h / 7d) re-fetches at a coarser step.

Charts are inline SVG with str-returning path helpers, because cl mode drops
args to JSX-returning helper functions.
"""

cl {
    import from react { useEffect }
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

        # Chart geometry: drawing area sits inside left/bottom margins that hold
        # the axis labels. viewBox is 260 wide x 96 tall; drawing area is
        # x:[44,256] y:[8,74].
        def chartLine(points: list, maxV: float) -> str {
            n = len(points);
            if n == 0 {
                return "";
            }
            mv = maxV;
            if mv <= 0 {
                mv = 1.0;
            }
            w = 212.0;
            h = 66.0;
            out = "";
            i = 0;
            for p in points {
                x = 44.0 + (w / 2);
                if n > 1 {
                    x = 44.0 + (i / (n - 1) * w);
                }
                y = 74.0 - (p["v"] / mv * h);
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
            return "44.0,74.0 " + line + " 256.0,74.0";
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
                    className="bg-slate-900 border border-slate-800 rounded-lg p-8 text-center"
                >
                    <p className="text-sm text-slate-400">Loading usage...</p>
                </div>;
        }

        if not metricsAvailable {
            return
                <div className="bg-slate-900 border border-amber-500/30 rounded-lg p-6">
                    <h2 className="text-sm font-medium text-white mb-2">
                        Metrics unavailable
                    </h2>
                    <p className="text-xs text-slate-400">
                        {unavailableReason
                        or "Could not reach the Prometheus monitoring stack."}
                    </p>
                </div>;
        }

        # Detect a freshly-deployed cluster: very little history collected yet.
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
                    "cpu": w["cpu"],
                    "memory": w["memory"],
                    "cpuMax": cpuMaxV,
                    "memMax": memMaxV,
                    "cpuLast": lastOf(w["cpu"]),
                    "memLast": lastOf(w["memory"]),
                    "cpuMaxLabel": formatCores(cpuMaxV),
                    "memMaxLabel": formatBytes(memMaxV),
                    "cpuLine": chartLine(w["cpu"], cpuMaxV),
                    "cpuArea": chartArea(w["cpu"], cpuMaxV),
                    "memLine": chartLine(w["memory"], memMaxV),
                    "memArea": chartArea(w["memory"], memMaxV)
                }
            );
        }
        startLabel = rangeLabel(rangeMinutes);

        return
            <div className="space-y-4">
                <div
                    className="flex items-center justify-between bg-slate-900 border border-slate-800 rounded-lg px-4 py-3"
                >
                    <h2 className="text-sm font-medium text-white">
                        Resource usage over time
                    </h2>
                    <select
                        value={str(rangeMinutes)}
                        onChange={lambda e: any { rangeMinutes = int(e.target.value); }}
                        className="px-2 py-1 bg-slate-950 border border-slate-700 rounded text-white text-xs"
                    >
                        <option value="60">Last 1 hour</option>
                        <option value="360">Last 6 hours</option>
                        <option value="1440">Last 24 hours</option>
                        <option value="10080">Last 7 days</option>
                    </select>
                </div>
                {sparse
                and <div
                    className="bg-slate-900 border border-amber-500/30 rounded-lg px-4 py-3"
                >
                    <p className="text-xs text-amber-300">
                        Collecting data. History builds up as the cluster runs, so
                        graphs fill in over the next several minutes. (Prometheus
                        history also resets if its pod restarts.)
                    </p>
                </div>}
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
                    {[
                        <div
                            key={c["name"]}
                            className="bg-slate-900 border border-slate-800 rounded-lg p-4"
                        >
                            <p className="text-sm font-medium text-white mb-3">
                                {c["name"]}
                            </p>
                            <div className="space-y-4">
                                <div>
                                    <div
                                        className="flex items-center justify-between mb-1"
                                    >
                                        <span className="text-xs text-slate-400">
                                            CPU
                                        </span>
                                        <span className="text-xs text-teal-300 font-mono">
                                            {formatCores(c["cpuLast"])}
                                        </span>
                                    </div>
                                    <svg
                                        viewBox="0 0 260 96"
                                        className="w-full"
                                        style={{"height": "110px"}}
                                    >
                                        <line
                                            x1="44"
                                            y1="8"
                                            x2="256"
                                            y2="8"
                                            stroke="#1e293b"
                                            strokeWidth="1"
                                        />
                                        <line
                                            x1="44"
                                            y1="74"
                                            x2="256"
                                            y2="74"
                                            stroke="#1e293b"
                                            strokeWidth="1"
                                        />
                                        <text
                                            x="40"
                                            y="11"
                                            textAnchor="end"
                                            fill="#64748b"
                                            fontSize="8"
                                        >
                                            {c["cpuMaxLabel"]}
                                        </text>
                                        <text
                                            x="40"
                                            y="74"
                                            textAnchor="end"
                                            fill="#64748b"
                                            fontSize="8"
                                        >
                                            0
                                        </text>
                                        <text x="44" y="90" fill="#64748b" fontSize="8">
                                            {startLabel}
                                        </text>
                                        <text
                                            x="256"
                                            y="90"
                                            textAnchor="end"
                                            fill="#64748b"
                                            fontSize="8"
                                        >
                                            now
                                        </text>
                                        <polygon
                                            points={c["cpuArea"]}
                                            fill="rgba(45,212,191,0.15)"
                                            stroke="none"
                                        />
                                        <polyline
                                            points={c["cpuLine"]}
                                            fill="none"
                                            stroke="#2dd4bf"
                                            strokeWidth="1.5"
                                        />
                                    </svg>
                                </div>
                                <div>
                                    <div
                                        className="flex items-center justify-between mb-1"
                                    >
                                        <span className="text-xs text-slate-400">
                                            Memory
                                        </span>
                                        <span className="text-xs text-purple-300 font-mono">
                                            {formatBytes(c["memLast"])}
                                        </span>
                                    </div>
                                    <svg
                                        viewBox="0 0 260 96"
                                        className="w-full"
                                        style={{"height": "110px"}}
                                    >
                                        <line
                                            x1="44"
                                            y1="8"
                                            x2="256"
                                            y2="8"
                                            stroke="#1e293b"
                                            strokeWidth="1"
                                        />
                                        <line
                                            x1="44"
                                            y1="74"
                                            x2="256"
                                            y2="74"
                                            stroke="#1e293b"
                                            strokeWidth="1"
                                        />
                                        <text
                                            x="40"
                                            y="11"
                                            textAnchor="end"
                                            fill="#64748b"
                                            fontSize="8"
                                        >
                                            {c["memMaxLabel"]}
                                        </text>
                                        <text
                                            x="40"
                                            y="74"
                                            textAnchor="end"
                                            fill="#64748b"
                                            fontSize="8"
                                        >
                                            0
                                        </text>
                                        <text x="44" y="90" fill="#64748b" fontSize="8">
                                            {startLabel}
                                        </text>
                                        <text
                                            x="256"
                                            y="90"
                                            textAnchor="end"
                                            fill="#64748b"
                                            fontSize="8"
                                        >
                                            now
                                        </text>
                                        <polygon
                                            points={c["memArea"]}
                                            fill="rgba(168,85,247,0.15)"
                                            stroke="none"
                                        />
                                        <polyline
                                            points={c["memLine"]}
                                            fill="none"
                                            stroke="#a855f7"
                                            strokeWidth="1.5"
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
