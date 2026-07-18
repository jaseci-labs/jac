import from typing { Any }
import from jaclang.scale.deploy.target.kubernetes.microservice.manifest_builder {
    GATEWAY_NAME
}
import from jaclang.scale.runtime.cli._narrow {
    bget,
    dget,
    effective_resources,
    iget,
    lget,
    pod_spec,
    sget
}


obj Diagnostic {
    has severity: str,
        message: str,
        service: str | None = None;
}


def _cpu_to_millicores(val: Any) -> int | None {
    if val is None {
        return None;
    }
    s = str(val).strip();
    if not s {
        return None;
    }
    try {
        if s.endswith("m") {
            return int(float(s[:-1]));
        }
        return int(float(s) * 1000);
    } except Exception {
        return None;
    }
}


def _mem_to_bytes(val: Any) -> int | None {
    if val is None {
        return None;
    }
    s = str(val).strip();
    if not s {
        return None;
    }
    units: dict[str, int] = {
        "Ki": 1024,
        "Mi": 1024 ** 2,
        "Gi": 1024 ** 3,
        "Ti": 1024 ** 4,
        "K": 1000,
        "M": 1000 ** 2,
        "G": 1000 ** 3,
        "T": 1000 ** 4
    };
    for (suffix, mult) in units.items() {
        if s.endswith(suffix) {
            try {
                return int(float(s[:-len(suffix)]) * mult);
            } except Exception {
                return None;
            }
        }
    }
    try {
        return int(s);
    } except Exception {
        return None;
    }
}


