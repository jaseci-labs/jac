"""Performance Report page (A-07): the deterministic system report.

Renders /admin/report - an industry-standard performance report built entirely
server-side from the in-cluster Prometheus / Tempo / Loki: health + top-line
RED (req/s, error rate, p95), per-pod USE (CPU / memory / restarts), the
slowest traces with their critical paths, and grouped error signatures. Every
number here is a fact - no model produces them. The "Analysis & Recommendations"
card at the top is the ONLY AI part: an optional, BYO-token second opinion that
reads this report.
"""

cl import from "lucide-react" {
    Activity, RefreshCw, AlertTriangle, Timer, Bug, Sparkles, Cpu, Server
}

cl {
    import from react { useEffect }
    import from ....components.common.Button { Button }
    import from ....context.AuthContext { useAuth }
    import from ....services.analystService { getReport, analyzeIncident }

    def:pub AnalystPage -> JsxElement {
        has isLoading: bool = True,
            ok: bool = True,
            reason: str = "",
            rpt: dict = {},
            apiKey: str = "",
            model: str = "",
            analyzing: bool = False,
            analysis: dict = {},
            analysisErr: str = "";

        auth = useAuth();

        async def load {
            isLoading = True;
            res = await getReport(auth["authToken"]);
            if res["ok"] and res["data"] {
                rpt = res["data"];
                ok = True;
            } else {
                ok = False;
                err = res["error"] or {};
                reason = err["message"] or "Performance report unavailable";
            }
            isLoading = False;
        }

        async def runDiagnose {
            if not apiKey {
                analysisErr = "Enter your LLM API key (BYO token) first.";
                return;
            }
            analyzing = True;
            analysisErr = "";
            analysis = {};
            res = await analyzeIncident(auth["authToken"], apiKey, model);
            if res["ok"] and res["data"] {
                analysis = res["data"]["analysis"] or {};
                if analysis["error"] {
                    analysisErr = str(analysis["error"]);
                }
            } else {
                err = res["error"] or {};
                analysisErr = err["message"] or "Analysis failed";
            }
            analyzing = False;
        }

        useEffect(lambda { load(); }, []);

        health = (rpt["health"] if rpt else {}) or {};
        pods = (rpt["pods"] if rpt else []) or [];
        slow = (rpt["slow_traces"] if rpt else []) or [];
        errors = (rpt["errors"] if rpt else []) or [];

        sectionCls = "bg-surface border border-line rounded-lg overflow-hidden shadow-sm";
        headCls = "flex items-center gap-2 px-4 py-3 border-b border-line";
        thCls = "text-left text-xs text-faint font-medium px-4 py-2";
        tdCls = "px-4 py-2 text-sm text-fg tabular-nums";
        statCls = "px-4 py-3 bg-surface";
        labelCls = "text-xs text-faint";
        valCls = "text-base font-semibold text-fg tabular-nums";

        return
            <div className="space-y-4">
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2.5">
                        <Activity className="w-5 h-5 text-accent"/>
                        <h1 className="text-lg font-semibold text-fg">
                            Performance Report
                        </h1>
                        <span className="text-xs text-faint">
                            {("status: " + str(health["status"])) if health else "system"}
                        </span>
                    </div>
                    <Button variant="secondary" onClick={lambda { load(); }}>
                        <RefreshCw className="w-3.5 h-3.5"/>
                        Refresh
                    </Button>
                </div>

                <div className={sectionCls}>
                    <div className={headCls}>
                        <Sparkles className="w-4 h-4 text-accent"/>
                        <h2 className="text-sm font-medium text-fg">
                            Analysis and Recommendations (AI, BYO token)
                        </h2>
                    </div>
                    <div className="p-4 space-y-3">
                        <div className="flex flex-col gap-2 sm:flex-row">
                            <input
                                type="password"
                                placeholder="LLM API key (used once, never stored)"
                                value={apiKey}
                                onChange={lambda e: any { apiKey = e.target.value; }}
                                className="flex-1 bg-surface-2 border border-line rounded px-3 py-1.5 text-sm text-fg"
                            />
                            <input
                                type="text"
                                placeholder="model (e.g. gpt-4o-mini)"
                                value={model}
                                onChange={lambda e: any { model = e.target.value; }}
                                className="sm:w-56 bg-surface-2 border border-line rounded px-3 py-1.5 text-sm text-fg"
                            />
                            <Button
                                variant="primary"
                                onClick={lambda { runDiagnose(); }}
                                disabled={analyzing or (not apiKey)}
                            >
                                <Sparkles className="w-3.5 h-3.5"/>
                                {"Analyzing..." if analyzing else "Analyze"}
                            </Button>
                        </div>
                        <p className="text-xs text-faint">
                            Optional second opinion: one small-model call reads the
                            report below and suggests a likely root cause. Your key
                            is used for this request only and is never stored.
                        </p>
                        {bool(analysisErr)
                        and <div className="text-sm text-warning">
                            <AlertTriangle className="w-4 h-4 inline mr-1.5"/>
                            {analysisErr}
                        </div>}
                        {(not analysisErr) and bool(analysis["root_cause"])
                        and <div className="space-y-1.5 border-t border-line pt-3">
                            <div className="text-sm text-fg">
                                <span className="text-faint">Root cause: </span>
                                {analysis["root_cause"]}
                            </div>
                            <div className="text-sm text-fg">
                                <span className="text-faint">Confidence: </span>
                                {str(analysis["confidence"])}
                            </div>
                            <div className="text-sm text-fg">
                                <span className="text-faint">Recommended: </span>
                                {analysis["recommended_action"]}
                            </div>
                            {bool(len(analysis["ranked_suspects"] or []))
                            and <ul className="text-sm text-muted list-disc pl-5">
                                {[
                                    <li key={sp["service"]}>
                                        {str(sp["service"]) + ": " + str(sp["why"])}
                                    </li> for sp in (analysis["ranked_suspects"] or [])
                                ]}
                            </ul>}
                        </div>}
                    </div>
                </div>

                {isLoading
                and <p className="text-sm text-muted px-1">Building report...</p>}

                {(not isLoading) and (not ok)
                and <div className="bg-surface border border-line rounded-lg p-4 text-sm text-warning">
                    <AlertTriangle className="w-4 h-4 inline mr-1.5"/>
                    {reason}
                </div>}

                {(not isLoading) and ok and bool(health)
                and <div className={sectionCls}>
                    <div className={headCls}>
                        <Activity className="w-4 h-4 text-accent"/>
                        <h2 className="text-sm font-medium text-fg">Health</h2>
                    </div>
                    <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-px bg-line">
                        <div className={statCls}>
                            <div className={labelCls}>Status</div>
                            <div className={valCls}>{str(health["status"])}</div>
                        </div>
                        <div className={statCls}>
                            <div className={labelCls}>Req/s</div>
                            <div className={valCls}>{str(health["req_per_s"])}</div>
                        </div>
                        <div className={statCls}>
                            <div className={labelCls}>Error ratio</div>
                            <div className={valCls}>{str(health["error_rate"])}</div>
                        </div>
                        <div className={statCls}>
                            <div className={labelCls}>p95 (s)</div>
                            <div className={valCls}>{str(health["p95_latency_s"])}</div>
                        </div>
                        <div className={statCls}>
                            <div className={labelCls}>Pods (run/pend/fail)</div>
                            <div className={valCls}>
                                {str(health["pods_running"]) + "/" + str(health["pods_pending"]) + "/" + str(health["pods_failed"])}
                            </div>
                        </div>
                        <div className={statCls}>
                            <div className={labelCls}>Nodes ready</div>
                            <div className={valCls}>{str(health["nodes_ready"])}</div>
                        </div>
                    </div>
                </div>}

                {(not isLoading) and ok and bool(len(pods))
                and <div className={sectionCls}>
                    <div className={headCls}>
                        <Cpu className="w-4 h-4 text-accent"/>
                        <h2 className="text-sm font-medium text-fg">
                            Pod resource usage
                        </h2>
                    </div>
                    <table className="w-full">
                        <thead className="bg-surface-2">
                            <tr>
                                <th className={thCls}>Pod</th>
                                <th className={thCls}>Status</th>
                                <th className={thCls}>CPU (cores)</th>
                                <th className={thCls}>Mem (MB)</th>
                                <th className={thCls}>Restarts</th>
                            </tr>
                        </thead>
                        <tbody>
                            {[
                                <tr key={p["pod"]} className="border-t border-line">
                                    <td className={tdCls + " font-mono text-xs"}>{p["pod"]}</td>
                                    <td className={tdCls}>{str(p["status"])}</td>
                                    <td className={tdCls}>{str(p["cpu_cores"])}</td>
                                    <td className={tdCls}>{str(p["mem_mb"])}</td>
                                    <td className={tdCls}>{str(p["restarts"])}</td>
                                </tr> for p in pods
                            ]}
                        </tbody>
                    </table>
                </div>}

                {(not isLoading) and ok and bool(len(slow))
                and <div className={sectionCls}>
                    <div className={headCls}>
                        <Timer className="w-4 h-4 text-accent"/>
                        <h2 className="text-sm font-medium text-fg">
                            Slowest traces (critical path)
                        </h2>
                    </div>
                    <table className="w-full">
                        <thead className="bg-surface-2">
                            <tr>
                                <th className={thCls}>Trace ID</th>
                                <th className={thCls}>Total (ms)</th>
                                <th className={thCls}>Top hop (self ms)</th>
                            </tr>
                        </thead>
                        <tbody>
                            {[
                                <tr key={t["trace_id"]} className="border-t border-line">
                                    <td className={tdCls + " font-mono text-xs"}>
                                        {t["trace_id"]}
                                    </td>
                                    <td className={tdCls}>{str(t["total_ms"])}</td>
                                    <td className={tdCls + " text-muted"}>
                                        {(str((t["critical_path"] or [{}])[0]["span_name"]) + " (" + str((t["critical_path"] or [{}])[0]["self_ms"]) + ")") if bool(len(t["critical_path"] or [])) else "-"}
                                    </td>
                                </tr> for t in slow
                            ]}
                        </tbody>
                    </table>
                </div>}

                {(not isLoading) and ok and bool(len(errors))
                and <div className={sectionCls}>
                    <div className={headCls}>
                        <Bug className="w-4 h-4 text-accent"/>
                        <h2 className="text-sm font-medium text-fg">
                            Error signatures
                        </h2>
                    </div>
                    <table className="w-full">
                        <thead className="bg-surface-2">
                            <tr>
                                <th className={thCls}>Signature</th>
                                <th className={thCls}>Count</th>
                                <th className={thCls}>Services</th>
                            </tr>
                        </thead>
                        <tbody>
                            {[
                                <tr key={e["signature"]} className="border-t border-line">
                                    <td className={tdCls + " font-mono text-xs"}>
                                        {e["signature"]}
                                    </td>
                                    <td className={tdCls}>{str(e["count"])}</td>
                                    <td className={tdCls + " text-muted"}>
                                        {(e["services"] or []).join(", ")}
                                    </td>
                                </tr> for e in errors
                            ]}
                        </tbody>
                    </table>
                </div>}
            </div>;
    }
}
