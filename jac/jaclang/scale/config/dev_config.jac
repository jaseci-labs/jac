"""Resolve the pod runtime channel from the project's `[dev]` jac.toml stanza.

The deploy path needs to know *which* `jac` runtime to put in the pods. That is
driven entirely by the top-level `[dev]` table in the nearest `jac.toml` (the
same stanza Jason's editable dev loop reads for `jaclang_source`), so a normal
app with no `[dev]` ships the published stable release, while a dev app opts into
a rolling/main or build-from-source runtime by declaring `[dev]`:

    (no [dev])                 -> STABLE  : download the latest published release binary
    [dev]                      -> DEV     : download the rolling `dev` prerelease binary (main)
    [dev] repo=.. branch=..    -> BRANCH  : clone + build that branch in-pod (escape hatch)
    [dev] jaclang_source=".."  -> LOCAL   : host-build from the local checkout + ship the binary

This reads the raw `[dev]` table directly rather than extending core's DevConfig,
keeping the deploy-specific `repo`/`branch` keys out of jaclang core.
"""

import tomllib;
import from pathlib { Path }

glob CHANNEL_STABLE: str = "stable",
     CHANNEL_DEV: str = "dev",
     CHANNEL_BRANCH: str = "branch",
     CHANNEL_LOCAL: str = "local";


obj DevDeploy {
    has channel: str = CHANNEL_STABLE,
        repo: str = "",
        branch: str = "",
        jaclang_source: str = "";

    def builds_in_pod -> bool {
        # Only the BRANCH escape hatch clones + compiles jaclang inside the pod.
        return self.channel == CHANNEL_BRANCH;
    }

    def ships_binary -> bool {
        # stable/dev download a prebuilt binary; local host-builds one. All three
        # ship a self-contained `jac` over the PVC and skip the in-pod build.
        return self.channel in (CHANNEL_STABLE, CHANNEL_DEV, CHANNEL_LOCAL);
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

    # Precedence: an explicit local checkout wins (you are editing jaclang),
    # then an explicit branch, else the bare `[dev]` rolling prerelease.
    if jaclang_source {
        channel = CHANNEL_LOCAL;
    } elif repo {
        channel = CHANNEL_BRANCH;
        if not branch {
            branch = "main";
        }
    } else {
        channel = CHANNEL_DEV;
    }
    return DevDeploy(
        channel=channel, repo=repo, branch=branch, jaclang_source=jaclang_source
    );
}
