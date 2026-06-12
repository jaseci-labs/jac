"""Controlled Actions page for the Ops Console (V-10, Tier 2).

Service-driven: it loads the live deployments (gateway + every microservice)
from /admin/ops/deploy, so you act on a real target picked from a list -
never a blind-typed name. Per service you can rollout-restart or scale; a
"Restart all services" button rolls the whole app; a pod picker force-
deletes a single pod; and a PVC field clears stuck finalizers. Every action
goes through a confirm dialog, and is admin-gated + audit-logged server-side
behind the `ops_console_mutations` RBAC (a 403 detail shows if it's absent).
"""

import from "lucide-react" {
    Wrench,
    RotateCw,
    Scaling,
    Trash2,
    Magnet,
    RefreshCw,
    AlertTriangle,
    Layers
}

import from react { useEffect }
import from ....context.AuthContext { useAuth }
import from ....services.opsService {
    getDeployHealth,
    rolloutRestart,
    scaleDeployment,
    deletePod,
    unstickPvc
}

def:pub ActionsPage -> JsxElement {
    has isLoading: bool = False,
        available: bool = True,
        detail: str = "",
        namespace: str = "",
        deployments: list = [],
        pods: list = [],
        selectedPod: str = "",
        pvcName: str = "",
        pending: dict = {},
        pendingReplicas: int = 1,
        busy: bool = False,
        message: str = "",
        isError: bool = False,
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
            } elif result["error"] {
                message = result["error"]["message"] or "Failed to load targets";
                isError = True;
            }
        } except Exception as e {
            console.error("actions load error:", e);
            message = "Error loading targets: " + String(e);
            isError = True;
        }
        isLoading = False;
        loadedOnce = True;
    }

    useEffect(lambda { load(); }, []);

    def report(result: dict) {
        if result["ok"] and result["data"] {
            message = result["data"]["message"] or "Done";
            isError = False;
        } elif result["error"] {
            message = result["error"]["message"] or "Action failed";
            isError = True;
        } else {
            message = "Action failed";
            isError = True;
        }
    }

    # ---- open the confirm dialog for each action --------------------
    def askRestart(name: str) {
        pending = {
            "kind": "restart",
            "target": name,
            "label": "Rollout restart " + name + "?",
            "danger": False
        };
    }
    def askRestartAll {
        pending = {
            "kind": "restart-all",
            "target": "",
            "label": "Rollout restart ALL " + String(len(deployments)) + " service(s)?",
            "danger": True
        };
    }
    def askScale(name: str, desired: int) {
        pendingReplicas = desired;
        pending = {
            "kind": "scale",
            "target": name,
            "label": "Scale " + name,
            "danger": False
        };
    }
    def askDelete {
        if not selectedPod {
            return;
        }
        pending = {
            "kind": "delete",
            "target": selectedPod,
            "label": "Delete pod " + selectedPod + "?",
            "danger": True
        };
    }
    def askUnstick {
        if not pvcName {
            return;
        }
        pending = {
            "kind": "unstick",
            "target": pvcName,
            "label": "Clear finalizers on PVC " + pvcName + "?",
            "danger": True
        };
    }
    def cancel {
        pending = {};
    }

    async def restartAll {
        okCount = 0;
        failCount = 0;
        for d in deployments {
            try {
                r = await rolloutRestart(auth["authToken"], d["name"]);
                if r["ok"] {
                    okCount += 1;
                } else {
                    failCount += 1;
                }
            } except Exception as e {
                console.error("restart-all error:", e);
                failCount += 1;
            }
        }
        message = "Restarted " + String(okCount) + " service(s)" + (
            ", " + String(failCount) + " failed"
                if failCount > 0
                else ""
        );
        isError = failCount > 0;
    }

    async def runPending {
        kind = pending["kind"];
        target = pending["target"];
        pending = {};
        busy = True;
        message = "";
        try {
            if kind == "restart" {
                report(await rolloutRestart(auth["authToken"], target));
            } elif kind == "restart-all" {
                await restartAll();
            } elif kind == "scale" {
                report(await scaleDeployment(auth["authToken"], target, pendingReplicas));
            } elif kind == "delete" {
                report(await deletePod(auth["authToken"], target));
            } elif kind == "unstick" {
                report(await unstickPvc(auth["authToken"], target));
            }
        } except Exception as e {
            message = "Error: " + String(e);
            isError = True;
        }
        busy = False;
        load();
    }

    # ---- helpers (return strings) -----------------------------------
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

    btnSm = "inline-flex items-center justify-center gap-1.5 px-2.5 py-1 text-xs rounded-md transition-colors disabled:opacity-40 disabled:cursor-not-allowed";
    inputCls = "bg-surface border border-line rounded px-2 py-1.5 text-sm text-fg";

    # ---- render -----------------------------------------------------
    return
        <div className="space-y-4">
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                    <Wrench className="w-5 h-5 text-accent"/>
                    <h1 className="text-lg font-semibold text-fg">
                        Controlled Actions
                    </h1>
                    {<span className="text-xs text-faint">{namespace}</span>
                        if namespace
                        else None}
                </div>
                <div className="flex items-center gap-2">
                    <button
                        className={btnSm + " bg-warning-weak text-warning border border-warning/40 hover:bg-warning/10 px-3 py-1.5 text-sm"}
                        disabled={busy or len(deployments) == 0}
                        onClick={lambda { askRestartAll(); }}
                    >
                        <Layers className="w-3.5 h-3.5"/>
                        Restart all services
                    </button>
                    <button
                        className={btnSm + " bg-surface-2 text-fg border border-line hover:bg-line px-3 py-1.5 text-sm"}
                        onClick={lambda { load(); }}
                    >
                        <RefreshCw className="w-3.5 h-3.5"/>
                        Refresh
                    </button>
                </div>
            </div>
            <div className="flex items-center gap-2 text-xs text-faint">
                <AlertTriangle className="w-3.5 h-3.5"/>
                <span>
                    Mutating + audit-logged. Needs [plugins.scale.kubernetes].ops_console_mutations; a 403 means the RBAC isn't bound.
                </span>
            </div>

            {<div className={"text-sm rounded-md p-3 border border-line " + (
                "bg-danger-weak text-danger"
                    if isError
                    else "bg-success-weak text-success"
            )}>
                {message}
            </div>
                if message
                else None}
            {<div
                className="flex items-start gap-2 text-warning text-sm bg-warning-weak border border-line rounded-md p-3"
            >
                <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5"/>
                <span className="text-muted">
                    Cluster view unavailable: {detail}. Enable [plugins.scale.kubernetes].ops_console (+ ops_console_mutations to act) and redeploy.
                </span>
            </div>
                if (loadedOnce and not available)
                else None}
            {<div className="text-faint text-sm">Loading services...</div>
                if (isLoading and not loadedOnce)
                else None}

            {<div className="space-y-2">
                <div className="text-xs uppercase tracking-wide text-faint">
                    Services ({len(deployments)})
                </div>
                {[
                    <div
                        key={d["name"]}
                        className="flex items-center justify-between rounded-lg border border-line bg-surface p-3 gap-3"
                    >
                        <div className="min-w-0">
                            <div className="text-sm font-medium text-fg truncate">
                                {d["name"]}
                            </div>
                            <div className="flex items-center gap-2 mt-0.5">
                                <span className="text-xs text-muted">
                                    {String(d["ready"])}/{String(d["desired"])} ready
                                </span>
                                <span className={rolloutCls(d["rollout"]["status"])}>
                                    {d["rollout"]["status"]}
                                </span>
                            </div>
                        </div>
                        <div className="flex items-center gap-2 shrink-0">
                            <button
                                className={btnSm + " bg-surface-2 text-fg border border-line hover:bg-line"}
                                disabled={busy}
                                onClick={lambda { askScale(d["name"], d["desired"]); }}
                            >
                                <Scaling className="w-3.5 h-3.5"/>
                                Scale
                            </button>
                            <button
                                className={btnSm + " bg-surface-2 text-fg border border-line hover:bg-line"}
                                disabled={busy}
                                onClick={lambda { askRestart(d["name"]); }}
                            >
                                <RotateCw className="w-3.5 h-3.5"/>
                                Restart
                            </button>
                        </div>
                    </div> for d in deployments
                ]}
                {<div className="text-faint text-sm">
                    No deployments in this namespace.
                </div>
                    if (available and loadedOnce and len(deployments) == 0)
                    else None}
            </div>
                if available
                else None}

            {<div className="grid grid-cols-1 lg:grid-cols-2 gap-4 pt-2">
                <div className="rounded-lg border border-line bg-surface p-4 space-y-2">
                    <div className="flex items-center gap-2 text-sm font-semibold text-fg">
                        <Trash2 className="w-4 h-4 text-danger"/>
                        Force-delete a pod
                    </div>
                    <p className="text-xs text-faint">
                        Deletes one pod; its controller recreates a fresh replacement.
                    </p>
                    <div className="flex items-center gap-2">
                        <select
                            value={selectedPod}
                            onChange={lambda e: any { selectedPod = e.target.value; }}
                            className={inputCls + " flex-1"}
                        >
                            <option value="">Select a pod...</option>
                            {[<option key={p["name"]} value={p["name"]}>{p["name"]}</option> for p in pods]}
                        </select>
                        <button
                            className={btnSm + " bg-danger-weak text-danger border border-danger/40 hover:bg-danger/10 px-3 py-1.5 text-sm"}
                            disabled={busy or not selectedPod}
                            onClick={lambda { askDelete(); }}
                        >
                            Delete
                        </button>
                    </div>
                </div>

                <div className="rounded-lg border border-line bg-surface p-4 space-y-2">
                    <div className="flex items-center gap-2 text-sm font-semibold text-fg">
                        <Magnet className="w-4 h-4 text-danger"/>
                        Unstick a terminating PVC
                    </div>
                    <p className="text-xs text-faint">
                        Clears finalizers on a PVC stuck in Terminating (see Endpoints & Storage for names).
                    </p>
                    <div className="flex items-center gap-2">
                        <input
                            className={inputCls + " flex-1"}
                            placeholder="pvc name"
                            value={pvcName}
                            onChange={lambda e: any { pvcName = e.target.value; }}
                        />
                        <button
                            className={btnSm + " bg-danger-weak text-danger border border-danger/40 hover:bg-danger/10 px-3 py-1.5 text-sm"}
                            disabled={busy or not pvcName}
                            onClick={lambda { askUnstick(); }}
                        >
                            Clear
                        </button>
                    </div>
                </div>
            </div>
                if available
                else None}

            {<div
                className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
                onClick={cancel}
            >
                <div
                    className="w-full max-w-md rounded-lg border border-line bg-surface p-5 space-y-4"
                    onClick={lambda e: any { e.stopPropagation(); }}
                >
                    <div className="flex items-center gap-2">
                        <AlertTriangle className={"w-5 h-5 " + (
                            "text-danger" if pending["danger"] else "text-warning"
                        )}/>
                        <h2 className="text-sm font-semibold text-fg">
                            {pending["label"]}
                        </h2>
                    </div>
                    {<div className="space-y-1">
                        <label className="text-xs text-faint">Replicas</label>
                        <input
                            className={inputCls + " w-full"}
                            type="number"
                            min="0"
                            max="50"
                            value={String(pendingReplicas)}
                            onChange={lambda e: any { pendingReplicas = Number(e.target.value); }}
                        />
                    </div>
                        if pending["kind"] == "scale"
                        else None}
                    <div className="flex justify-end gap-2">
                        <button
                            className={btnSm + " bg-surface-2 text-fg border border-line hover:bg-line px-3 py-1.5 text-sm"}
                            onClick={cancel}
                        >
                            Cancel
                        </button>
                        <button
                            className={btnSm + " px-3 py-1.5 text-sm " + (
                                "bg-danger-weak text-danger border border-danger/40 hover:bg-danger/10"
                                    if pending["danger"]
                                    else "bg-accent text-accent-fg hover:opacity-90"
                            )}
                            onClick={lambda { runPending(); }}
                        >
                            Confirm
                        </button>
                    </div>
                </div>
            </div>
                if pending["kind"]
                else None}
        </div>;
}