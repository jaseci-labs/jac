"""`jac start --scale --dry-run` implementation.

Generates the manifest bundle that WOULD be applied + the image plan
that WOULD be built, and prints both to stdout. Touches nothing:
no cluster contact, no image build, no DB provisioning.

Output format:
  === jac scale plan: dry-run ===
  Cluster type detected: <type>
  Namespace: <ns>
  Services: <comma-separated list>

  --- Resources (<N> manifests) ---
  Deployments: ...
  Services:    ...
  HPAs:        ...
  PDBs:        ...
  Ingress:     <yes/no>

  --- YAML ---
  <multi-doc YAML stream>
"""

import yaml;
import from typing { Any }
import from jaclang.cli.console { console }
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.microservices.images.cluster_detect { detect_cluster_type }


"""Names of entries in a bundle sub-section (deployments / services / etc.).
Returns [] if the section is missing or not a dict."""
def _section_keys(bundle: Any, key: str) -> list {
    section = bundle.get(key, {});
    if not isinstance(section, dict) {
        return [];
    }
    return list(section.keys());
}


"""Manifest dicts in a bundle sub-section. Returns [] on missing/non-dict."""
def _section_values(bundle: Any, key: str) -> list {
    section = bundle.get(key, {});
    if not isinstance(section, dict) {
        return [];
    }
    return list(section.values());
}


"""Print the manifest bundle + image plan that `jac start --scale`
would produce. `target` must be a configured KubernetesMicroserviceTarget
(or any class with `generate_manifests(app_config) -> dict` and a
`k8s_config` attribute exposing `namespace`). Returns the bundle dict
for tests / programmatic callers."""
def print_plan(target: Any, app_config: AppConfig) -> Any {
    bundle: Any = target.generate_manifests(app_config);
    namespace = target.k8s_config.namespace;
    cluster_type = detect_cluster_type();

    deployments = _section_keys(bundle, "deployments");
    services = _section_keys(bundle, "services");
    hpas = _section_keys(bundle, "hpas");
    pdbs = _section_keys(bundle, "pdbs");
    pvcs = _section_keys(bundle, "pvcs");
    has_ingress = bundle.get("ingress") is not None;
    has_user_secret = bundle.get("user_secret") is not None;

    # microservices = services minus gateway (named via the __gateway__ sentinel)
    svc_names = [s for s in services if s != "__gateway__"];

    manifests: list = [];
    for key in ["deployments", "services", "hpas", "pdbs", "pvcs"] {
        for m in _section_values(bundle, key) {
            manifests.append(m);
        }
    }
    if has_ingress {
        manifests.append(bundle["ingress"]);
    }
    if has_user_secret {
        manifests.append(bundle["user_secret"]);
    }

    console.print();
    console.print("[bold cyan]=== jac scale plan: dry-run ===[/bold cyan]");
    console.print(f"[bold]Cluster type detected:[/bold] {cluster_type}");
    console.print(f"[bold]Namespace:[/bold] {namespace}");
    if svc_names {
        console.print(f"[bold]Services:[/bold] {', '.join(svc_names)}");
    } else {
        console.print("[bold]Services:[/bold] (none declared)");
    }
    console.print();
    console.print(f"[bold]--- Resources ({len(manifests)} manifests, NOT applied) ---[/bold]");
    console.print(f"  Deployments: {', '.join(deployments) or '(none)'}");
    console.print(f"  Services:    {', '.join(services) or '(none)'}");
    console.print(f"  HPAs:        {', '.join(hpas) or '(none)'}");
    console.print(f"  PDBs:        {', '.join(pdbs) or '(none)'}");
    if pvcs {
        console.print(f"  PVCs:        {', '.join(pvcs)}");
    }
    console.print(f"  Ingress:     {'yes' if has_ingress else 'no'}");
    if has_user_secret {
        console.print(f"  User secret: yes");
    }
    console.print();
    console.print("[bold]--- YAML (would be applied) ---[/bold]");
    console.print(yaml.safe_dump_all(manifests, default_flow_style=False, sort_keys=False));
    return bundle;
}
