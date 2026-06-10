"""Performance Analyst page (A-07): the deterministic incident digest.

Renders the reduce-before-the-model funnel output from /admin/analyst/digest -
ranked metric symptoms (current vs baseline), slow-trace exemplars, and grouped
error signatures - all pre-aggregated server-side. No model output yet; this is
the substrate the REASON stage (A-07.b) will explain. Purely presentational:
every number/string is computed by the backend.
"""

cl import from "lucide-react" { Activity, RefreshCw, AlertTriangle, Timer, Bug }

cl {
    import from react { useEffect }
    import from ....components.common.Button { Button }
    import from ....context.AuthContext { useAuth }
    import from ....services.analystService { getAnalystDigest }

    def:pub AnalystPage -> JsxElement {
        has isLoading: bool = True,
            ok: bool = True,
            reason: str = "",
            digest: dict = {};

        auth = useAuth();

        async def load {
            isLoading = True;
            res = await getAnalystDigest(auth["authToken"]);
            if res["ok"] and res["data"] {
                digest = res["data"];
                ok = True;
            } else {
                ok = False;
                err = res["error"] or {};
                reason = err["message"] or "Analyst digest unavailable";
            }
            isLoading = False;
        }

        useEffect(lambda { load(); }, []);

        def fmtDelta(d: float) -> str {
            sign = "+" if d >= 0 else "";
            return sign + str(d) + "%";
        }

        symptoms = (digest["symptoms"] if digest else []) or [];
        exemplars = (digest["exemplar_traces"] if digest else []) or [];
        errors = (digest["error_signatures"] if digest else []) or [];
        hasAny = bool(len(symptoms)) or bool(len(exemplars)) or bool(len(errors));

        sectionCls = "bg-surface border border-line rounded-lg overflow-hidden shadow-sm";
        headCls = "flex items-center gap-2 px-4 py-3 border-b border-line";
        thCls = "text-left text-xs text-faint font-medium px-4 py-2";
        tdCls = "px-4 py-2 text-sm text-fg tabular-nums";

        return
            <div className="space-y-4">
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2.5">
                        <Activity className="w-5 h-5 text-accent"/>
                        <h1 className="text-lg font-semibold text-fg">
                            Performance Analyst
                        </h1>
                        <span className="text-xs text-faint">incident digest</span>
                    </div>
                    <Button variant="secondary" onClick={lambda { load(); }}>
                        <RefreshCw className="w-3.5 h-3.5"/>
                        Refresh
                    </Button>
                </div>

                {isLoading
                and <p className="text-sm text-muted px-1">Building digest...</p>}

                {(not isLoading) and (not ok)
                and <div className="bg-surface border border-line rounded-lg p-4 text-sm text-warning">
                    <AlertTriangle className="w-4 h-4 inline mr-1.5"/>
                    {reason}
                </div>}

                {(not isLoading) and ok and (not hasAny)
                and <div className="bg-surface border border-line rounded-lg p-4 text-sm text-muted">
                    No anomalies detected (or signals unavailable off-cluster).
                    The digest is empty - nothing to reason over right now.
                </div>}

                {(not isLoading) and ok and bool(len(symptoms))
                and <div className={sectionCls}>
                    <div className={headCls}>
                        <Activity className="w-4 h-4 text-accent"/>
                        <h2 className="text-sm font-medium text-fg">
                            Metric symptoms (vs baseline)
                        </h2>
                    </div>
                    <table className="w-full">
                        <thead className="bg-surface-2">
                            <tr>
                                <th className={thCls}>Signal</th>
                                <th className={thCls}>Baseline</th>
                                <th className={thCls}>Current</th>
                                <th className={thCls}>Change</th>
                            </tr>
                        </thead>
                        <tbody>
                            {[
                                <tr key={s["name"]} className="border-t border-line">
                                    <td className={tdCls}>{s["name"]}</td>
                                    <td className={tdCls}>{str(s["baseline"])}</td>
                                    <td className={tdCls}>{str(s["current"])}</td>
                                    <td className={tdCls + " text-accent"}>
                                        {fmtDelta(s["delta_pct"])}
                                    </td>
                                </tr> for s in symptoms
                            ]}
                        </tbody>
                    </table>
                </div>}

                {(not isLoading) and ok and bool(len(exemplars))
                and <div className={sectionCls}>
                    <div className={headCls}>
                        <Timer className="w-4 h-4 text-accent"/>
                        <h2 className="text-sm font-medium text-fg">
                            Slow-trace exemplars
                        </h2>
                    </div>
                    <table className="w-full">
                        <thead className="bg-surface-2">
                            <tr>
                                <th className={thCls}>Trace ID</th>
                                <th className={thCls}>Total (ms)</th>
                            </tr>
                        </thead>
                        <tbody>
                            {[
                                <tr key={t["trace_id"]} className="border-t border-line">
                                    <td className={tdCls + " font-mono text-xs"}>
                                        {t["trace_id"]}
                                    </td>
                                    <td className={tdCls}>{str(t["total_ms"])}</td>
                                </tr> for t in exemplars
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
