"""Resolve the pod runtime channel from the project's `[dev]` jac.toml stanza.

The binary shipped to pods is ALWAYS a prebuilt download - never built from
source, on the host or in-pod. The `[dev]` table only decides which binary and
whether to overlay jaclang source on top of it (via the editable dev loop,
`jaclang_source`):

    (no [dev])                 -> STABLE : latest published release binary, run as-is
    [dev]                      -> DEV    : rolling `dev` prerelease binary (main),
                                           run as-is (no overlay - it IS main HEAD)
    [dev] repo=.. branch=..    -> DEV    : dev binary + overlay source from repo/branch
    [dev] jaclang_source=".."  -> DEV    : dev binary + overlay the local checkout
                                           if present, else fetched `main`

A bare `[dev]` ships the dev binary bare because it is already built from main
HEAD - cloning main to overlay the same code would be redundant. When a custom
source IS requested, the origin resolves at deploy time as: repo/branch if given,
else the local `jaclang_source` dir if it exists, else a fresh `main`. This reads
the raw `[dev]` table directly rather than extending core's DevConfig, keeping the
deploy-specific `repo`/`branch` keys out of core.
"""

import tomllib;
import from pathlib { Path }

glob CHANNEL_STABLE: str = "stable",
     CHANNEL_DEV: str = "dev";


obj DevDeploy {
    has channel: str = CHANNEL_STABLE,
        repo: str = "",
        branch: str = "",
        jaclang_source: str = "";

    def overlays_source -> bool {
        return self.channel == CHANNEL_DEV
        and (self.repo != "" or self.jaclang_source != "");
    }
}


def _nearest_jac_toml(start: Path) -> (Path | None) {
    cur: Path = start.resolve();
    while True {
        toml = cur / "jac.toml";
        if toml.is_file() {
            return toml;
        }
        if cur.parent == cur {
            return None;
        }
        cur = cur.parent;
    }
}


def resolve_dev_deploy(project_dir: str) -> DevDeploy {
    toml = _nearest_jac_toml(Path(project_dir));
    if toml is None {
        return DevDeploy();
    }
    raw = toml.read_bytes();
    if b"dev" not in raw {
        return DevDeploy();
    }
    data = tomllib.loads(raw.decode("utf-8"));
    section = data.get("dev");
    if not isinstance(section, dict) {
        return DevDeploy();
    }

    repo = str(section.get("repo", "") or "");
    branch = str(section.get("branch", "") or "");
    jaclang_source = str(section.get("jaclang_source", "") or "");
    if repo and not branch {
        branch = "main";
    }
    return DevDeploy(
        channel=CHANNEL_DEV, repo=repo, branch=branch, jaclang_source=jaclang_source
    );
}
