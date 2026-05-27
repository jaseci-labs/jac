"""Workloads page: non-technical-friendly view of K8s workload health.

Renders summary cards + a table of Deployments / StatefulSets / DaemonSets / Pods
driven by /admin/workloads/*. A chip filter at the top lets the admin narrow
the table to a specific workload kind. Pods are loaded separately because
they have a different shape (per-pod rather than aggregated).

Status strings ('Healthy', 'Starting', 'Broken', 'Unstable') are pre-computed
server-side so this page is purely presentational.
"""

cl {
    import from react { useEffect }
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

        statusClasses = {
            "Healthy": "bg-emerald-500/20 text-emerald-300 border-emerald-500/40",
            "Starting": "bg-amber-500/20 text-amber-300 border-amber-500/40",
            "Unstable": "bg-orange-500/20 text-orange-300 border-orange-500/40",
            "Broken": "bg-red-500/20 text-red-300 border-red-500/40"
        };
        statusDotClasses = {
            "Healthy": "bg-emerald-400",
            "Starting": "bg-amber-400",
            "Unstable": "bg-orange-400",
            "Broken": "bg-red-400"
        };
        toneClasses = {
            "white": "text-white",
            "good": "text-emerald-300",
            "warn": "text-amber-300",
            "bad": "text-red-300"
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
                    className="bg-slate-900 border border-slate-800 rounded-lg p-8 text-center"
                >
                    <p className="text-sm text-slate-400">Loading workloads...</p>
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
                        or "Could not reach the Prometheus monitoring stack. Confirm monitoring is enabled in jac.toml and the cluster has finished deploying."}
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
        activeChipCls = "bg-teal-500/20 text-teal-200 border-teal-500/40";
        inactiveChipCls = "bg-slate-800 text-slate-400 border-slate-700 hover:text-slate-200";
        chipBase = "px-3 py-1 rounded-full text-xs font-medium cursor-pointer border ";

        return
            <div className="space-y-4">
                <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
                    {[
                        <div
                            key={c["label"]}
                            className="bg-slate-900 border border-slate-800 rounded-lg p-4"
                        >
                            <p
                                className="text-xs text-slate-500 uppercase tracking-wider"
                            >
                                {c["label"]}
                            </p>
                            <p
                                className={"text-2xl font-semibold mt-1 " + str(toneClasses[c["tone"]] or "text-white")}
                            >
                                {c["value"]}
                            </p>
                            {c["sub"]
                            and <p className="text-xs text-slate-500 mt-1">
                                {c["sub"]}
                            </p>}
                        </div> for c in primaryCards
                    ]}
                </div>
                <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                    {[
                        <div
                            key={c["label"]}
                            className="bg-slate-900 border border-slate-800 rounded-lg p-4"
                        >
                            <p
                                className="text-xs text-slate-500 uppercase tracking-wider"
                            >
                                {c["label"]}
                            </p>
                            <p
                                className={"text-2xl font-semibold mt-1 " + str(toneClasses[c["tone"]] or "text-white")}
                            >
                                {c["value"]}
                            </p>
                            {c["sub"]
                            and <p className="text-xs text-slate-500 mt-1">
                                {c["sub"]}
                            </p>}
                        </div> for c in secondaryCards
                    ]}
                </div>
                <div
                    className="bg-slate-900 border border-slate-800 rounded-lg overflow-hidden"
                >
                    <div
                        className="flex items-center justify-between px-4 py-3 border-b border-slate-800"
                    >
                        <h2 className="text-sm font-medium text-white">Workloads</h2>
                        <p className="text-xs text-slate-500">
                            refreshing every 10s
                        </p>
                    </div>
                    <div className="flex gap-2 px-4 py-3 border-b border-slate-800">
                        {[
                            <button
                                key={k}
                                className={chipBase + (activeChipCls if kindFilter == k else inactiveChipCls)}
                                onClick={lambda e: any { kindFilter = k; }}
                            >
                                {k}
                            </button> for k in chipLabels
                        ]}
                    </div>
                    {not showPods and len(filteredWorkloads) == 0
                    and <div className="p-6 text-center text-sm text-slate-500">
                        No workloads visible.
                    </div>}
                    {not showPods and len(filteredWorkloads) > 0
                    and <div className="overflow-x-auto">
                        <table className="w-full text-sm">
                            <thead
                                className="text-xs text-slate-500 uppercase tracking-wider bg-slate-950/40"
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
                                </tr>
                            </thead>
                            <tbody>
                                {[
                                    <tr
                                        key={w["kind"] + "/" + w["name"]}
                                        className="border-t border-slate-800"
                                    >
                                        <td className="px-4 py-2 text-white">
                                            {w["name"]}
                                        </td>
                                        <td className="px-4 py-2">
                                            <span
                                                className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-slate-800 text-slate-300 border border-slate-700"
                                            >
                                                {w["kind"]}
                                            </span>
                                        </td>
                                        <td className="px-4 py-2">
                                            <span
                                                className={"inline-flex items-center gap-1.5 px-2 py-0.5 rounded text-xs font-medium border " + str(statusClasses[w["status"]] or "bg-slate-700/40 text-slate-300 border-slate-600/40")}
                                            >
                                                <span
                                                    className={"w-1.5 h-1.5 rounded-full " + str(statusDotClasses[w["status"]] or "bg-slate-400")}
                                                ></span>
                                                {w["status"]}
                                            </span>
                                        </td>
                                        <td className="px-4 py-2 text-slate-300">
                                            {w["replicas_ready"]}{" / "}{w[
                                                "replicas_desired"
                                            ]}
                                        </td>
                                        <td className="px-4 py-2 text-slate-300">
                                            {w["cpu_cores"]}{" cores"}
                                        </td>
                                        <td className="px-4 py-2 text-slate-300">
                                            {formatBytes(w["memory_bytes"])}
                                        </td>
                                        <td className="px-4 py-2 text-slate-300">
                                            {w["restarts_last_hour"]}
                                        </td>
                                    </tr> for w in filteredWorkloads
                                ]}
                            </tbody>
                        </table>
                    </div>}
                    {showPods and len(pods) == 0
                    and <div className="p-6 text-center text-sm text-slate-500">
                        No pods visible.
                    </div>}
                    {showPods and len(pods) > 0
                    and <div className="overflow-x-auto">
                        <table className="w-full text-sm">
                            <thead
                                className="text-xs text-slate-500 uppercase tracking-wider bg-slate-950/40"
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
                                </tr>
                            </thead>
                            <tbody>
                                {[
                                    <tr
                                        key={p["name"]}
                                        className="border-t border-slate-800"
                                    >
                                        <td className="px-4 py-2 text-white">
                                            {p["name"]}
                                        </td>
                                        <td className="px-4 py-2 text-slate-300">
                                            {p["owner"]}
                                        </td>
                                        <td className="px-4 py-2">
                                            <span
                                                className={"inline-flex items-center gap-1.5 px-2 py-0.5 rounded text-xs font-medium border " + str(statusClasses[phaseToStatus[p["phase"]] or p["phase"]] or "bg-slate-700/40 text-slate-300 border-slate-600/40")}
                                            >
                                                <span
                                                    className={"w-1.5 h-1.5 rounded-full " + str(statusDotClasses[phaseToStatus[p["phase"]] or p["phase"]] or "bg-slate-400")}
                                                ></span>
                                                {phaseToStatus[p["phase"]] or p["phase"]}
                                            </span>
                                        </td>
                                        <td className="px-4 py-2 text-slate-300">
                                            {p["node"]}
                                        </td>
                                        <td className="px-4 py-2 text-slate-300">
                                            {p["cpu_cores"]}{" cores"}
                                        </td>
                                        <td className="px-4 py-2 text-slate-300">
                                            {formatBytes(p["memory_bytes"])}
                                        </td>
                                        <td className="px-4 py-2 text-slate-300">
                                            {p["restarts_last_hour"]}
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
