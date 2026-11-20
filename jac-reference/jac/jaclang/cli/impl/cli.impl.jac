import os;
import sys;

impl start_cli -> None {
    raw_argv = sys.argv[1:];

    dev_source = str(handoff().get('compiler_source') or '');
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
    return resolve_cli_version();
}
