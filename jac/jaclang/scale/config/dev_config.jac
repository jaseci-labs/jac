"""Resolve the pod runtime channel from the project's `[dev]` jac.toml stanza.

The binary shipped to pods is ALWAYS a prebuilt download - never built from
source, on the host or in-pod. The `[dev]` table only decides which binary and
whether to overlay jaclang source on top of it (via the editable dev loop,
`jaclang_source`):

    (no [dev])                 -> STABLE : latest published release binary, run as-is
    [dev]                      -> DEV    : rolling `dev` prerelease binary (main) +
                                           overlay jaclang source
    [dev] repo=.. branch=..    -> DEV    : ...source overlaid from that repo/branch
    [dev] jaclang_source=".."  -> DEV    : ...source overlaid from the local checkout
                                           if present, else fetched `main`

For DEV the source origin resolves at deploy time as: repo/branch if given, else
the local `jaclang_source` dir if it exists, else a fresh `main` from
jaseci-labs. This reads the raw `[dev]` table directly rather than extending
core's DevConfig, keeping the deploy-specific `repo`/`branch` keys out of core.
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
        # DEV overlays jaclang source on the downloaded binary; STABLE runs the
        # binary's own bundled jaclang as-is.
        return self.channel == CHANNEL_DEV;
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
    # Cheap guard: skip the tomllib parse unless the word `dev` appears at all.
    # Deliberately loose (a substring, not `[dev]`) so no table spelling - bare
    # `[dev]`, whitespace `[ dev ]`, or dotted `[dev.x]` - is ever missed; the
    # real decision is `data.get("dev")` below, so false positives only cost a
    # parse, never a wrong channel.
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
    # A `[dev]` table with a repo but no branch defaults to main.
    if repo and not branch {
        branch = "main";
    }
    return DevDeploy(
        channel=CHANNEL_DEV, repo=repo, branch=branch, jaclang_source=jaclang_source
    );
}
