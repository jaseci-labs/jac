"""Interactive CLI for configuring microservice mode.

Commands:
  jac setup microservice          - interactive setup
  jac setup microservice --list   - show current config
  jac setup microservice --add <file>    - add a service
  jac setup microservice --remove <name> - remove a service

Writes a v2 [plugins.scale.microservices.routes] table that maps module
names to gateway prefixes. Services are discovered automatically via
`sv import`; the routes table only controls public URL routing.
"""

import os;
import tomllib;
import from pathlib { Path }

"""Scan the project for .jac files, excluding build artifacts."""
def scan_jac_files(project_root: str = ".") -> list[str] {
    base_dir = Path(project_root);
    exclude_dirs: set[str] = {".jac","__pycache__","node_modules",".git","dist","build","__jac_gen__"};
    jac_files: list[str] = [];

    for f in base_dir.rglob("*.jac") {
        parts = f.relative_to(base_dir).parts;
        should_skip = False;
        for part in parts {
            if part in exclude_dirs {
                should_skip = True;
            }
        }
        if not should_skip {
            jac_files.append(str(f.relative_to(base_dir)));
        }
    }

    jac_files.sort();
    return jac_files;
}

"""Derive the module name from a file path - matches sv_import resolution.

Returns the file stem: orders_app.jac -> orders_app, services/cart.jac -> cart.
"""
def derive_module_name(file_path: str) -> str {
    return Path(file_path).stem;
}

"""Derive a gateway route prefix from a module name.

Strips the conventional _app suffix so orders_app -> /api/orders.
"""
def derive_prefix(module_name: str) -> str {
    name = module_name;
    if name.endswith("_app") {
        name = name[:-4];
    }
    return f"/api/{name}";
}

"""Run the interactive setup flow - scan project, prompt user, write TOML."""
def run_setup(project_root: str = ".") -> None {
    toml_path = Path(project_root) / "jac.toml";

    jac_files = scan_jac_files(project_root);
    if not jac_files {
        print("No .jac files found in project.");
        return;
    }

    print("\nFound .jac files:");
    for (i, f) in enumerate(jac_files) {
        print(f"  {i + 1}. {f}");
    }

    selection = input(
        "\nSelect files to run as microservices (comma-separated numbers): "
    ).strip();
    if not selection {
        print("No services selected. Exiting.");
        return;
    }

    selected_indices: list[int] = [];
    for x in selection.split(",") {
        stripped = x.strip();
        if stripped.isdigit() {
            selected_indices.append(int(stripped) - 1);
        }
    }

    selected_files: list[str] = [];
    for i in selected_indices {
        if 0 <= i < len(jac_files) {
            selected_files.append(jac_files[i]);
        }
    }

    if not selected_files {
        print("No valid files selected. Exiting.");
        return;
    }

    client_entry = input("\nClient UI entry point (leave blank for none): ").strip();

    # Preserve existing jac.toml content, strip old microservices section
    lines: list[str] = [];
    if toml_path.exists() {
        existing = toml_path.read_text();
        skip_section = False;
        for line in existing.split("\n") {
            if line.strip().startswith("[plugins.scale.microservices") {
                skip_section = True;
            } elif line.strip().startswith("[") and skip_section {
                if not line.strip().startswith("[plugins.scale.microservices") {
                    skip_section = False;
                    lines.append(line);
                }
            } elif not skip_section {
                lines.append(line);
            }
        }
        while lines and not lines[-1].strip() {
            lines.pop();
        }
        lines.append("");
    }

    # Write microservices config
    lines.append("[plugins.scale.microservices]");
    lines.append("enabled = true");
    lines.append("gateway_port = 8000");
    lines.append('gateway_host = "0.0.0.0"');
    lines.append("");

    lines.append("[plugins.scale.microservices.routes]");
    for file_path in selected_files {
        module = derive_module_name(file_path);
        prefix = derive_prefix(module);
        lines.append(f'{module} = "{prefix}"');
    }
    lines.append("");

    if client_entry {
        lines.append("[plugins.scale.microservices.client]");
        lines.append(f'entry = "{client_entry}"');
        lines.append('dist_dir = ".jac/client/dist"');
        lines.append('base_route = "/"');
        lines.append("");
    }

    # Reference blocks for production-hardening knobs. Left commented so
    # the default stance is safe: no CORS, no rate limiting. Uncomment
    # and tune per deployment.
    lines.extend(
        [
            "# Graceful drain window on SIGTERM (seconds). Matches K8s",
            "# terminationGracePeriodSeconds. Default: 10.",
            "# [plugins.scale.microservices]",
            "# drain_timeout_seconds = 10",
            "",
            "# Per-service RPC timeout override (seconds). Raise for LLM /",
            "# long-running services. `rpc_timeout` controls inter-service",
            "# `sv import` calls; `http_forward_timeout` controls the gateway's",
            "# proxy to the service.",
            "# [plugins.scale.microservices.services.llm_app]",
            "# rpc_timeout = 120.0",
            "# http_forward_timeout = 300.0",
            "",
            "# Global gateway-to-service forward timeout (seconds). Applies to",
            "# both the built-in passthrough fan-out and the path-routed proxy.",
            "# Per-service overrides above take precedence. Default: 30.",
            "# [plugins.scale.microservices]",
            "# http_forward_timeout = 30.0",
            "",
            "# CORS middleware. Open by default (any origin; allow_origins",
            "# defaults to [\"*\"]). Uncomment to restrict, or set",
            "# allow_origins = [] to disable entirely. Note: allow_credentials",
            "# = true requires a concrete allow_origins list per CORS spec.",
            "# [plugins.scale.microservices.cors]",
            '# allow_origins = ["https://app.example.com"]',
            '# allow_methods = ["GET", "POST", "OPTIONS"]',
            '# allow_headers = ["Authorization", "Content-Type"]',
            "# allow_credentials = true",
            "# max_age = 600",
            "",
            "# Rate limiting (token bucket, per-IP + optional per-user).",
            "# [plugins.scale.microservices.rate_limit]",
            "# enabled = true",
            "# per_ip_rpm = 600",
            "# per_user_rpm = 120",
            "# burst_multiplier = 2.0",
            '# exempt_paths = ["/health", "/healthz", "/metrics"]',
            ""
        ]
    );

    toml_path.write_text("\n".join(lines));

    print(f"\nAdded microservice config to jac.toml:");
    for file_path in selected_files {
        module = derive_module_name(file_path);
        print(f"  - {module:18s} -> {derive_prefix(module):20s} ({file_path})");
    }
    if client_entry {
        print(f"  - {'client':18s} -> {client_entry}");
    }
    print(f"\nRun `jac start main.jac` to launch locally.");
}

