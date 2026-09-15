import os;
import sys;

impl start_cli -> None {
    import from jaclang.cli.console { console }
    import from jaclang.cli.manifest_route { handle_manifest_route }

    raw_argv = sys.argv[1:];

    handle_manifest_route(raw_argv);
}

impl jac_version -> str {
    import from jaclang.cli.manifest_route { resolve_cli_version }

    return resolve_cli_version();
}
