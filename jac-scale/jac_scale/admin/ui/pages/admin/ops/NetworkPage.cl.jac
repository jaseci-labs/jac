"""Endpoints / Ingress / Storage page for the Ops Console.

Reads GET /admin/ops/network and renders three sections, kubeconfig-free:
  - Services: type, clusterIP, ports, and ready backend count (0 ready =
    the classic "no endpoints -> 503" cause, highlighted red).
  - Ingress: host -> path -> service:port rules + the load-balancer
    address actually serving traffic.
  - PVCs: bind phase (Bound green / Pending red), capacity, storage class,
    and which pods currently mount each claim.
"""

import from "lucide-react" { Network, RefreshCw, AlertTriangle }

import from react { useEffect }
import from ....context.AuthContext { useAuth }
import from ....services.opsService { getNetwork }

def:pub NetworkPage -> JsxElement {
    has isLoading: bool = False,
        available: bool = True,
        detail: str = "",
        namespace: str = "",
        services: list = [],
        ingresses: list = [],
        pvcs: list = [],
        errorMsg: str = "",
        loadedOnce: bool = False;

    auth = useAuth();

    async def load {
        isLoading = True;
        try {
            result = await getNetwork(auth["authToken"]);
            if result["ok"] and result["data"] {
                data = result["data"];
                available = data["available"] or False;
                detail = data["detail"] or "";
                namespace = data["namespace"] or "";
                services = data["services"] or [];
                ingresses = data["ingresses"] or [];
                pvcs = data["pvcs"] or [];
                errorMsg = "";
            } elif result["error"] {
                errorMsg = result["error"]["message"] or "Failed to load network view";
            }
        } except Exception as e {
            console.error("network load error:", e);
            errorMsg = "Error loading network view: " + String(e);
        }
        isLoading = False;
        loadedOnce = True;
    }

    useEffect(lambda { load(); }, []);

    def portsLabel(ports: list) -> str {
        parts: list = [];
        for p in ports {
            parts.push(String(p["port"]) + "->" + String(p["target"]));
        }
        return parts.join(", ");
    }

    def pvcPhaseCls(phase: str) -> str {
        base = "text-[11px] font-medium px-2 py-0.5 rounded ";
        if phase == "Bound" {
            return base + "bg-success-weak text-success";
        }
        return base + "bg-danger-weak text-danger";
    }

    # ExternalName / headless (clusterIP None) services have no Endpoints by
    # design, so 0 ready backends is expected for them - don't flag red.
    def backendCls(s: dict) -> str {
        base = "py-1.5 pr-3 ";
        if s["type"] == "ExternalName" or s["cluster_ip"] == "None" {
            return base + "text-muted";
        }
        if s["ready_backends"] == 0 {
            return base + "text-danger font-medium";
        }
        return base + "text-success";
    }

    return
        <div className="space-y-4">
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                    <Network className="w-5 h-5 text-accent"/>
                    <h1 className="text-lg font-semibold text-fg">
                        Endpoints & Storage
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
            {<div className="space-y-2">
                <div className="text-xs uppercase tracking-wide text-faint">
                    Services ({len(services)})
                </div>
                <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                        <thead>
                            <tr className="text-left text-faint border-b border-line">
                                <th className="py-1.5 pr-3 font-medium">Name</th>
                                <th className="py-1.5 pr-3 font-medium">Type</th>
                                <th className="py-1.5 pr-3 font-medium">Cluster IP</th>
                                <th className="py-1.5 pr-3 font-medium">Ports</th>
                                <th className="py-1.5 pr-3 font-medium">
                                    Ready backends
                                </th>
                            </tr>
                        </thead>
                        <tbody>
                            {[
                                <tr key={s["name"]} className="border-b border-line/50">
                                    <td className="py-1.5 pr-3 text-fg font-medium">
                                        {s["name"]}
                                    </td>
                                    <td className="py-1.5 pr-3 text-muted">
                                        {s["type"]}
                                    </td>
                                    <td
                                        className="py-1.5 pr-3 text-faint font-mono text-xs"
                                    >
                                        {s["cluster_ip"]}
                                    </td>
                                    <td className="py-1.5 pr-3 text-faint text-xs">
                                        {portsLabel(s["ports"] or [])}
                                    </td>
                                    <td className={backendCls(s)}>
                                        {String(s["ready_backends"])}
                                    </td>
                                </tr> for s in services
                            ]}
                        </tbody>
                    </table>
                </div>
            </div>
                if (available and len(services) > 0)
                else None}
            {<div className="space-y-2">
                <div className="text-xs uppercase tracking-wide text-faint">
                    Ingress
                </div>
                {[
                    <div
                        key={ing["name"]}
                        className="rounded-lg border border-line bg-surface p-3 space-y-1.5"
                    >
                        <div className="flex items-center justify-between">
                            <span className="text-sm font-medium text-fg">
                                {ing["name"]}
                            </span>
                            <span className="text-xs text-faint font-mono">
                                {(ing["lb"] or []).join(", ") or "no LB address"}
                            </span>
                        </div>
                        {[
                            <div
                                key={r["host"] + r["path"] + r["service"]}
                                className="text-xs text-muted font-mono"
                            >
                                {r["host"] or "*"}{r["path"]} {"->"} {r["service"]}:{String(
                                    r["port"]
                                )}
                            </div> for r in (ing["rules"] or [])
                        ]}
                    </div> for ing in ingresses
                ]}
            </div>
                if (available and len(ingresses) > 0)
                else None}
            {<div className="space-y-2">
                <div className="text-xs uppercase tracking-wide text-faint">
                    Persistent Volume Claims ({len(pvcs)})
                </div>
                <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                        <thead>
                            <tr className="text-left text-faint border-b border-line">
                                <th className="py-1.5 pr-3 font-medium">Name</th>
                                <th className="py-1.5 pr-3 font-medium">Phase</th>
                                <th className="py-1.5 pr-3 font-medium">Capacity</th>
                                <th className="py-1.5 pr-3 font-medium">
                                    Storage class
                                </th>
                                <th className="py-1.5 pr-3 font-medium">Claimants</th>
                            </tr>
                        </thead>
                        <tbody>
                            {[
                                <tr key={v["name"]} className="border-b border-line/50">
                                    <td className="py-1.5 pr-3 text-fg font-medium">
                                        {v["name"]}
                                    </td>
                                    <td className="py-1.5 pr-3">
                                        <span className={pvcPhaseCls(v["phase"])}>
                                            {v["phase"]}
                                        </span>
                                    </td>
                                    <td className="py-1.5 pr-3 text-muted">
                                        {v["capacity"]}
                                    </td>
                                    <td className="py-1.5 pr-3 text-faint text-xs">
                                        {v["storage_class"]}
                                    </td>
                                    <td className="py-1.5 pr-3 text-faint text-xs">
                                        {(v["claimants"] or []).join(", ")
                                        or "unmounted"}
                                    </td>
                                </tr> for v in pvcs
                            ]}
                        </tbody>
                    </table>
                </div>
            </div>
                if (available and len(pvcs) > 0)
                else None}
            {<div className="text-faint text-sm">
                No services, ingresses, or PVCs in this namespace.
            </div>
                if (
                    available
                    and loadedOnce
                    and not errorMsg
                    and len(services) == 0
                    and len(ingresses) == 0
                    and len(pvcs) == 0
                )
                else None}
        </div>;
}
