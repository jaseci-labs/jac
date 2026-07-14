"""Workloads page: non-technical-friendly view of K8s workload health.

Renders summary cards + a table of Deployments / StatefulSets / DaemonSets / Pods
driven by /admin/workloads/*. A chip filter at the top lets the admin narrow
the table to a specific workload kind. Pods are loaded separately because
they have a different shape (per-pod rather than aggregated).

Status strings ('Healthy', 'Starting', 'Broken', 'Unstable') are pre-computed
server-side so this page is purely presentational.
"""

cl import from "lucide-react" { Boxes, RefreshCw, Activity }

cl {
    import from react { useEffect }
    import from ....components.common.Button { Button }
    import from ....components.common.PageHeader { PageHeader }
    import from ....context.AuthContext { useAuth }
    import from ....services.workloadsService {
        getWorkloadsSummary,
        getWorkloadsList,
        getWorkloadsPods
    }

    def:pub WorkloadsPage -> JsxElement {
        has isLoading: bool = True,
            metricsAvailable: bool = True,
            unavailableReason: str = "",
            summary: dict = {},
            workloads: list = [],
            pods: list = [],
            kindFilter: str = "All",
            autoRefresh: bool = True;

        auth = useAuth();

        async def loadAll {
            sumRes = await getWorkloadsSummary(auth["authToken"]);
            listRes = await getWorkloadsList(auth["authToken"]);
            podsRes = await getWorkloadsPods(auth["authToken"]);
            sumData = {};
            if sumRes["ok"] and sumRes["data"] {
                sumData = sumRes["data"];
            }
            listData = {};
            if listRes["ok"] and listRes["data"] {
                listData = listRes["data"];
            }
            podsData = {};
            if podsRes["ok"] and podsRes["data"] {
                podsData = podsRes["data"];
            }
            metricsAvailable = bool(sumData["metrics_available"]);
            unavailableReason = sumData["reason"] or "";
            summary = sumData;
            workloads = listData["workloads"] or [];
            pods = podsData["pods"] or [];
            isLoading = False;
        }

        useEffect(lambda { loadAll(); }, []);

        useEffect(
            lambda -> any {
                if not autoRefresh {
                    return undefined;
                }
                interval = setInterval(lambda { loadAll(); }, 10000);
                return lambda { clearInterval(interval); };
            },
            [autoRefresh]
        );

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

        def formatAge(createdSecs: float) -> str {
            if createdSecs <= 0 {
                return "-";
            }
            ageSecs = (Date.now() / 1000) - createdSecs;
            if ageSecs < 0 {
                return "-";
            }
            if ageSecs < 60 {
                return str(int(ageSecs)) + "s";
            }
            if ageSecs < 3600 {
                return str(int(ageSecs / 60)) + "m";
            }
            if ageSecs < 86400 {
                hrs = int(ageSecs / 3600);
                mins = int((ageSecs % 3600) / 60);
                return str(hrs) + "h " + str(mins) + "m";
            }
            days = int(ageSecs / 86400);
            hrs = int((ageSecs % 86400) / 3600);
            return str(days) + "d " + str(hrs) + "h";
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
        toneClasses = {
            "white": "text-fg",
            "good": "text-success",
            "warn": "text-warning",
            "bad": "text-danger"
        };
        phaseToStatus = {
            "Running": "Healthy",
            "Pending": "Starting",
            "Succeeded": "Healthy",
            "Failed": "Broken",
            "Unknown": "Unknown"
        };

        if isLoading {
            return
                <div
                    className="bg-surface border border-line rounded-lg p-8 text-center shadow-sm"
                >
                    <p className="text-sm text-muted">Loading workloads...</p>
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
                        Workloads are off
                    </h2>
                    <p className="text-sm text-muted">
                        Enable in jac.toml:
                        <span className="font-mono text-fg ml-1">
                            [scale.monitoring] enabled = true
                        </span>
                    </p>
                </div>;
        }

        summaryPods = summary["pods"] or {};
        nodes = summary["nodes"] or {};
        traffic = summary["traffic"] or {};
        running = summaryPods["running"] or 0;
        pending = summaryPods["pending"] or 0;
        failed = summaryPods["failed"] or 0;
        nodesReady = nodes["ready"] or 0;
        nodesTotal = nodes["total"] or 0;
        rps = traffic["requests_per_sec"] or 0;
        errPct = traffic["error_rate_pct"] or 0;
        p95 = traffic["p95_latency_ms"] or 0;

        pendingTone = "white";
        if pending > 0 {
            pendingTone = "warn";
        }
        failedTone = "white";
        if failed > 0 {
            failedTone = "bad";
        }
        errTone = "good";
        if errPct > 0 {
            errTone = "warn";
        }
        if errPct >= 1 {
            errTone = "bad";
        }

        primaryCards = [
            {
                "label": "Healthy",
                "value": running,
                "sub": "pods running",
                "tone": "good"
            },
            {
                "label": "Starting",
                "value": pending,
                "sub": "pods pending",
                "tone": pendingTone
            },
            {
                "label": "Broken",
                "value": failed,
                "sub": "pods failing",
                "tone": failedTone
            },
            {
                "label": "Traffic",
                "value": str(rps) + " r/s",
                "sub": "requests per second",
                "tone": "white"
            },
            {
                "label": "Errors",
                "value": str(errPct) + "%",
                "sub": "of requests are errors",
                "tone": errTone
            }
        ];
        secondaryCards = [
            {
                "label": "Cluster nodes",
                "value": str(nodesReady) + " / " + str(nodesTotal),
                "sub": "ready",
                "tone": "white"
            },
            {
                "label": "Response time (p95)",
                "value": str(p95) + " ms",
                "sub": "95% of requests under",
                "tone": "white"
            },
            {
                "label": "Namespace",
                "value": summary["namespace"] or "default",
                "sub": "",
                "tone": "white"
            }
        ];

        filteredWorkloads = [];
        if kindFilter == "All" {
            filteredWorkloads = workloads;
        } elif kindFilter != "Pods" {
            singularMap = {
                "Deployments": "Deployment",
                "StatefulSets": "StatefulSet",
                "DaemonSets": "DaemonSet"
            };
            wantKind = singularMap[kindFilter] or kindFilter;
            for w in workloads {
                if w["kind"] == wantKind {
                    filteredWorkloads.append(w);
                }
            }
        }

        showPods = kindFilter == "Pods";

        chipLabels = ["All", "Deployments", "StatefulSets", "DaemonSets", "Pods"];
        activeChipCls = "bg-accent-weak text-accent border-accent-line";
        inactiveChipCls = "bg-surface-2 text-muted border-line hover:text-fg";
        chipBase = "px-3 py-1 rounded-full text-xs font-medium cursor-pointer border transition-colors ";

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
            <Button variant="secondary" onClick={lambda { loadAll(); }}>
                <RefreshCw className="w-3.5 h-3.5"/>
                Refresh
            </Button>
        </div>;

        return
            <div className="space-y-4">
                <PageHeader
                    icon={Boxes}
                    title="Workloads"
                    live={True}
                    right={headerRight}
                />
                <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
                    {[
                        <div
                            key={c["label"]}
                            className="bg-surface border border-line rounded-lg p-4 shadow-sm"
                        >
                            <p className="text-xs text-faint uppercase tracking-wider">
                                {c["label"]}
                            </p>
                            <p
                                className={"text-2xl font-semibold mt-1 tabular-nums " + str(
                                    toneClasses[c["tone"]] or "text-fg"
                                )}
                            >
                                {c["value"]}
                            </p>
                            {c["sub"]
                            and <p className="text-xs text-faint mt-1">{c["sub"]}</p>}
                        </div> for c in primaryCards
                    ]}
                </div>
                <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                    {[
                        <div
                            key={c["label"]}
                            className="bg-surface border border-line rounded-lg p-4 shadow-sm"
                        >
                            <p className="text-xs text-faint uppercase tracking-wider">
                                {c["label"]}
                            </p>
                            <p
                                className={"text-2xl font-semibold mt-1 tabular-nums " + str(
                                    toneClasses[c["tone"]] or "text-fg"
                                )}
                            >
                                {c["value"]}
                            </p>
                            {c["sub"]
                            and <p className="text-xs text-faint mt-1">{c["sub"]}</p>}
                        </div> for c in secondaryCards
                    ]}
                </div>
                <div
                    className="bg-surface border border-line rounded-lg overflow-hidden shadow-sm"
                >
                    <div
                        className="flex items-center justify-between px-4 py-3 border-b border-line"
                    >
                        <h2 className="text-sm font-medium text-fg">Workloads</h2>
                        <p className="text-xs text-faint">refreshing every 10s</p>
                    </div>
                    <div className="flex gap-2 px-4 py-3 border-b border-line">
                        {[
                            <button
                                key={k}
                                className={chipBase + (
                                    activeChipCls
                                        if kindFilter == k
                                        else inactiveChipCls
                                )}
                                onClick={lambda (e: any) { kindFilter = k; }}
                            >
                                {k}
                            </button> for k in chipLabels
                        ]}
                    </div>
                    {not showPods
                    and len(filteredWorkloads) == 0
                    and <div className="p-6 text-center text-sm text-faint">
                        No workloads visible.
                    </div>}
                    {not showPods
                    and len(filteredWorkloads) > 0
                    and <div className="overflow-x-auto">
                        <table className="w-full text-sm">
                            <thead
                                className="text-xs text-faint uppercase tracking-wider bg-surface-2"
                            >
                                <tr>
                                    <th className="text-left px-4 py-2 font-medium">
                                        Name
                                    </th>
                                    <th className="text-left px-4 py-2 font-medium">
                                        Kind
                                    </th>
                                    <th className="text-left px-4 py-2 font-medium">
                                        Status
                                    </th>
                                    <th className="text-left px-4 py-2 font-medium">
                                        Replicas
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
                                        key={w["kind"] + "/" + w["name"]}
                                        className="border-t border-line"
                                    >
                                        <td className="px-4 py-2 text-fg">
                                            {w["name"]}
                                        </td>
                                        <td className="px-4 py-2">
                                            <span
                                                className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-surface-2 text-muted border border-line"
                                            >
                                                {w["kind"]}
                                            </span>
                                        </td>
                                        <td className="px-4 py-2">
                                            <span
                                                className={"inline-flex items-center gap-1.5 px-2 py-0.5 rounded text-xs font-medium border " + str(
                                                    statusClasses[w["status"]]
                                                    or "bg-surface-2 text-muted border-line"
                                                )}
                                            >
                                                <span
                                                    className={"w-1.5 h-1.5 rounded-full " + str(
                                                        statusDotClasses[w["status"]]
                                                        or "bg-faint"
                                                    )}
                                                ></span>
                                                {w["status"]}
                                            </span>
                                        </td>
                                        <td
                                            className="px-4 py-2 text-muted tabular-nums"
                                        >
                                            {w["replicas_ready"]}{" / "}{w[
                                                "replicas_desired"
                                            ]}
                                        </td>
                                        <td
                                            className="px-4 py-2 text-muted tabular-nums"
                                        >
                                            {w["cpu_cores"]}{" cores"}
                                        </td>
                                        <td
                                            className="px-4 py-2 text-muted tabular-nums"
                                        >
                                            {formatBytes(w["memory_bytes"])}
                                        </td>
                                        <td
                                            className="px-4 py-2 text-muted tabular-nums"
                                        >
                                            {w["restarts_last_hour"]}
                                        </td>
                                        <td
                                            className="px-4 py-2 text-muted tabular-nums"
                                        >
                                            {formatAge(w["created"])}
                                        </td>
                                    </tr> for w in filteredWorkloads
                                ]}
                            </tbody>
                        </table>
                    </div>}
                    {showPods
                    and len(pods) == 0
                    and <div className="p-6 text-center text-sm text-faint">
                        No pods visible.
                    </div>}
                    {showPods
                    and len(pods) > 0
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
                                        Workload
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
                                        <td className="px-4 py-2 text-muted">
                                            {p["owner"]}
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
                                            {p["cpu_cores"]}{" cores"}
                                        </td>
                                        <td
                                            className="px-4 py-2 text-muted tabular-nums"
                                        >
                                            {formatBytes(p["memory_bytes"])}
                                        </td>
                                        <td
                                            className="px-4 py-2 text-muted tabular-nums"
                                        >
                                            {p["restarts_last_hour"]}
                                        </td>
                                        <td
                                            className="px-4 py-2 text-muted tabular-nums"
                                        >
                                            {formatAge(p["created"])}
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
