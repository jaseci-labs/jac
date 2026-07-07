"""Deploy Health page for the Ops Console.

Reads GET /admin/ops/deploy and renders two tables, kubeconfig-free:
  - Deployments: ready/desired replicas + rollout status (complete /
    progressing / stuck) + the spec image(s).
  - Pods: phase, ready containers, restart count (highlighted when > 0),
    node, and per-container state (running / waiting:<reason> /
    terminated:<reason>).

Off-cluster (or before the Ops Console RBAC is applied) it shows a single
"unavailable" banner with the reason, never an error.
"""

import from "lucide-react" { Boxes }

import from react { useEffect }
import from ....components.common.PageHeader { PageHeader, OpsUnavailableBanner }
import from ....context.AuthContext { useAuth }
import from ....services.opsService { getDeployHealth }
import from ....utils.api { getErrorMessage }

def:pub DeployPage -> JsxElement {
    has isLoading: bool = False,
        available: bool = True,
        detail: str = "",
        namespace: str = "",
        deployments: list = [],
        pods: list = [],
        errorMsg: str = "",
        loadedOnce: bool = False;

    auth = useAuth();

    async def load {
        isLoading = True;
        try {
            result = await getDeployHealth(auth["authToken"]);
            if result["ok"] and result["data"] {
                data = result["data"];
                available = data["available"] or False;
                detail = data["detail"] or "";
                namespace = data["namespace"] or "";
                deployments = data["deployments"] or [];
                pods = data["pods"] or [];
                errorMsg = "";
            } elif result["error"] {
                errorMsg = getErrorMessage(result, "Failed to load deploy health");
            }
        } except Exception as e {
            console.error("deploy health load error:", e);
            errorMsg = "Error loading deploy health: " + String(e);
        }
        isLoading = False;
        loadedOnce = True;
    }

    useEffect(lambda { load(); }, []);

    # ---- helpers (return strings, never JSX) -------------------------
    def rolloutCls(status: str) -> str {
        base = "text-[11px] font-semibold uppercase tracking-wide px-2 py-0.5 rounded ";
        if status == "complete" {
            return base + "bg-success-weak text-success";
        }
        if status == "stuck" {
            return base + "bg-danger-weak text-danger";
        }
        return base + "bg-warning-weak text-warning";
    }

    def phaseCls(phase: str) -> str {
        base = "text-[11px] font-medium px-2 py-0.5 rounded ";
        if phase == "Running" or phase == "Succeeded" {
            return base + "bg-success-weak text-success";
        }
        if phase == "Pending" {
            return base + "bg-warning-weak text-warning";
        }
        return base + "bg-danger-weak text-danger";
    }

    def containerSummary(containers: list) -> str {
        parts: list = [];
        for c in containers {
            tag = c["state"];
            if c["reason"] {
                tag = c["state"] + ":" + c["reason"];
            }
            parts.push(c["name"] + " (" + tag + ")");
        }
        return parts.join(", ");
    }

    # ---- render ------------------------------------------------------
    return
        <div className="space-y-4">
            <PageHeader
                icon={Boxes}
                title="Deploy Health"
                namespace={namespace}
                onRefresh={lambda { load(); }}
            />
            <OpsUnavailableBanner
                show={loadedOnce and not available}
                detail={detail}
                remediation="Set [scale.kubernetes].ops_console = true and redeploy so the read-only Role is bound to the gateway ServiceAccount."
            />
            {<div className="text-danger text-sm">{errorMsg}</div>
                if errorMsg
                else None}
            {<div className="text-faint text-sm">Loading...</div>
                if (isLoading and not loadedOnce)
                else None}
            {<div className="space-y-2">
                <div className="text-xs uppercase tracking-wide text-faint">
                    Deployments ({len(deployments)})
                </div>
                <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                        <thead>
                            <tr className="text-left text-faint border-b border-line">
                                <th className="py-1.5 pr-3 font-medium">Name</th>
                                <th className="py-1.5 pr-3 font-medium">Ready</th>
                                <th className="py-1.5 pr-3 font-medium">Rollout</th>
                                <th className="py-1.5 pr-3 font-medium">Image</th>
                            </tr>
                        </thead>
                        <tbody>
                            {[
                                <tr key={d["name"]} className="border-b border-line/50">
                                    <td className="py-1.5 pr-3 text-fg font-medium">
                                        {d["name"]}
                                    </td>
                                    <td
                                        className={"py-1.5 pr-3 " + (
                                            "text-success"
                                                if (
                                                    d["ready"] == d["desired"]
                                                    and d["desired"] > 0
                                                )
                                                else "text-warning"
                                        )}
                                    >
                                        {String(d["ready"])}/{String(d["desired"])}
                                    </td>
                                    <td className="py-1.5 pr-3">
                                        <span
                                            className={rolloutCls(
                                                d["rollout"]["status"]
                                            )}
                                        >
                                            {d["rollout"]["status"]}
                                        </span>
                                    </td>
                                    <td
                                        className="py-1.5 pr-3 text-faint text-xs font-mono truncate max-w-xs"
                                    >
                                        {(d["images"] or []).join(", ")}
                                    </td>
                                </tr> for d in deployments
                            ]}
                        </tbody>
                    </table>
                </div>
            </div>
                if (available and len(deployments) > 0)
                else None}
            {<div className="space-y-2">
                <div className="text-xs uppercase tracking-wide text-faint">
                    Pods ({len(pods)})
                </div>
                <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                        <thead>
                            <tr className="text-left text-faint border-b border-line">
                                <th className="py-1.5 pr-3 font-medium">Pod</th>
                                <th className="py-1.5 pr-3 font-medium">Phase</th>
                                <th className="py-1.5 pr-3 font-medium">Ready</th>
                                <th className="py-1.5 pr-3 font-medium">Restarts</th>
                                <th className="py-1.5 pr-3 font-medium">Containers</th>
                                <th className="py-1.5 pr-3 font-medium">Node</th>
                            </tr>
                        </thead>
                        <tbody>
                            {[
                                <tr key={p["name"]} className="border-b border-line/50">
                                    <td
                                        className="py-1.5 pr-3 text-fg truncate max-w-xs"
                                    >
                                        {p["name"]}
                                    </td>
                                    <td className="py-1.5 pr-3">
                                        <span className={phaseCls(p["phase"])}>
                                            {p["phase"]}
                                        </span>
                                    </td>
                                    <td className="py-1.5 pr-3 text-muted">
                                        {String(p["ready"])}/{String(p["total"])}
                                    </td>
                                    <td
                                        className={"py-1.5 pr-3 " + (
                                            "text-danger font-medium"
                                                if p["restarts"] > 0
                                                else "text-muted"
                                        )}
                                    >
                                        {String(p["restarts"])}
                                    </td>
                                    <td className="py-1.5 pr-3 text-faint text-xs">
                                        {containerSummary(p["containers"] or [])}
                                    </td>
                                    <td
                                        className="py-1.5 pr-3 text-faint text-xs truncate max-w-xs"
                                    >
                                        {p["node"]}
                                    </td>
                                </tr> for p in pods
                            ]}
                        </tbody>
                    </table>
                </div>
            </div>
                if (available and len(pods) > 0)
                else None}
            {<div className="text-faint text-sm">
                No deployments or pods in this namespace.
            </div>
                if (
                    available
                    and loadedOnce
                    and not errorMsg
                    and len(deployments) == 0
                    and len(pods) == 0
                )
                else None}
        </div>;
}
