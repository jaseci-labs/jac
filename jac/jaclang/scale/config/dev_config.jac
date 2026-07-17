"""Resolve the pod runtime channel for a deploy.

The binary shipped to pods is ALWAYS a prebuilt jac binary - never built from
source, on the host or in-pod. The channel decides which prebuilt binary:

    (no [dev])                 -> STABLE : latest published release binary, run as-is
    [dev]                      -> DEV    : rolling `dev` prerelease binary (main),
                                           run as-is (it IS main HEAD)
    [experimental] pr = <N>    -> EXPERIMENTAL : run the PR's build from the per-PR
                                           image jaseci/jaclang:experimental-<N>
    JAC_SCALE_BINARY_PATH set  -> LOCAL  : ship the jac binary at that local path
                                           instead of downloading a release

Priority is LOCAL > EXPERIMENTAL > DEV > STABLE.
"""

import os;
import from pathlib { Path }

glob BINARY_PATH_ENV: str = "JAC_SCALE_BINARY_PATH";


enum Channel {
    STABLE = "stable",
    DEV = "dev",
    LOCAL = "local",
    EXPERIMENTAL = "experimental"
}


def resolve_dev_channel(project_dir: str) -> Channel {
    if os.environ.get(BINARY_PATH_ENV, "") {
        return Channel.LOCAL;
    }
    import from jaclang.project.config { get_config_for_path }
    config = get_config_for_path(Path(project_dir));
    if config is None {
        return Channel.STABLE;
    }
    if config.get_section("experimental") is not None {
        return Channel.EXPERIMENTAL;
    }
    if config.get_section("dev") is None {
        return Channel.STABLE;
    }
    return Channel.DEV;
}


def resolve_experimental_pr(project_dir: str) -> str {
    # The [experimental] pr as a bare string; "" when unset (callers fall back).
    import from jaclang.project.config { get_config_for_path }
    config = get_config_for_path(Path(project_dir));
    if config is None {
        return "";
    }
    section = config.get_section("experimental");
    if section is None {
        return "";
    }
    return str(section.get("pr", "")).strip();
}
