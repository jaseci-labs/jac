"""Controlled Actions page for the Ops Console (V-10, Tier 2).

Four mutating operations, each behind a typed confirmation (you must
re-type the exact target name before the button arms): rollout-restart and
scale a deployment, delete a pod, unstick a terminating PVC. Every call is
admin-gated and audit-logged server-side and needs the
`ops_console_mutations` RBAC; without it the action returns a 403 detail.
"""

cl import from "lucide-react" { Wrench, RotateCw, Scaling, Trash2, Magnet, AlertTriangle }

cl {
    import from ....context.AuthContext { useAuth }
    import from ....services.opsService {
        rolloutRestart,
        scaleDeployment,
        deletePod,
        unstickPvc
    }

    def:pub ActionsPage -> JsxElement {
        has restartTarget: str = "",
            restartConfirm: str = "",
            scaleTarget: str = "",
            scaleReplicas: int = 1,
            scaleConfirm: str = "",
            deleteTarget: str = "",
            deleteConfirm: str = "",
            unstickTarget: str = "",
            unstickConfirm: str = "",
            busy: str = "",
            message: str = "",
            isError: bool = False;

        auth = useAuth();

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

        async def doRestart {
            busy = "restart";
            message = "";
            try {
                report(await rolloutRestart(auth["authToken"], restartTarget));
            } except Exception as e {
                message = "Error: " + String(e);
                isError = True;
            }
            busy = "";
        }

        async def doScale {
            busy = "scale";
            message = "";
            try {
                report(await scaleDeployment(auth["authToken"], scaleTarget, scaleReplicas));
            } except Exception as e {
                message = "Error: " + String(e);
                isError = True;
            }
            busy = "";
        }

        async def doDelete {
            busy = "delete";
            message = "";
            try {
                report(await deletePod(auth["authToken"], deleteTarget));
            } except Exception as e {
                message = "Error: " + String(e);
                isError = True;
            }
            busy = "";
        }

        async def doUnstick {
            busy = "unstick";
            message = "";
            try {
                report(await unstickPvc(auth["authToken"], unstickTarget));
            } except Exception as e {
                message = "Error: " + String(e);
                isError = True;
            }
            busy = "";
        }

        inputCls = "bg-surface border border-line rounded px-2 py-1.5 text-sm text-fg w-full";
        btnCls = "inline-flex items-center justify-center gap-1.5 px-3 py-1.5 text-sm rounded-md transition-colors disabled:opacity-40 disabled:cursor-not-allowed";

        return
            <div className="space-y-4">
                <div className="flex items-center gap-2.5">
                    <Wrench className="w-5 h-5 text-accent"/>
                    <h1 className="text-lg font-semibold text-fg">Controlled Actions</h1>
                </div>
                <div className="flex items-center gap-2 text-xs text-faint">
                    <AlertTriangle className="w-3.5 h-3.5"/>
                    <span>
                        Mutating + audit-logged. Re-type the exact target name to arm each action. Needs [plugins.scale.kubernetes].ops_console_mutations.
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

                <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                    <div className="rounded-lg border border-line bg-surface p-4 space-y-2">
                        <div className="flex items-center gap-2 text-sm font-semibold text-fg">
                            <RotateCw className="w-4 h-4 text-accent"/>
                            Rollout restart
                        </div>
                        <input className={inputCls} placeholder="deployment name (e.g. gateway-deployment)"
                            value={restartTarget}
                            onChange={lambda e: any { restartTarget = e.target.value; }}/>
                        <input className={inputCls} placeholder="re-type name to confirm"
                            value={restartConfirm}
                            onChange={lambda e: any { restartConfirm = e.target.value; }}/>
                        <button
                            className={btnCls + " bg-surface-2 text-fg border border-line hover:bg-line"}
                            disabled={busy != "" or not restartTarget or restartConfirm != restartTarget}
                            onClick={lambda { doRestart(); }}
                        >
                            {busy == "restart" and "Restarting..." or "Rollout restart"}
                        </button>
                    </div>

                    <div className="rounded-lg border border-line bg-surface p-4 space-y-2">
                        <div className="flex items-center gap-2 text-sm font-semibold text-fg">
                            <Scaling className="w-4 h-4 text-accent"/>
                            Scale deployment
                        </div>
                        <input className={inputCls} placeholder="deployment name"
                            value={scaleTarget}
                            onChange={lambda e: any { scaleTarget = e.target.value; }}/>
                        <input className={inputCls} type="number" min="0" max="50"
                            value={String(scaleReplicas)}
                            onChange={lambda e: any { scaleReplicas = Number(e.target.value); }}/>
                        <input className={inputCls} placeholder="re-type name to confirm"
                            value={scaleConfirm}
                            onChange={lambda e: any { scaleConfirm = e.target.value; }}/>
                        <button
                            className={btnCls + " bg-surface-2 text-fg border border-line hover:bg-line"}
                            disabled={busy != "" or not scaleTarget or scaleConfirm != scaleTarget}
                            onClick={lambda { doScale(); }}
                        >
                            {busy == "scale" and "Scaling..." or "Scale"}
                        </button>
                    </div>

                    <div className="rounded-lg border border-line bg-surface p-4 space-y-2">
                        <div className="flex items-center gap-2 text-sm font-semibold text-fg">
                            <Trash2 className="w-4 h-4 text-danger"/>
                            Delete pod
                        </div>
                        <input className={inputCls} placeholder="pod name"
                            value={deleteTarget}
                            onChange={lambda e: any { deleteTarget = e.target.value; }}/>
                        <input className={inputCls} placeholder="re-type name to confirm"
                            value={deleteConfirm}
                            onChange={lambda e: any { deleteConfirm = e.target.value; }}/>
                        <button
                            className={btnCls + " bg-danger-weak text-danger border border-danger/40 hover:bg-danger/10"}
                            disabled={busy != "" or not deleteTarget or deleteConfirm != deleteTarget}
                            onClick={lambda { doDelete(); }}
                        >
                            {busy == "delete" and "Deleting..." or "Delete pod"}
                        </button>
                    </div>

                    <div className="rounded-lg border border-line bg-surface p-4 space-y-2">
                        <div className="flex items-center gap-2 text-sm font-semibold text-fg">
                            <Magnet className="w-4 h-4 text-danger"/>
                            Unstick PVC
                        </div>
                        <input className={inputCls} placeholder="pvc name"
                            value={unstickTarget}
                            onChange={lambda e: any { unstickTarget = e.target.value; }}/>
                        <input className={inputCls} placeholder="re-type name to confirm"
                            value={unstickConfirm}
                            onChange={lambda e: any { unstickConfirm = e.target.value; }}/>
                        <button
                            className={btnCls + " bg-danger-weak text-danger border border-danger/40 hover:bg-danger/10"}
                            disabled={busy != "" or not unstickTarget or unstickConfirm != unstickTarget}
                            onClick={lambda { doUnstick(); }}
                        >
                            {busy == "unstick" and "Clearing..." or "Clear finalizers"}
                        </button>
                    </div>
                </div>
            </div>;
    }
}
