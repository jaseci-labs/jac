"""Tests for scripts/release_site_branch.sh, which ships jaclang.org per release.

jachammer redeploys the site on every push to release/jaclang-org, so this
script deciding to move that branch IS the decision to redeploy. It must move
the branch only for the release that is latest, to the commit its tag names,
and must never move it for a backport, which would roll the site back.

`gh` is stubbed on PATH, so these exercise the real command lines the script
runs and record what it asked GitHub to do.
"""

import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }

glob REPO_ROOT: Path = Path(__file__).resolve().parents[3],
     SCRIPT: str = str(REPO_ROOT / "scripts" / "release_site_branch.sh"),
     VERSION: str = "0.37.1",
     VTAG: str = "v0.37.1",
     SHA: str = "0123456789abcdef0123456789abcdef01234567";

glob FAKE_GH: str = '#!/usr/bin/env bash\n'
         + 'printf \'%s\\n\' "$*" >> "$GH_LOG"\n'
         + '[ "$1" = "api" ] || { echo "fake gh: unexpected $1" >&2; exit 1; }\n'
         + 'case "$*" in\n'
         + '    *releases/latest*)\n'
         + '        [ -s "$GH_LATEST" ] || { echo "HTTP 502" >&2; exit 1; }\n'
         + '        cat "$GH_LATEST"\n'
         + '        ;;\n'
         + '    *commits/*)\n'
         + '        cat "$GH_COMMIT"\n'
         + '        ;;\n'
         + '    *git/ref/heads/*)\n'
         + '        [ "$GH_BRANCH_EXISTS" = "1" ] || { echo "HTTP 404" >&2; exit 1; }\n'
         + '        echo "{}"\n'
         + '        ;;\n'
         + '    *git/refs*)\n'
         + '        echo "{}"\n'
         + '        ;;\n'
         + '    *)\n'
         + '        echo "fake gh: unexpected api call $*" >&2\n'
         + '        exit 1\n'
         + '        ;;\n'
         + 'esac\n';

"""A stub `gh` on PATH plus the files that drive what it answers."""
def scaffold(latest: str, commit: str = SHA) -> dict[(str, str)] {
    base = tempfile.mkdtemp(prefix="jac-release-site-branch-");
    bindir = os.path.join(base, "bin");
    os.makedirs(bindir);
    gh = Path(bindir) / "gh";
    gh.write_text(FAKE_GH);
    os.chmod(str(gh), 0o755);
    fx = {
        "base": base,
        "bin": bindir,
        "log": os.path.join(base, "gh.log"),
        "latest": os.path.join(base, "latest.txt"),
        "commit": os.path.join(base, "commit.txt")
    };
    Path(fx["latest"]).write_text(f"{latest}\n" if latest else "");
    Path(fx["commit"]).write_text(f"{commit}\n");
    Path(fx["log"]).write_text("");
    return fx;
}

def run_script(
    fx: dict[(str, str)], branch_exists: bool = True
) -> subprocess.CompletedProcess[str] {
    env: dict[str, str] = dict(os.environ);
    env["PATH"] = fx["bin"] + os.pathsep + env["PATH"];
    env["GH_LOG"] = fx["log"];
    env["GH_LATEST"] = fx["latest"];
    env["GH_COMMIT"] = fx["commit"];
    env["GH_BRANCH_EXISTS"] = "1" if branch_exists else "";
    env["GH_REPO"] = "jaseci-labs/jac";
    return subprocess.run(
        ["bash", SCRIPT, VERSION],
        cwd=fx["base"],
        env=env,
        capture_output=True,
        text=True
    );
}

"""The call that wrote the branch (PATCH or POST on git/refs), or ""."""
def write_call(fx: dict[(str, str)]) -> str {
    for line in Path(fx["log"]).read_text().splitlines() {
        if "-X PATCH" in line or "-X POST" in line {
            return line;
        }
    }
    return "";
}

test "the latest release moves the existing branch to its tag's commit" {
    fx = scaffold(VTAG);
    try {
        res = run_script(fx);
        out = res.stdout + res.stderr;
        assert res.returncode == 0 , out;
        call = write_call(fx);
        assert "-X PATCH" in call , "an existing branch must be updated: " + call;
        assert "heads/release/jaclang-org" in call , call;
        assert f"sha={SHA}" in call , "the branch must land on the tag's commit: "
            + call;
        assert "force=true" in call , "moving between releases is not a fast-forward: "
            + call;
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "the first run creates the branch" {
    fx = scaffold(VTAG);
    try {
        res = run_script(fx, branch_exists=False);
        out = res.stdout + res.stderr;
        assert res.returncode == 0 , out;
        call = write_call(fx);
        assert "-X POST" in call , "a missing branch must be created: " + call;
        assert "ref=refs/heads/release/jaclang-org" in call , call;
        assert f"sha={SHA}" in call , call;
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "a backport that did not take latest leaves the branch alone" {
    fx = scaffold("v0.38.0");
    try {
        res = run_script(fx);
        out = res.stdout + res.stderr;
        assert res.returncode == 0 , "a backport is not an error: " + out;
        assert write_call(fx) == "" , "a backport must not roll the site back";
        assert "not the latest release" in out , out;
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "an unreadable latest release fails instead of silently skipping" {
    fx = scaffold("");
    try {
        res = run_script(fx);
        out = res.stdout + res.stderr;
        assert res.returncode != 0 , "a lookup failure must be visible: " + out;
        assert write_call(fx) == "" , out;
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "a tag that does not resolve to a SHA fails without moving the branch" {
    fx = scaffold(VTAG, commit="not-a-sha");
    try {
        res = run_script(fx);
        out = res.stdout + res.stderr;
        assert res.returncode != 0 , out;
        assert write_call(fx) == "" , out;
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}