"""Add a single service to existing config."""
def add_service(project_root: str, file_path: str) -> None {
    toml_path = Path(project_root) / "jac.toml";
    if not toml_path.exists() {
        print("No jac.toml found. Run `jac setup microservice` first.");
        return;
    }

    module = derive_module_name(file_path);
    prefix = derive_prefix(module);

    with open(str(toml_path), "rb") as f {
        doc = tomllib.load(f);
    }
    ms = doc.get("plugins", {}).get("scale", {}).get("microservices", {});
    routes = ms.get("routes", {});
    if module in routes {
        print(f"Route '{module}' already exists. Remove it first with --remove.");
        return;
    }

    content = toml_path.read_text();
    # If [routes] table exists, append to it; otherwise create it.
    header = "[plugins.scale.microservices.routes]";
    if header in content {
        # Insert after the header line
        new_lines: list[str] = [];
        inserted = False;
        for line in content.split("\n") {
            new_lines.append(line);
            if (not inserted) and line.strip() == header {
                new_lines.append(f'{module} = "{prefix}"');
                inserted = True;
            }
        }
        content = "\n".join(new_lines);
    } else {
        content += f'\n{header}\n{module} = "{prefix}"\n';
    }
    toml_path.write_text(content);

    print(f"Added route: {module} -> {prefix} ({file_path})");
}

"""Remove a route from config by module name."""
def remove_service(project_root: str, module_name: str) -> None {
    toml_path = Path(project_root) / "jac.toml";
    if not toml_path.exists() {
        print("No jac.toml found.");
        return;
    }

    content = toml_path.read_text();
    lines = content.split("\n");
    in_routes = False;
    found = False;
    new_lines: list[str] = [];
    for line in lines {
        stripped = line.strip();
        if stripped == "[plugins.scale.microservices.routes]" {
            in_routes = True;
            new_lines.append(line);
            continue;
        }
        if in_routes and stripped.startswith("[") {
            in_routes = False;
        }
        if in_routes and stripped.startswith(f"{module_name} =") {
            found = True;
            continue;
        }
        new_lines.append(line);
    }

    if not found {
        print(f"Route '{module_name}' not found in config.");
        return;
    }

    toml_path.write_text("\n".join(new_lines));
    print(f"Removed route: {module_name}");
}

"""List currently configured routes."""
def list_services(project_root: str) -> None {
    toml_path = Path(project_root) / "jac.toml";
    if not toml_path.exists() {
        print("No jac.toml found.");
        return;
    }

    with open(str(toml_path), "rb") as f {
        doc = tomllib.load(f);
    }

    ms = doc.get("plugins", {}).get("scale", {}).get("microservices", {});
    enabled = ms.get("enabled", False);
    routes = ms.get("routes", {});
    client = ms.get("client", {});

    print(f"Microservice mode: {'ENABLED' if enabled else 'DISABLED'}");
    print(
        f"Gateway: {ms.get('gateway_host', '0.0.0.0')}:{ms.get('gateway_port', 8000)}"
    );

    if routes {
        print(f"\nRoutes ({len(routes)}):");
        for (module, prefix) in routes.items() {
            print(f"  {module:18s} -> {prefix}");
        }
    } else {
        print("\nNo routes configured.");
    }

    if client.get("entry") {
        print(f"\nClient: {client['entry']}");
    }
}
