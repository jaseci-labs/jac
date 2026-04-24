"""Dev-server helpers for MobileTarget.

Handles local IP detection, backend server startup, Vite dev server
startup, and dev-config.json generation.
"""
import from pathlib { Path }
import from typing { Any }
import from jaclang.cli.console { console }
import subprocess;
import json;

"""Return http://127.0.0.1:{port}."""
def _make_localhost_url(port: int) -> str {
    return f"http://127.0.0.1:{port}";
}

"""Read api.base_url from jac.toml via JacClientConfig."""
def _get_toml_api_base_url(project_dir: Path) -> str {
    import from jac_client.plugin.src.config_loader { JacClientConfig }
    config_loader = JacClientConfig(project_dir);
    return config_loader.get_api_config().get('base_url', '');
}

"""Get local network IP using only local-only OS calls (no external network)."""
def _get_local_ip -> str {
    import socket;

    try {
        # Method 1: resolve all addresses for the local hostname and pick the
        # first routable (non-loopback) IPv4 address.  Works fully offline.
        hostname = socket.gethostname();
        for info in socket.getaddrinfo(hostname, None, socket.AF_INET) {
            ip = info[4][0];
            if not ip.startswith('127.') {
                return ip;
            }
        }

        # Method 2: gethostbyname_ex returns (hostname, aliaslist, ipaddrlist).
        # Also works offline on machines with multiple interfaces.
        (_h, _aliases, addr_list) = socket.gethostbyname_ex(hostname);
        for ip in addr_list {
            if not ip.startswith('127.') {
                return ip;
            }
        }

        # Fallback: only loopback found (single-interface machine or unusual
        # network config); mobile device can't reach this but it's the best
        # we can report.
        return '127.0.0.1';
    } except Exception {
        return '127.0.0.1';
    }
}

"""Write dev-config.json with local IP and production API URL for the app."""
def _write_dev_config(mobile_dir: Path, project_dir: Path, local_ip: str) {
    import from jac_client.plugin.src.mobile_config { MobileConfig }
    try {
        mobile_config = MobileConfig(project_dir=project_dir);
        config_data = mobile_config.load();
        production_api_url = config_data.get('features', {}).get('api_url', '');
    } except Exception {
        production_api_url = '';
    }

    dev_config = {
        'localIP': local_ip,
        'productionApiUrl': production_api_url
    };

    dev_config_path = mobile_dir / "dev-config.json";
    with open(dev_config_path, "w") as f {
        json.dump(dev_config, f, indent=2);
    }
    console.print(f"  ✔ Dev config written (IP: {local_ip})", style="success");
}

"""Start Vite dev server for HMR support."""
def _start_vite_dev_server(
    entry_file: Path, project_dir: Path, api_port: int
) -> subprocess.Popen {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }

    try {
        bundler = ViteBundler(
            project_dir=project_dir, output_dir=None, minify=False, config_path=None
        );
        dev_config_path = bundler.create_vite_config(
            entry_file,
            api_base_url_override=f"http://localhost:{api_port}",
            is_dev=True,
            api_port=api_port
        );
        process = bundler.start_dev_server(port=5173, suppress_initial_output=True);
        return process;
    } except Exception as e {
        raise RuntimeError(f"Failed to start Vite dev server: {e}");
    }
}

"""Start jac serve backend in the background."""
def _start_backend_server(
    entry_file: Path, project_dir: Path, port: int
) -> subprocess.Popen {
    try {
        process = subprocess.Popen(
            ["jac", "serve", str(entry_file), "--port", str(port)],
            cwd=str(project_dir),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        );
        return process;
    } except Exception as e {
        raise RuntimeError(f"Failed to start backend server: {e}");
    }
}
