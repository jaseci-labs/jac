"""Resolve the pod runtime channel from the project's `[dev]` jac.toml stanza.

The binary shipped to pods is ALWAYS a prebuilt download - never built from
source, on the host or in-pod. The `[dev]` table only decides which prebuilt
binary channel to ship:

    (no [dev])                 -> STABLE : latest published release binary, run as-is
    [dev]                      -> DEV    : rolling `dev` prerelease binary (main),
                                           run as-is (it IS main HEAD)

Both channels ship the binary bare - there is no source overlay. A bare `[dev]`
is already built from main HEAD, so cloning main to overlay the same code would
be redundant, and stable runs the published release as-is.
"""

import from pathlib { Path }


enum Channel { STABLE = "stable", DEV = "dev" }


def resolve_dev_channel(project_dir: str) -> Channel {
    import from jaclang.project.config { get_config_for_path }
    config = get_config_for_path(Path(project_dir));
    if config is None or config.get_section("dev") is None {
        return Channel.STABLE;
    }
    return Channel.DEV;
}