obj PlanValidator {
    has bundle: Any,
        ms_cfg: Any,
        svc_configs: Any;

    def run -> list[Diagnostic] {
        out: list[Diagnostic] = [];
        routes = dget(self.ms_cfg, "routes");
        deployments = dget(self.bundle, "deployments");

        self._check_routes(routes, out);

        cfgs: dict = self.svc_configs if isinstance(self.svc_configs, dict) else {};
        for svc_name_raw in routes {
            if svc_name_raw == GATEWAY_NAME {
                continue;
            }
            svc_name = str(svc_name_raw);
            svc_cfg = cfgs.get(svc_name, {});
            deployment = deployments.get(svc_name);
            if deployment is None {
                out.append(
                    Diagnostic(
                        severity="error",
                        service=svc_name,
                        message=(
                            f"route '{svc_name}' has no generated Deployment "
                            "manifest; check that the .jac file exists in the "
                            "project directory"
                        )
                    )
                );
                continue;
            }
            self._check_hpa(svc_name, svc_cfg, deployment, out);
            self._check_pdb(svc_name, svc_cfg, deployment, out);
            self._check_resources(svc_name, deployment, out);
            self._check_image(svc_name, deployment, out);
        }
        return out;
    }

    def _check_routes(routes: dict, out: list[Diagnostic]) {
        if GATEWAY_NAME in routes {
            out.append(
                Diagnostic(
                    severity="error",
                    message=(
                        f"route name '{GATEWAY_NAME}' is reserved for the internal "
                        "gateway sentinel; rename this microservice in "
                        "[scale.microservices.routes]"
                    )
                )
            );
        }
        seen: dict[str, str] = {};
        for (svc, path) in routes.items() {
            path_s = str(path);
            if path_s in seen {
                out.append(
                    Diagnostic(
                        severity="error",
                        message=(
                            f"route path {path_s!r} is claimed by both "
                            f"'{seen[path_s]}' and '{svc}'; each gateway path "
                            "must be unique"
                        )
                    )
                );
            } else {
                seen[path_s] = str(svc);
            }
        }
    }

    def _check_hpa(
        svc_name: str, svc_cfg: Any, deployment: Any, out: list[Diagnostic]
    ) {
        hpa = dget(svc_cfg, "hpa");
        if not bget(hpa, "enabled", True) {
            return;
        }
        hpa_min = iget(hpa, "min", 1);
        hpa_max = iget(hpa, "max", 3);
        hpa_cpu = iget(hpa, "cpu_target", 70);
        if hpa_min < 1 {
            out.append(
                Diagnostic(
                    severity="error",
                    service=svc_name,
                    message=f"HPA min={hpa_min}; must be >= 1"
                )
            );
        }
        if hpa_min > hpa_max {
            out.append(
                Diagnostic(
                    severity="error",
                    service=svc_name,
                    message=f"HPA min ({hpa_min}) > max ({hpa_max}); swap or fix"
                )
            );
        }
        if hpa_cpu < 1 or hpa_cpu > 100 {
            out.append(
                Diagnostic(
                    severity="error",
                    service=svc_name,
                    message=f"HPA cpu_target={hpa_cpu}; must be 1-100"
                )
            );
        }
        hpa_mem = iget(hpa, "memory_target", 80);
        if hpa_mem < 1 or hpa_mem > 100 {
            out.append(
                Diagnostic(
                    severity="error",
                    service=svc_name,
                    message=f"HPA memory_target={hpa_mem}; must be 1-100"
                )
            );
        }

        (cpu_req, _, mem_req, _) = effective_resources(deployment);
        if cpu_req is None {
            out.append(
                Diagnostic(
                    severity="warn",
                    service=svc_name,
                    message=(
                        f"HPA targets {hpa_cpu}% CPU but cpu_request is unset; "
                        "HPA can't compute utilization without a request baseline"
                    )
                )
            );
        }
        if mem_req is None {
            out.append(
                Diagnostic(
                    severity="warn",
                    service=svc_name,
                    message=(
                        f"HPA targets {hpa_mem}% memory but memory_request is unset; "
                        "HPA can't compute utilization without a request baseline"
                    )
                )
            );
        }
    }

    def _check_pdb(
        svc_name: str, svc_cfg: Any, deployment: Any, out: list[Diagnostic]
    ) {
        pdb_cfg = dget(svc_cfg, "pdb");
        if not bget(pdb_cfg, "enabled", True) {
            return;
        }

        max_un = iget(pdb_cfg, "max_unavailable", 1);
        replicas = iget(dget(deployment, "spec"), "replicas", 1);
        if max_un < 1 and replicas <= 1 {
            out.append(
                Diagnostic(
                    severity="warn",
                    service=svc_name,
                    message=(
                        f"pdb.max_unavailable={max_un} with replicas={replicas} "
                        "forbids voluntary disruption; node drains will block. "
                        "Set max_unavailable >= 1 or scale replicas."
                    )
                )
            );
        }
    }

    def _check_resources(svc_name: str, deployment: Any, out: list[Diagnostic]) {
        (cpu_req, cpu_lim, mem_req, mem_lim) = effective_resources(deployment);
        cpu_req_m = _cpu_to_millicores(cpu_req);
        cpu_lim_m = _cpu_to_millicores(cpu_lim);
        mem_req_b = _mem_to_bytes(mem_req);
        mem_lim_b = _mem_to_bytes(mem_lim);

        if cpu_req is not None and cpu_req_m is None {
            out.append(
                Diagnostic(
                    severity="error",
                    service=svc_name,
                    message=(
                        f"cpu_request={cpu_req!r} is not a valid Kubernetes CPU "
                        "quantity (e.g. '500m', '1')"
                    )
                )
            );
        }
        if cpu_lim is not None and cpu_lim_m is None {
            out.append(
                Diagnostic(
                    severity="error",
                    service=svc_name,
                    message=(
                        f"cpu_limit={cpu_lim!r} is not a valid Kubernetes CPU quantity"
                    )
                )
            );
        }
        if mem_req is not None and mem_req_b is None {
            out.append(
                Diagnostic(
                    severity="error",
                    service=svc_name,
                    message=(
                        f"memory_request={mem_req!r} is not a valid Kubernetes memory "
                        "quantity (e.g. '128Mi', '1Gi')"
                    )
                )
            );
        }
        if mem_lim is not None and mem_lim_b is None {
            out.append(
                Diagnostic(
                    severity="error",
                    service=svc_name,
                    message=(
                        f"memory_limit={mem_lim!r} is not a valid Kubernetes memory "
                        "quantity"
                    )
                )
            );
        }
        if cpu_req_m is not None and cpu_lim_m is not None and cpu_req_m > cpu_lim_m {
            out.append(
                Diagnostic(
                    severity="error",
                    service=svc_name,
                    message=f"cpu_request ({cpu_req}) > cpu_limit ({cpu_lim})"
                )
            );
        }
        if mem_req_b is not None and mem_lim_b is not None and mem_req_b > mem_lim_b {
            out.append(
                Diagnostic(
                    severity="error",
                    service=svc_name,
                    message=f"memory_request ({mem_req}) > memory_limit ({mem_lim})"
                )
            );
        }
        if cpu_lim is None and mem_lim is None {
            out.append(
                Diagnostic(
                    severity="warn",
                    service=svc_name,
                    message=(
                        "no cpu_limit or memory_limit set; pod runs as BestEffort "
                        "QoS and is first to be OOM-killed under node pressure"
                    )
                )
            );
        }
    }

    def _check_image(svc_name: str, deployment: Any, out: list[Diagnostic]) {
        for c in lget(pod_spec(deployment), "containers") {
            if isinstance(c, dict) and c.get("image") {
                return;
            }
        }
        out.append(
            Diagnostic(
                severity="error",
                service=svc_name,
                message=(
                    "no base image resolved for this service; apply will fail. "
                    "Check [scale.kubernetes].python_image"
                )
            )
        );
    }
}


def has_errors(diagnostics: list[Diagnostic]) -> bool {
    return bool(any(d.severity == "error" for d in diagnostics));
}
