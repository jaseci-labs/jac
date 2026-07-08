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

import tomllib;
import from pathlib { Path }

glob CHANNEL_STABLE: str = "stable",
     CHANNEL_DEV: str = "dev";


obj DevDeploy {
    has channel: str = CHANNEL_STABLE;
}


def resolve_dev_deploy(project_dir: str) -> DevDeploy {
    import from jaclang.jac0core.modresolver { find_project_root }
    found = find_project_root(Path(project_dir));
    if found is None {
        return DevDeploy();
    }
    (_, toml) = found;
    raw = toml.read_bytes();
    if b"dev" not in raw {
        return DevDeploy();
    }
    data = tomllib.loads(raw.decode("utf-8"));
    section = data.get("dev");
    if not isinstance(section, dict) {
        return DevDeploy();
    }
    return DevDeploy(channel=CHANNEL_DEV);
}
