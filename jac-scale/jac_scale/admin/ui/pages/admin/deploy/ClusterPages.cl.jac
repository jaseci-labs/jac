"""Cluster pages — embed Grafana k8s-cluster dashboard panels in the admin UI.

Each page hydrates `/admin/cluster/info` once and renders Grafana iframes for the
relevant panel IDs from `MonitoringDeployer`'s k8s-cluster dashboard. When the
monitoring stack isn't deployed the page falls back to a "monitoring offline"
notice instead of broken iframes.
"""

cl {
    import from react { useEffect }
    import from ....components.common.GrafanaPanel {
        GrafanaPanel,
        GrafanaUnavailable
    }
    import from ....context.AuthContext { useAuth }
    import from ....services.clusterService { getClusterInfo }

    def:pub DeploymentsPage -> JsxElement {
        has isLoading: bool = True, info: dict = {};

        auth = useAuth();

        async def load {
            result = await getClusterInfo(auth["authToken"]);
            if result["ok"] and result["data"] {
                info = result["data"];
            }
            isLoading = False;
        }

        useEffect(lambda { load(); }, []);

        if isLoading {
            return <div className="text-slate-500 text-sm p-4">Loading cluster info...</div>;
        }
        if not info["enabled"] {
            return <GrafanaUnavailable/>;
        }
        base = info["grafana_base"];
        uid = info["dashboard_uid"];
        return
            <div className="space-y-4">
                <div className="flex items-center gap-4">
                    <h1 className="text-lg font-semibold text-white">Deployments</h1>
                    {info["namespace"] and <span
                        className="text-xs text-slate-500 font-mono"
                    >
                        namespace: {info["namespace"]}
                    </span>}
                </div>
                <GrafanaPanel
                    grafanaBase={base}
                    dashboardUid={uid}
                    panelId={6}
                    title="Deployment Available Replicas"
                    height="320px"
                />
                <GrafanaPanel
                    grafanaBase={base}
                    dashboardUid={uid}
                    panelId={7}
                    title="Pod Container Restarts (last 1h)"
                    height="320px"
                />
            </div>;
    }

    def:pub PodsPage -> JsxElement {
        has isLoading: bool = True, info: dict = {};

        auth = useAuth();

        async def load {
            result = await getClusterInfo(auth["authToken"]);
            if result["ok"] and result["data"] {
                info = result["data"];
            }
            isLoading = False;
        }

        useEffect(lambda { load(); }, []);

        if isLoading {
            return <div className="text-slate-500 text-sm p-4">Loading cluster info...</div>;
        }
        if not info["enabled"] {
            return <GrafanaUnavailable/>;
        }
        base = info["grafana_base"];
        uid = info["dashboard_uid"];
        return
            <div className="space-y-4">
                <div className="flex items-center gap-4">
                    <h1 className="text-lg font-semibold text-white">Pods</h1>
                    {info["namespace"] and <span
                        className="text-xs text-slate-500 font-mono"
                    >
                        namespace: {info["namespace"]}
                    </span>}
                </div>
                <div className="grid grid-cols-3 gap-4">
                    <GrafanaPanel
                        grafanaBase={base}
                        dashboardUid={uid}
                        panelId={3}
                        title="Running"
                        height="160px"
                    />
                    <GrafanaPanel
                        grafanaBase={base}
                        dashboardUid={uid}
                        panelId={4}
                        title="Pending"
                        height="160px"
                    />
                    <GrafanaPanel
                        grafanaBase={base}
                        dashboardUid={uid}
                        panelId={5}
                        title="Failed"
                        height="160px"
                    />
                </div>
                <GrafanaPanel
                    grafanaBase={base}
                    dashboardUid={uid}
                    panelId={15}
                    title="Pods per Node"
                    height="320px"
                />
                <div className="grid grid-cols-2 gap-4">
                    <GrafanaPanel
                        grafanaBase={base}
                        dashboardUid={uid}
                        panelId={10}
                        title="Pod CPU Requests"
                        height="320px"
                    />
                    <GrafanaPanel
                        grafanaBase={base}
                        dashboardUid={uid}
                        panelId={11}
                        title="Pod Memory Requests"
                        height="320px"
                    />
                </div>
            </div>;
    }

    def:pub ScalingPage -> JsxElement {
        has isLoading: bool = True, info: dict = {};

        auth = useAuth();

        async def load {
            result = await getClusterInfo(auth["authToken"]);
            if result["ok"] and result["data"] {
                info = result["data"];
            }
            isLoading = False;
        }

        useEffect(lambda { load(); }, []);

        if isLoading {
            return <div className="text-slate-500 text-sm p-4">Loading cluster info...</div>;
        }
        if not info["enabled"] {
            return <GrafanaUnavailable/>;
        }
        base = info["grafana_base"];
        uid = info["dashboard_uid"];
        return
            <div className="space-y-4">
                <div className="flex items-center gap-4">
                    <h1 className="text-lg font-semibold text-white">Scaling &amp; Nodes</h1>
                    {info["namespace"] and <span
                        className="text-xs text-slate-500 font-mono"
                    >
                        namespace: {info["namespace"]}
                    </span>}
                </div>
                <div className="grid grid-cols-3 gap-4">
                    <GrafanaPanel
                        grafanaBase={base}
                        dashboardUid={uid}
                        panelId={12}
                        title="Total Nodes"
                        height="160px"
                    />
                    <GrafanaPanel
                        grafanaBase={base}
                        dashboardUid={uid}
                        panelId={13}
                        title="Ready"
                        height="160px"
                    />
                    <GrafanaPanel
                        grafanaBase={base}
                        dashboardUid={uid}
                        panelId={14}
                        title="Not Ready"
                        height="160px"
                    />
                </div>
                <div className="grid grid-cols-2 gap-4">
                    <GrafanaPanel
                        grafanaBase={base}
                        dashboardUid={uid}
                        panelId={16}
                        title="Node CPU Usage (%)"
                        height="320px"
                    />
                    <GrafanaPanel
                        grafanaBase={base}
                        dashboardUid={uid}
                        panelId={17}
                        title="Node Memory Usage (%)"
                        height="320px"
                    />
                </div>
                <div className="grid grid-cols-2 gap-4">
                    <GrafanaPanel
                        grafanaBase={base}
                        dashboardUid={uid}
                        panelId={18}
                        title="CPU Requests per Node"
                        height="320px"
                    />
                    <GrafanaPanel
                        grafanaBase={base}
                        dashboardUid={uid}
                        panelId={19}
                        title="Memory Requests per Node"
                        height="320px"
                    />
                </div>
            </div>;
    }
}
