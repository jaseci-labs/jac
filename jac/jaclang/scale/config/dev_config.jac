"""Resolve the pod runtime channel for a deploy.

The binary shipped to pods is ALWAYS a prebuilt jac binary - never built from
source, on the host or in-pod. The channel decides which prebuilt binary:

    (no [dev])                 -> STABLE : latest published release binary, run as-is
    [dev]                      -> DEV    : rolling `dev` prerelease binary (main),
                                           run as-is (it IS main HEAD)
    JAC_SCALE_BINARY_PATH set  -> LOCAL  : ship the jac binary at that local path
                                           instead of downloading a release

Priority is LOCAL > DEV > STABLE: JAC_SCALE_BINARY_PATH (a local build or
air-gapped mirror) wins over the `[dev]` stanza, which wins over the default.
"""

import os;
import from pathlib { Path }

glob BINARY_PATH_ENV: str = "JAC_SCALE_BINARY_PATH";


enum Channel { STABLE = "stable", DEV = "dev", LOCAL = "local" }


def resolve_dev_channel(project_dir: str) -> Channel {
    if os.environ.get(BINARY_PATH_ENV, "") {
        return Channel.LOCAL;
    }
    import from jaclang.project.config { get_config_for_path }
    config = get_config_for_path(Path(project_dir));
    if config is None or config.get_section("dev") is None {
        return Channel.STABLE;
    }
    return Channel.DEV;
}
