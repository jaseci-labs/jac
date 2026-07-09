import yaml;
import from typing { Any }
import from jaclang.cli.console { console }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.deploy.target.kubernetes.microservice.manifest_builder {
    GATEWAY_NAME
}
import from jaclang.scale.runtime.cli.diagnostics {
    Diagnostic,
    PlanValidator,
    has_errors
}
import from jaclang.scale.runtime.cli._narrow { dget, iget, lget, pod_spec, sget }


def _diags_for(diagnostics: list[Diagnostic], service: str | None) -> list[Diagnostic] {
    return [
        d
        for d in diagnostics
        if d.service == service
    ];
}


def _print_diag(d: Diagnostic, indent: str = "    ") {
    marker = "X" if d.severity == "error" else "!";
    style = "error" if d.severity == "error" else "warning";
    console.print(f"{indent}{marker} {d.message}", style=style);
}


def _resource_range(req: str | None, lim: str | None) -> str {
    if req is None and lim is None {
        return "(unset)";
    }
    if lim is None {
        return f"{req} (no limit)";
    }
    if req is None {
        return f"(no request) -> {lim}";
    }
    return f"{req} -> {lim}";
}


obj HPAView {
    has min_replicas: int,
        max_replicas: int,
        cpu_target: int;

    static def from_manifest(hpa: Any) -> HPAView | None {
        if not isinstance(hpa, dict) {
            return None;
        }
        return HPAView(
            min_replicas=iget(hpa, "min", 1),
            max_replicas=iget(hpa, "max", 1),
            cpu_target=iget(hpa, "cpu_target", 0)
        );
    }
}


obj PDBView {
    has max_unavailable: int | None;

    static def from_manifest(pdb: Any) -> PDBView | None {
        if not isinstance(pdb, dict) {
            return None;
        }
        raw = dget(pdb, "spec").get("maxUnavailable");
        if raw is None {
            return PDBView(max_unavailable=None);
        }
        try {
            return PDBView(max_unavailable=int(raw));
        } except Exception {
            return PDBView(max_unavailable=None);
        }
    }
}


