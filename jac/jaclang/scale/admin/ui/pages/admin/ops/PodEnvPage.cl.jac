"""Pod Environment page for the Ops Console.

Reads GET /admin/ops/podenv and renders this pod's own process env plus
each pod's configured spec env. Values are allowlist-redacted server-side:
allowed keys show their value (mono), masked keys show `********`, and
secretRef/configMapRef keys show `(from secret)` - so the page can never
display secret material. A pod selector switches between this pod and the
listed pods.
"""

import from "lucide-react" { KeyRound, Lock }

import from react { useEffect }
import from ....components.common.PageHeader { PageHeader, OpsUnavailableBanner }
import from ....context.AuthContext { useAuth }
import from ....services.opsService { getPodEnv }
import from ....utils.api { getErrorMessage }

def:pub PodEnvPage -> JsxElement {
    has isLoading: bool = False,
        available: bool = True,
        detail: str = "",
        namespace: str = "",
        thisPod: list = [],
        pods: list = [],
        selected: str = "__self__",
        errorMsg: str = "",
        loadedOnce: bool = False;

    auth = useAuth();

    async def load {
        isLoading = True;
        try {
            result = await getPodEnv(auth["authToken"]);
            if result["ok"] and result["data"] {
                data = result["data"];
                available = data["available"] or False;
                detail = data["detail"] or "";
                namespace = data["namespace"] or "";
                thisPod = data["this_pod"] or [];
                pods = data["pods"] or [];
                errorMsg = "";
            } elif result["error"] {
                errorMsg = getErrorMessage(result, "Failed to load pod env");
            }
        } except Exception as e {
            console.error("podenv load error:", e);
            errorMsg = "Error loading pod env: " + String(e);
        }
        isLoading = False;
        loadedOnce = True;
    }

    useEffect(
        lambda {
            load();
            return;
        },
        []
    );

    # Resolve the currently-selected env list (this pod vs a named pod).
    def selectedEnv -> list {
        if selected == "__self__" {
            return thisPod;
        }
        for p in pods {
            if p["pod"] == selected {
                return p["env"] or [];
            }
        }
        return [];
    }

    rows = selectedEnv();

    return
        <div className="space-y-4">
            <PageHeader
                icon={KeyRound}
                title="Pod Environment"
                namespace={namespace}
                onRefresh={lambda { load(); }}
            />
            <div className="flex items-center gap-2 text-xs text-faint">
                <Lock className="w-3.5 h-3.5"/>
                <span>
                    Allowlist-redacted: only OTEL_*/JAC_*/K8S_*-class values shown; secrets never resolved.
                </span>
            </div>
            {<div className="text-danger text-sm">{errorMsg}</div>
                if errorMsg
                else None}
            {<div className="text-faint text-sm">Loading...</div>
                if (isLoading and not loadedOnce)
                else None}
            <OpsUnavailableBanner
                show={loadedOnce and not available}
                detail={detail}
                label="Other pods unavailable"
                remediation="Showing this pod only. Enable [scale.kubernetes].ops_console for the rest."
            />
            <select
                value={selected}
                onChange={lambda (e: any) { selected = e.target.value; }}
                className="bg-surface border border-line rounded px-2 py-1.5 text-sm text-fg"
            >
                <option value="__self__">This pod (gateway)</option>
                {[
                    <option key={p["pod"]} value={p["pod"]}>{p["pod"]}</option>
                    for p in pods
                ]}
            </select>
            <div className="overflow-x-auto">
                <table className="w-full text-sm">
                    <thead>
                        <tr className="text-left text-faint border-b border-line">
                            <th className="py-1.5 pr-3 font-medium">Key</th>
                            <th className="py-1.5 pr-3 font-medium">Value</th>
                        </tr>
                    </thead>
                    <tbody>
                        {[
                            <tr key={en["name"]} className="border-b border-line/50">
                                <td className="py-1.5 pr-3 text-fg font-mono text-xs">
                                    {en["name"]}
                                </td>
                                <td
                                    className={"py-1.5 pr-3 font-mono text-xs " + (
                                        "text-muted"
                                            if en["shown"]
                                            else "text-faint italic"
                                    )}
                                >
                                    {en["value"]}
                                </td>
                            </tr> for en in rows
                        ]}
                    </tbody>
                </table>
            </div>
            {<div className="text-faint text-sm">No env on this target.</div>
                if (loadedOnce and not errorMsg and len(rows) == 0)
                else None}
        </div>;
}
