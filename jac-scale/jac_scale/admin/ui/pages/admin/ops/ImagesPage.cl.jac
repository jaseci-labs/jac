"""Image / Build Freshness page for the Ops Console (V-06).

Reads GET /admin/ops/images and renders one card per app showing:
  - the running image tag(s),
  - the resolved sha256 digest(s) across replicas - more than one =
    cross-replica DRIFT (the image-cache bug), highlighted red,
  - the B-01 build identity (JAC_BUILD_SHA / JAC_IMAGE_REF) so an operator
    can confirm the deploy actually shipped the commit they expect.
"""

import from "lucide-react" { Container, RefreshCw, AlertTriangle, GitCommitHorizontal }

import from react { useEffect }
import from ....context.AuthContext { useAuth }
import from ....services.opsService { getImages }

def:pub ImagesPage -> JsxElement {
    has isLoading: bool = False,
        available: bool = True,
        detail: str = "",
        namespace: str = "",
        apps: list = [],
        errorMsg: str = "",
        loadedOnce: bool = False;

    auth = useAuth();

    async def load {
        isLoading = True;
        try {
            result = await getImages(auth["authToken"]);
            if result["ok"] and result["data"] {
                data = result["data"];
                available = data["available"] or False;
                detail = data["detail"] or "";
                namespace = data["namespace"] or "";
                apps = data["apps"] or [];
                errorMsg = "";
            } elif result["error"] {
                errorMsg = result["error"]["message"] or "Failed to load image freshness";
            }
        } except Exception as e {
            console.error("images load error:", e);
            errorMsg = "Error loading image freshness: " + String(e);
        }
        isLoading = False;
        loadedOnce = True;
    }

    useEffect(lambda { load(); }, []);

    def shortDigest(d: str) -> str {
        # imageID looks like `repo@sha256:abcd...`; show the last 19.
        idx = d.indexOf("sha256:");
        if idx >= 0 {
            return d.substring(idx, idx + 19);
        }
        if len(d) > 24 {
            return d.substring(0, 24);
        }
        return d;
    }

    return
        <div className="space-y-4">
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                    <Container className="w-5 h-5 text-accent"/>
                    <h1 className="text-lg font-semibold text-fg">
                        Image & Build Freshness
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

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                {[
                    <div
                        key={a["app"]}
                        className={"rounded-lg border bg-surface p-4 space-y-2 " + (
                            "border-danger/40"
                                if a["drift"]
                                else "border-line"
                        )}
                    >
                        <div className="flex items-center justify-between">
                            <h2 className="text-sm font-semibold text-fg">
                                {a["app"]}
                            </h2>
                            <span className="text-xs text-faint">
                                {String(a["replicas"])} replica(s)
                            </span>
                        </div>
                        <div className="text-xs font-mono text-muted truncate">
                            {(a["tags"] or []).join(", ")}
                        </div>
                        {[
                            <div key={dg} className="text-[11px] font-mono text-faint">
                                {shortDigest(dg)}
                            </div> for dg in (a["distinct_digests"] or [])
                        ]}
                        {<div className="flex items-center gap-1.5 text-danger text-xs font-medium">
                            <AlertTriangle className="w-3.5 h-3.5"/>
                            Cross-replica digest drift ({String(len(a["distinct_digests"] or []))} distinct)
                        </div>
                            if a["drift"]
                            else None}
                        {<div className="flex items-center gap-1.5 text-xs text-muted pt-1 border-t border-line">
                            <GitCommitHorizontal className="w-3.5 h-3.5 text-accent"/>
                            <span className="font-mono">
                                {a["build_sha"] or "no JAC_BUILD_SHA"}
                            </span>
                        </div>
                            if (a["build_sha"] or a["image_ref"])
                            else None}
                    </div> for a in apps
                ]}
            </div>
            {<div className="text-faint text-sm">
                No pods in this namespace.
            </div>
                if (available and loadedOnce and len(apps) == 0)
                else None}
        </div>;
}