obj ServiceView {
    has name: str,
        image: str,
        replicas: int,
        cpu_request: str | None = None,
        cpu_limit: str | None = None,
        mem_request: str | None = None,
        mem_limit: str | None = None,
        container_port: int | None = None,
        route_path: str | None = None,
        env_keys: list[str] = [],
        secret_ref_count: int = 0,
        hpa: HPAView | None = None,
        pdb: PDBView | None = None,
        mounts: list[tuple[str, str]] = [];

    static def from_manifests(
        name: str, deployment: Any, hpa: Any, pdb: Any, route_path: str | None
    ) -> ServiceView {
        containers = lget(pod_spec(deployment), "containers");
        container: dict = {};
        if containers and isinstance(containers[0], dict) {
            container = dict(containers[0]);
        }

        resources = dget(container, "resources");
        requests = dget(resources, "requests");
        limits = dget(resources, "limits");

        container_port: int | None = None;
        ports = lget(container, "ports");
        if ports and isinstance(ports[0], dict) {
            raw = ports[0].get("containerPort");
            if raw is not None {
                try {
                    container_port = int(raw);
                } except Exception {
                    container_port = None;
                }
            }
        }

        env_keys: list[str] = [];
        secret_refs: int = 0;
        for e in lget(container, "env") {
            if not isinstance(e, dict) {
                continue;
            }
            if e.get("valueFrom") {
                secret_refs += 1;
                continue;
            }
            ename = sget(e, "name");
            if ename {
                env_keys.append(ename);
            }
        }

        mounts: list[tuple[str, str]] = [];
        for m in lget(container, "volumeMounts") {
            if not isinstance(m, dict) {
                continue;
            }
            mounts.append((sget(m, "name") or "?", sget(m, "mountPath") or "?"));
        }

        return ServiceView(
            name=name,
            image=sget(container, "image") or "(not resolved)",
            replicas=iget(dget(deployment, "spec"), "replicas", 1),
            cpu_request=sget(requests, "cpu"),
            cpu_limit=sget(limits, "cpu"),
            mem_request=sget(requests, "memory"),
            mem_limit=sget(limits, "memory"),
            container_port=container_port,
            route_path=route_path,
            env_keys=env_keys,
            secret_ref_count=secret_refs,
            hpa=HPAView.from_manifest(hpa),
            pdb=PDBView.from_manifest(pdb),
            mounts=mounts
        );
    }

    def render(diagnostics: list[Diagnostic]) {
        if self.hpa is not None {
            h = self.hpa;

            target_str = (
                f"@ {h.cpu_target}% CPU" if h.cpu_target > 0 else "(no CPU target)"
            );
            replicas_line = (
                f"{self.replicas}  "
                f"(HPA: {h.min_replicas} -> {h.max_replicas} {target_str})"
            );
        } else {
            replicas_line = str(self.replicas);
        }

        console.print();
        console.print(f"  {self.name}", style="bold");
        console.print(f"    image:     {self.image}");
        console.print(f"    replicas:  {replicas_line}");
        console.print(
            f"    resources: cpu {_resource_range(self.cpu_request, self.cpu_limit)}"
            f"    mem {_resource_range(self.mem_request, self.mem_limit)}"
        );
        if self.container_port is not None {
            console.print(f"    port:      {self.container_port}");
        }
        if self.route_path is not None {
            console.print(f"    route:     {self.route_path}  (via gateway)");
        } elif self.name != GATEWAY_NAME {
            console.print("    route:     (internal-only, no gateway path)");
        }
        if self.env_keys or self.secret_ref_count {
            env_line = ", ".join(self.env_keys[:5]) if self.env_keys else "(none)";
            if len(self.env_keys) > 5 {
                env_line += f", +{len(self.env_keys) - 5} more";
            }
            if self.secret_ref_count {
                env_line += f"  (+ {self.secret_ref_count} secret-refs)";
            }
            console.print(f"    env:       {env_line}");
        }
        if self.pdb is not None and self.pdb.max_unavailable is not None {
            console.print(f"    pdb:       maxUnavailable={self.pdb.max_unavailable}");
        }
        if self.mounts {
            parts = [f"{n} @ {p}" for (n, p) in self.mounts];
            console.print(f"    mounts:    {', '.join(parts)}");
        }
        for d in _diags_for(diagnostics, self.name) {
            _print_diag(d);
        }
    }
}


obj IngressRuleView {
    has host: str,
        paths: list[tuple[str, str]];
}


obj IngressView {
    has rules: list[IngressRuleView];

    static def from_manifest(ingress: Any, routes: dict) -> IngressView | None {
        if not isinstance(ingress, dict) {
            return None;
        }
        rules: list[IngressRuleView] = [];
        for rule in lget(dget(ingress, "spec"), "rules") {
            if not isinstance(rule, dict) {
                continue;
            }
            paths: list[tuple[str, str]] = [];
            for (svc, path) in routes.items() {
                if svc == GATEWAY_NAME {
                    continue;
                }
                paths.append((str(path), str(svc)));
            }
            paths.append(("/", "gateway"));
            rules.append(
                IngressRuleView(host=sget(rule, "host") or "(any host)", paths=paths)
            );
        }
        return IngressView(rules=rules) if rules else None;
    }

    def render {
        console.print();
        console.print("Ingress", style="bold");
        for rule in self.rules {
            console.print(f"  {rule.host}");
            for (path, svc) in rule.paths {
                console.print(f"    {path:<10s} -> {svc}");
            }
        }
    }
}


