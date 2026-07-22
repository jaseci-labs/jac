import os;
import sys;
import from importlib.metadata { version as pkg_version }
import from pathlib { Path }

impl start_cli -> None {
    import from jaclang.cli.console { console }
    import from jaclang.cli.manifest_route { handle_manifest_route }

    raw_argv = sys.argv[1:];

    dev_source = os.environ.get('JAC_DEV_SOURCE');
    if dev_source {
        notice = (
            f"🛠  jac dev mode — using compiler source at {dev_source}"
                if console.use_emoji
                else f"[dev] jac dev mode - using compiler source at {dev_source}"
        );
        console.print(notice, style='info', file=sys.stderr);
    }

    handle_manifest_route(raw_argv);
}

impl jac_version -> str {
    import from jaclang.project.config { JacConfig }

    dev_source = os.environ.get('JAC_DEV_SOURCE');
    if dev_source {
        toml_path = Path(dev_source) / 'jac.toml';
        if toml_path.exists() {
            try {
                return JacConfig.load(toml_path).project.version;
            } except Exception { }
        }
    }
    return pkg_version('jaclang');
}
