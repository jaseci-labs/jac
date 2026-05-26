"""Grafana iframe embed components for cluster panels.

`GrafanaPanel` renders a single panel via Grafana's `/d-solo/` endpoint.
`GrafanaDashboard` embeds an entire dashboard in kiosk mode.

Both rely on Grafana being served at the same origin (NGINX ingress at /grafana)
with `GF_SECURITY_ALLOW_EMBEDDING=true` and anonymous Viewer role enabled.
"""

cl {
    def:pub GrafanaPanel(
        grafanaBase: str,
        dashboardUid: str,
        panelId: int,
        title: str = "",
        height: str = "300px",
        slug: str = "panel"
    ) -> JsxElement {
        src = grafanaBase + "/d-solo/" + dashboardUid + "/" + slug
            + "?orgId=1&panelId=" + str(panelId)
            + "&theme=dark&refresh=30s&kiosk";
        return
            <div
                className="bg-slate-900 border border-slate-800 rounded-lg overflow-hidden"
            >
                {title and <div
                    className="px-4 py-2 border-b border-slate-800 text-xs text-slate-400 font-mono uppercase tracking-wider"
                >
                    {title}
                </div>}
                <iframe
                    src={src}
                    width="100%"
                    height={height}
                    frameBorder="0"
                    className="block w-full bg-slate-950"
                ></iframe>
            </div>;
    }

    def:pub GrafanaDashboard(
        grafanaBase: str,
        dashboardUid: str,
        height: str = "1200px",
        slug: str = "dashboard"
    ) -> JsxElement {
        src = grafanaBase + "/d/" + dashboardUid + "/" + slug
            + "?orgId=1&theme=dark&refresh=30s&kiosk";
        return
            <div
                className="bg-slate-900 border border-slate-800 rounded-lg overflow-hidden"
            >
                <iframe
                    src={src}
                    width="100%"
                    height={height}
                    frameBorder="0"
                    className="block w-full bg-slate-950"
                ></iframe>
            </div>;
    }

    def:pub GrafanaUnavailable(message: str = "") -> JsxElement {
        body = message or "Kubernetes monitoring is not enabled. Set [monitoring] enabled = true and k8s_metrics_enabled = true in jac.toml, then redeploy.";
        return
            <div
                className="bg-slate-900 border border-orange-500/30 rounded-lg p-8 text-center"
            >
                <div
                    className="w-12 h-12 mx-auto mb-3 rounded-full bg-slate-800 border border-orange-500/50 flex items-center justify-center"
                >
                    <span className="text-orange-400 text-xl">!</span>
                </div>
                <h2 className="text-sm font-medium text-white mb-1">
                    Cluster Monitoring Offline
                </h2>
                <p className="text-xs text-slate-500 font-mono">{body}</p>
            </div>;
    }
}
