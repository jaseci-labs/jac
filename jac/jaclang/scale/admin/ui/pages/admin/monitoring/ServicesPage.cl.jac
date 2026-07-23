"""Services page: service-centric view of K8s workloads with drill-down.

Replaces the former flat Workloads page. Each "service" is a workload
(Deployment / StatefulSet / DaemonSet) from /admin/workloads/list, rendered as
a card. Clicking a card opens an in-page detail (ServiceDetail) showing that
service's pods (filtered from /admin/workloads/pods by `owner`) and its
CPU / memory history (filtered from /admin/workloads/timeseries by name).

Navigation is local state (`selectedService`), matching the no-router pattern
the dashboard uses elsewhere. Cluster-wide traffic still shows in the summary
cards; per-service traffic is deferred (see ServiceDetail).
"""

cl import from "lucide-react" { Server, RefreshCw, Activity, ChevronRight }

cl {
    import from react { useEffect }
    import from ....components.common.PageHeader { PageHeader }
    import from ....context.AuthContext { useAuth }
    import from ....services.workloadsService {
        getWorkloadsSummary,
        getWorkloadsList,
        getWorkloadsPods,
        getWorkloadsTimeseries
    }
    import from ....utils.format { formatBytes, formatCores }
    import from .ServiceDetail { ServiceDetail }

    def:pub ServicesPage -> JsxElement {
        has isLoading: bool = True,
            metricsAvailable: bool = True,
            unavailableReason: str = "",
            summary: dict = {},
            services: list[dict] = [],
            pods: list[dict] = [],
            series: list[dict] = [],
            selectedService: str = "",
            autoRefresh: bool = True;

        auth = useAuth();

        async def loadAll {
            sumRes = await getWorkloadsSummary(auth["authToken"]);
            listRes = await getWorkloadsList(auth["authToken"]);
            podsRes = await getWorkloadsPods(auth["authToken"]);
            tsRes = await getWorkloadsTimeseries(auth["authToken"], 60);
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
            tsData = {};
            if tsRes["ok"] and tsRes["data"] {
                tsData = tsRes["data"];
            }
            metricsAvailable = bool(sumData["metrics_available"]);
            unavailableReason = sumData["reason"] or "";
            summary = sumData;
            services = listData["workloads"] or [];
            pods = podsData["pods"] or [];
            series = tsData["workloads"] or [];
            isLoading = False;
        }

        useEffect(
            lambda {
                loadAll();
                return;
            },
            []
        );

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

        # Closure factory so each card's click captures its own service name
        # (an inline lambda inside the comprehension would capture by reference).
        def makeSelect(svcName: str) -> any {
            return lambda (e: any) { selectedService = svcName; };
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

        if isLoading {
            return
                <div
                    className="bg-surface border border-line rounded-lg p-8 text-center shadow-sm"
                >
                    <p className="text-sm text-muted">Loading services...</p>
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
                        Services are off
                    </h2>
                    <p className="text-sm text-muted">
                        Enable in jac.toml:
                        <span className="font-mono text-fg ml-1">
                            [scale.monitoring] enabled = true
                        </span>
                    </p>
                </div>;
        }

        # Drill-down: resolve the selected service row + its pods + its series,
        # then hand off to the detail component. Falls through to the grid if the
        # selection vanished (e.g. the service was deleted between refreshes).
        if selectedService {
            svcRow = {};
            for s in services {
                if s["name"] == selectedService {
                    svcRow = s;
                }
            }
            if svcRow["name"] {
                svcPods = [];
                for p in pods {
                    if p["owner"] == selectedService {
                        svcPods.append(p);
                    }
                }
                svcCpu = [];
                svcMem = [];
                for w in series {
                    if w["name"] == selectedService {
                        svcCpu = list(w["cpu"] or []);
                        svcMem = list(w["memory"] or []);
                    }
                }
                return
                    <ServiceDetail
                        service={svcRow}
                        pods={svcPods}
                        cpu={svcCpu}
                        memory={svcMem}
                        onBack={lambda { selectedService = ""; }}
                    />;
            }
        }

        # Cluster-wide rollups (still valid: only PER-service traffic is missing).
        traffic = summary["traffic"] or {};
        nodes = summary["nodes"] or {};
        rps = traffic["requests_per_sec"] or 0;
        errPct = traffic["error_rate_pct"] or 0;
        p95 = traffic["p95_latency_ms"] or 0;
        nodesReady = nodes["ready"] or 0;
        nodesTotal = nodes["total"] or 0;

        # Service-level status counts (this is what a service view should lead with).
        healthyN = 0;
        attentionN = 0;
        brokenN = 0;
        for s in services {
            st = s["status"];
            if st == "Healthy" {
                healthyN = healthyN + 1;
            } elif st == "Broken" {
                brokenN = brokenN + 1;
            } else {
                attentionN = attentionN + 1;
            }
        }
        attentionTone = "white";
        if attentionN > 0 {
            attentionTone = "warn";
        }
        brokenTone = "white";
        if brokenN > 0 {
            brokenTone = "bad";
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
                "label": "Services",
                "value": len(services),
                "sub": "total",
                "tone": "white"
            },
            {
                "label": "Healthy",
                "value": healthyN,
                "sub": "running normally",
                "tone": "good"
            },
            {
                "label": "Needs attention",
                "value": attentionN,
                "sub": "starting / unstable",
                "tone": attentionTone
            },
            {"label": "Broken", "value": brokenN, "sub": "failing", "tone": brokenTone},
            {
                "label": "Traffic",
                "value": str(rps) + " r/s",
                "sub": "cluster requests/sec",
                "tone": "white"
            }
        ];
        secondaryCards = [
            {
                "label": "Errors",
                "value": str(errPct) + "%",
                "sub": "of requests are errors",
                "tone": errTone
            },
            {
                "label": "Response time (p95)",
                "value": str(p95) + " ms",
                "sub": "95% of requests under",
                "tone": "white"
            },
            {
                "label": "Cluster nodes",
                "value": str(nodesReady) + " / " + str(nodesTotal),
                "sub": "ready",
                "tone": "white"
            },
            {
                "label": "Namespace",
                "value": summary["namespace"] or "default",
                "sub": "",
                "tone": "white"
            }
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
            <button
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs rounded-md bg-surface-2 text-fg border border-line hover:bg-line transition-colors"
                onClick={lambda { loadAll(); }}
            >
                <RefreshCw className="w-3.5 h-3.5"/>
                Refresh
            </button>
        </div>;

        return
            <div className="space-y-4">
                <PageHeader
                    icon={Server}
                    title="Services"
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
                <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
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
                <div className="flex items-center justify-between">
                    <h2 className="text-sm font-medium text-fg">
                        Services ({len(services)})
                    </h2>
                    {autoRefresh
                    and <p className="text-xs text-faint">refreshing every 10s</p>}
                </div>
                {len(services) == 0
                and <div
                    className="bg-surface border border-line rounded-lg p-6 text-center text-sm text-faint shadow-sm"
                >
                    No services visible.
                </div>}
                {len(services) > 0
                and <div
                    className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3"
                >
                    {[
                        <button
                            key={str(s["kind"]) + "/" + str(s["name"])}
                            onClick={makeSelect(str(s["name"]))}
                            className="text-left bg-surface border border-line rounded-lg p-4 shadow-sm hover:border-accent-line hover:bg-surface-2 transition-colors group"
                        >
                            <div className="flex items-start justify-between gap-2">
                                <div className="min-w-0">
                                    <p
                                        className="text-sm font-semibold text-fg truncate"
                                    >
                                        {s["name"]}
                                    </p>
                                    <span
                                        className="inline-flex items-center px-2 py-0.5 mt-1 rounded text-xs font-medium bg-surface-2 text-muted border border-line"
                                    >
                                        {s["kind"]}
                                    </span>
                                </div>
                                <span
                                    className={"inline-flex items-center gap-1.5 px-2 py-0.5 rounded text-xs font-medium border shrink-0 " + str(
                                        statusClasses[s["status"]]
                                        or "bg-surface-2 text-muted border-line"
                                    )}
                                >
                                    <span
                                        className={"w-1.5 h-1.5 rounded-full " + str(
                                            statusDotClasses[s["status"]] or "bg-faint"
                                        )}
                                    ></span>
                                    {s["status"]}
                                </span>
                            </div>
                            <div className="grid grid-cols-3 gap-2 mt-3">
                                <div>
                                    <p
                                        className="text-[11px] text-faint uppercase tracking-wider"
                                    >
                                        Pods
                                    </p>
                                    <p className="text-sm text-fg tabular-nums">
                                        {s["replicas_ready"]}{" / "}{s[
                                            "replicas_desired"
                                        ]}
                                    </p>
                                </div>
                                <div>
                                    <p
                                        className="text-[11px] text-faint uppercase tracking-wider"
                                    >
                                        CPU
                                    </p>
                                    <p className="text-sm text-fg tabular-nums">
                                        {formatCores(s["cpu_cores"] or 0)}
                                    </p>
                                </div>
                                <div>
                                    <p
                                        className="text-[11px] text-faint uppercase tracking-wider"
                                    >
                                        Memory
                                    </p>
                                    <p className="text-sm text-fg tabular-nums">
                                        {formatBytes(s["memory_bytes"] or 0)}
                                    </p>
                                </div>
                            </div>
                            <div
                                className="flex items-center justify-between mt-3 pt-3 border-t border-line"
                            >
                                <span className="text-xs text-faint tabular-nums">
                                    {s["restarts_last_hour"]} restarts (1h)
                                </span>
                                <span
                                    className="inline-flex items-center gap-1 text-xs text-muted group-hover:text-accent"
                                >
                                    Details
                                    <ChevronRight className="w-3.5 h-3.5"/>
                                </span>
                            </div>
                        </button> for s in services
                    ]}
                </div>}
            </div>;
    }
}