def _render_cluster_wide(bundle: Any, ms_cfg: Any) -> None {
    lines: list[str] = [];

    rl = dget(ms_cfg, "rate_limit");
    if isinstance(rl, dict) and rl.get("enabled") {
        rpm = iget(rl, "requests_per_minute", 0);
        if rpm {
            lines.append(f"  rate_limit:  {rpm}/min per IP");
        }
    }

    cors = dget(ms_cfg, "cors");
    if isinstance(cors, dict) and cors.get("enabled") {
        raw = cors.get("allow_origins");
        if isinstance(raw, list) and raw {
            lines.append(f"  cors:        allow_origins={[str(o) for o in raw]}");
        } else {
            lines.append("  cors:        enabled");
        }
    }

    us = bundle.get("user_secret") if isinstance(bundle, dict) else None;
    if isinstance(us, dict) {
        name = sget(dget(us, "metadata"), "name") or "?";
        data = dget(us, "data") or dget(us, "stringData");
        lines.append(f"  user_secret: {name} ({len(data)} keys)");
    }

    if not lines {
        return;
    }
    console.print();
    console.print("Cluster-wide", style="bold");
    for line in lines {
        console.print(line);
    }
}


def _render_totals(bundle: Any) {
    def _n(key: str, label: str) -> str | None {
        n = len(dget(bundle, key));
        return f"{n} {label}{'s' if n != 1 else ''}" if n else None;
    }
    parts: list[str] = [];
    n_dep = len(dget(bundle, "deployments"));
    n_svc = len(dget(bundle, "services"));
    parts.append(f"{n_dep} deployment{'s' if n_dep != 1 else ''}");
    parts.append(f"{n_svc} service{'s' if n_svc != 1 else ''}");
    for (key, label) in [
        ("autoscalers", "Autoscaler"),
        ("pdbs", "PDB"),
        ("pvcs", "PVC")
    ] {
        entry = _n(key, label);
        if entry {
            parts.append(entry);
        }
    }
    if isinstance(bundle, dict) and bundle.get("ingress") {
        parts.append("1 ingress");
    }
    console.print();
    console.print("Totals", style="bold");
    console.print(f"  {', '.join(parts)}");
}


