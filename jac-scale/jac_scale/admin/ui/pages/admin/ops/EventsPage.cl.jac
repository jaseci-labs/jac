"""Events & Resource Pressure page for the Ops Console.

Reads GET /admin/ops/events and renders recent namespace events
Warning-first, with pressure rows (OOMKilled / FailedScheduling /
Insufficient* / FailedBinding / ImagePullBackOff / Evicted) highlighted
red. A summary bar shows the warning + pressure counts at a glance.
"""

import from "lucide-react" { Activity, RefreshCw, AlertTriangle }

import from react { useEffect }
import from ....context.AuthContext { useAuth }
import from ....services.opsService { getEvents }

def:pub EventsPage -> JsxElement {
    has isLoading: bool = False,
        available: bool = True,
        detail: str = "",
        namespace: str = "",
        events: list = [],
        warnings: int = 0,
        pressure: int = 0,
        errorMsg: str = "",
        loadedOnce: bool = False;

    auth = useAuth();

    async def load {
        isLoading = True;
        try {
            result = await getEvents(auth["authToken"]);
            if result["ok"] and result["data"] {
                data = result["data"];
                available = data["available"] or False;
                detail = data["detail"] or "";
                namespace = data["namespace"] or "";
                events = data["events"] or [];
                warnings = data["warnings"] or 0;
                pressure = data["pressure"] or 0;
                errorMsg = "";
            } elif result["error"] {
                errorMsg = result["error"]["message"] or "Failed to load events";
            }
        } except Exception as e {
            console.error("events load error:", e);
            errorMsg = "Error loading events: " + String(e);
        }
        isLoading = False;
        loadedOnce = True;
    }

    useEffect(lambda { load(); }, []);

    def rowCls(ev: dict) -> str {
        if ev["pressure"] {
            return "border-b border-line/50 bg-danger-weak";
        }
        return "border-b border-line/50";
    }

    def reasonCls(ev: dict) -> str {
        if ev["pressure"] {
            return "py-1.5 pr-3 text-danger font-medium";
        }
        if ev["type"] == "Warning" {
            return "py-1.5 pr-3 text-warning";
        }
        return "py-1.5 pr-3 text-muted";
    }

    return
        <div className="space-y-4">
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                    <Activity className="w-5 h-5 text-accent"/>
                    <h1 className="text-lg font-semibold text-fg">
                        Events & Resource Pressure
                    </h1>
                    {<span className="text-xs text-faint">{namespace}</span>
                        if namespace
                        else None}
                </div>
                <button
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-md bg-surface-2 text-fg border border-line hover:bg-line transition-colors"
                    onClick={lambda { load(); }}
                >
                    <RefreshCw className="w-3.5 h-3.5"/>
                    Refresh
                </button>
            </div>
            {<div
                className="flex items-start gap-2 text-warning text-sm bg-warning-weak border border-line rounded-md p-3"
            >
                <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5"/>
                <span className="text-muted">
                    Cluster view unavailable: {detail}. Enable [plugins.scale.kubernetes].ops_console and redeploy.
                </span>
            </div>
                if (loadedOnce and not available)
                else None}
            {<div className="text-danger text-sm">{errorMsg}</div>
                if errorMsg
                else None}
            {<div className="text-faint text-sm">Loading...</div>
                if (isLoading and not loadedOnce)
                else None}
            {<div className="flex gap-4 text-sm">
                <span
                    className={pressure > 0
                    and "text-danger font-medium"
                    or "text-muted"}
                >
                    {String(pressure)} pressure
                </span>
                <span className={warnings > 0 and "text-warning" or "text-muted"}>
                    {String(warnings)} warnings
                </span>
                <span className="text-faint">{String(len(events))} total</span>
            </div>
                if available
                else None}
            {<div className="overflow-x-auto">
                <table className="w-full text-sm">
                    <thead>
                        <tr className="text-left text-faint border-b border-line">
                            <th className="py-1.5 pr-3 font-medium">Reason</th>
                            <th className="py-1.5 pr-3 font-medium">Object</th>
                            <th className="py-1.5 pr-3 font-medium">Message</th>
                            <th className="py-1.5 pr-3 font-medium">Count</th>
                            <th className="py-1.5 pr-3 font-medium">Last seen</th>
                        </tr>
                    </thead>
                    <tbody>
                        {[
                            <tr
                                key={ev["name"] + ev["reason"] + ev["last_seen"]}
                                className={rowCls(ev)}
                            >
                                <td className={reasonCls(ev)}>{ev["reason"]}</td>
                                <td className="py-1.5 pr-3 text-muted text-xs">
                                    {ev["kind"]}/{ev["name"]}
                                </td>
                                <td
                                    className="py-1.5 pr-3 text-faint text-xs max-w-md truncate"
                                >
                                    {ev["message"]}
                                </td>
                                <td className="py-1.5 pr-3 text-muted">
                                    {String(ev["count"])}
                                </td>
                                <td className="py-1.5 pr-3 text-faint text-xs">
                                    {ev["last_seen"]}
                                </td>
                            </tr> for ev in events
                        ]}
                    </tbody>
                </table>
            </div>
                if (available and len(events) > 0)
                else None}
            {<div className="text-faint text-sm">No recent events.</div>
                if (available and loadedOnce and not errorMsg and len(events) == 0)
                else None}
        </div>;
}