obj Plan {
    has bundle: dict,
        ms_cfg: dict,
        svc_configs: dict,
        cluster_type: str,
        namespace: str,
        services: list[ServiceView],
        ingress: IngressView | None;

    static def from_target(target: Any, app_config: AppConfig) -> Plan {
        bundle_raw = target.generate_manifests(app_config);
        bundle: dict = bundle_raw if isinstance(bundle_raw, dict) else {};
        (ms_cfg, svc_configs) = Plan._load_ms_cfg();

        routes_any: Any = ms_cfg.get("routes", {});
        routes: dict = {};
        if isinstance(routes_any, dict) {
            routes = routes_any;
        }
        deployments = dget(bundle, "deployments");
        autoscalers = dget(bundle, "autoscalers");
        pdbs = dget(bundle, "pdbs");

        user_routes: list[str] = [
            str(r)
            for r in routes
            if r != GATEWAY_NAME
        ];
        ordered: list[str] = [
            r
            for r in user_routes
            if r in deployments
        ];
        if GATEWAY_NAME in deployments {
            ordered.append(GATEWAY_NAME);
        }
        for k in deployments {
            k_str = str(k);
            if k_str not in ordered {
                ordered.append(k_str);
            }
        }

        services: list[ServiceView] = [];
        for svc in ordered {
            route_path: str | None = str(routes[svc]) if svc in routes else None;
            services.append(
                ServiceView.from_manifests(
                    name=svc,
                    deployment=deployments.get(svc),
                    hpa=autoscalers.get(svc),
                    pdb=pdbs.get(svc),
                    route_path=route_path
                )
            );
        }

        return Plan(
            bundle=bundle,
            ms_cfg=ms_cfg,
            svc_configs=svc_configs,
            cluster_type="(active kubectl context)",
            namespace=str(target.k8s_config.namespace),
            services=services,
            ingress=IngressView.from_manifest(bundle.get("ingress"), routes)
        );
    }

    static def _load_ms_cfg -> tuple[dict, dict] {
        try {
            import from jaclang.scale.config.config_loader { get_scale_config }
            raw: Any = get_scale_config().get_microservices_config();
            ms_cfg: dict = raw if isinstance(raw, dict) else {};
            services_raw: Any = ms_cfg.get("services", {});
            svc_configs: dict = {};
            if isinstance(services_raw, dict) {
                for (name, cfg) in services_raw.items() {
                    if isinstance(cfg, dict) {
                        svc_configs[str(name)] = cfg;
                    }
                }
            }
            return (ms_cfg, svc_configs);
        } except Exception {
            return ({}, {});
        }
    }

    def validate -> list[Diagnostic] {
        return PlanValidator(
            bundle=self.bundle, ms_cfg=self.ms_cfg, svc_configs=self.svc_configs
        ).run();
    }

    def render(diagnostics: list[Diagnostic], show_yaml: bool = False) {
        self._render_header(diagnostics);
        self._render_global_diags(diagnostics);
        self._render_services(diagnostics);
        if self.ingress is not None {
            self.ingress.render();
        }
        _render_cluster_wide(self.bundle, self.ms_cfg);
        _render_totals(self.bundle);
        self._render_yaml_or_hint(show_yaml);
    }

    def _render_header(diagnostics: list[Diagnostic]) {
        n_err = len(
            [
                d
                for d in diagnostics
                if d.severity == "error"
            ]
        );
        n_warn = len(
            [
                d
                for d in diagnostics
                if d.severity == "warn"
            ]
        );
        console.print();
        console.print("=== jac scale plan: dry-run ===", style="bold cyan");
        console.print(
            f"Cluster:    {self.cluster_type}    Namespace: {self.namespace}",
            style="bold"
        );
        if n_err {
            console.print(
                f"X {n_err} error{'s' if n_err != 1 else ''}, "
                f"{n_warn} warning{'s' if n_warn != 1 else ''}  -  "
                f"fix errors before deploying",
                style="error"
            );
        } elif n_warn {
            console.print(
                f"! {n_warn} warning{'s' if n_warn != 1 else ''}  -  "
                f"advisory; deploy not blocked",
                style="warning"
            );
        } else {
            console.print("check: no errors or warnings", style="success");
        }
    }

    def _render_global_diags(diagnostics: list[Diagnostic]) -> None {
        globals_ = _diags_for(diagnostics, None);
        if not globals_ {
            return;
        }
        console.print();
        console.print("Global findings", style="bold");
        for d in globals_ {
            _print_diag(d, indent="  ");
        }
    }

    def _render_services(diagnostics: list[Diagnostic]) -> None {
        if not self.services {
            console.print();
            console.print(
                "(no microservices declared in [scale.microservices.routes])",
                style="muted"
            );
            return;
        }
        console.print();
        console.print(f"Microservices ({len(self.services)})", style="bold");
        for svc in self.services {
            svc.render(diagnostics);
        }
    }

    def _render_yaml_or_hint(show_yaml: bool) {
        if show_yaml {
            console.print();
            console.print("--- YAML (would be applied) ---", style="bold");
            console.print(
                yaml.safe_dump_all(
                    self._flatten_manifests(), default_flow_style=False, sort_keys=False
                )
            );
        } else {
            console.print();
            console.print(
                "To see the raw YAML manifests, re-run with --show-yaml", style="muted"
            );
        }
    }

    def _flatten_manifests -> list {
        out: list = [];
        if self.bundle.get("user_secret") {
            out.append(self.bundle["user_secret"]);
        }
        for key in ["pvcs", "deployments", "services", "pdbs"] {
            for m in dget(self.bundle, key).values() {
                out.append(m);
            }
        }
        if self.bundle.get("ingress") {
            out.append(self.bundle["ingress"]);
        }
        return out;
    }
}


def print_plan(
    target: Any, app_config: AppConfig, show_yaml: bool = False
) -> tuple[dict, list[Diagnostic]] {
    plan = Plan.from_target(target, app_config);
    diagnostics = plan.validate();
    plan.render(diagnostics, show_yaml=show_yaml);
    return (plan.bundle, diagnostics);
}
