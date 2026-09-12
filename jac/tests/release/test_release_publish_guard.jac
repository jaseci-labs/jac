"""Tests for scripts/release_publish_guard.sh, the release pipeline's publish gate.

The gate decides whether a finished draft release becomes the one install.sh
hands users. It is handed the platform list build-binaries.yml's `plan` job
emits, which is the single source of truth for what a release must contain, and
it has to tell three cases apart: every required binary attached is a publish, a
required binary missing is a refusal that leaves the draft alone, and a platform
that is not on the required list is simply absent from the release rather than a
reason to withhold it.

`gh` is stubbed on PATH, so these exercise the real command lines the guard runs
and record what it asked GitHub to do.
"""

import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }

glob REPO_ROOT: Path = Path(__file__).resolve().parents[3],
     GUARD: str = str(REPO_ROOT / "scripts" / "release_publish_guard.sh"),
     VERSION: str = "0.37.1",
     VTAG: str = "v0.37.1";

glob FAKE_GH: str = '#!/usr/bin/env bash\n'
         + 'printf \'%s\\n\' "$*" >> "$GH_LOG"\n'
         + 'if [ "${GH_VIEW_FAILS:-}" = "1" ]; then\n'
         + '    echo "HTTP 502: simulated release API error" >&2\n'
         + '    exit 1\n'
         + 'fi\n'
         + 'case "$1" in\n'
         + '    release)\n'
         + '        case "$2" in\n'
         + '            view)\n'
         + '                if printf \'%s\' "$*" | grep -q isDraft; then\n'
         + '                    cat "$GH_ISDRAFT"\n'
         + '                else\n'
         + '                    cat "$GH_ASSETS"\n'
         + '                fi\n'
         + '                ;;\n'
         + '            edit)\n'
         + '                echo "edited $3"\n'
         + '                ;;\n'
         + '            *)\n'
         + '                echo "fake gh: unexpected release subcommand $2" >&2\n'
         + '                exit 1\n'
         + '                ;;\n'
         + '        esac\n'
         + '        ;;\n'
         + '    api)\n'
         + '        [ -s "$GH_LATEST" ] || exit 1\n'
         + '        cat "$GH_LATEST"\n'
         + '        ;;\n'
         + '    *)\n'
         + '        echo "fake gh: unexpected command $1" >&2\n'
         + '        exit 1\n'
         + '        ;;\n'
         + 'esac\n';

glob ALL_PLATFORMS: list[str] = [
         "linux-x86_64",
         "linux-aarch64",
         "macos-aarch64",
         "macos-x86_64"
     ];

"""A stub `gh` on PATH plus the files that drive what it answers."""
def scaffold(
    assets: list[str], is_draft: str = "true", latest: str = ""
) -> dict[(str, str)] {
    base = tempfile.mkdtemp(prefix="jac-release-publish-guard-");
    bindir = os.path.join(base, "bin");
    os.makedirs(bindir);
    gh = Path(bindir) / "gh";
    gh.write_text(FAKE_GH);
    os.chmod(str(gh), 0o755);
    fx = {
        "base": base,
        "bin": bindir,
        "log": os.path.join(base, "gh.log"),
        "assets": os.path.join(base, "assets.txt"),
        "isdraft": os.path.join(base, "isdraft.txt"),
        "latest": os.path.join(base, "latest.txt")
    };
    Path(fx["assets"]).write_text("".join([f"{a}\n" for a in assets]));
    Path(fx["isdraft"]).write_text(is_draft + "\n");
    Path(fx["latest"]).write_text(f"{latest}\n" if latest else "");
    Path(fx["log"]).write_text("");
    return fx;
}

"""Asset names a release carries once the named platforms have uploaded."""
def assets_for(platforms: list[str]) -> list[str] {
    out = [];
    for p in platforms {
        out.append(f"jac-{VERSION}-{p}");
        out.append(f"jac-{VERSION}-{p}.sha256");
    }
    out.append(f"jac-{VERSION}-admin-dist.tar.gz");
    return out;
}

def run_guard(
    fx: dict[(str, str)], required: list[str], api_fails: bool = False
) -> subprocess.CompletedProcess[str] {
    env = dict(os.environ);
    env["PATH"] = fx["bin"] + os.pathsep + env["PATH"];
    env["GH_LOG"] = fx["log"];
    env["GH_ASSETS"] = fx["assets"];
    env["GH_ISDRAFT"] = fx["isdraft"];
    env["GH_LATEST"] = fx["latest"];
    env["GH_REPO"] = "jaseci-labs/jac";
    env["GH_VIEW_FAILS"] = "1" if api_fails else "";
    env["RELEASE_ASSET_TIMEOUT"] = "1";
    env["RELEASE_ASSET_POLL"] = "1";
    return subprocess.run(
        ["bash", GUARD, VERSION] + required,
        cwd=fx["base"],
        env=env,
        capture_output=True,
        text=True
    );
}

"""The `gh release edit` line the guard ran, or "" when it published nothing."""
def publish_call(fx: dict[(str, str)]) -> str {
    for line in Path(fx["log"]).read_text().splitlines() {
        if line.startswith("release edit") {
            return line;
        }
    }
    return "";
}

test "every required asset attached: the draft is published as latest" {
    fx = scaffold(assets_for(ALL_PLATFORMS));
    try {
        res = run_guard(fx, ALL_PLATFORMS);
        out = res.stdout + res.stderr;
        assert res.returncode == 0 , "a complete release must publish: " + out;
        call = publish_call(fx);
        assert (VTAG in call) , "the guard must publish the release tag: " + call;
        assert ("--draft=false" in call) , "the draft must be revealed: " + call;
        assert ("--latest=false" not in call) , "a newest release must take the latest pointer: "
            + call;
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "a required asset missing: refuse and leave the draft alone" {
    fx = scaffold(assets_for(["linux-x86_64", "linux-aarch64", "macos-aarch64"]));
    try {
        res = run_guard(fx, ALL_PLATFORMS);
        out = res.stdout + res.stderr;
        assert res.returncode != 0 , "a release missing a required binary must not publish: "
            + out;
        assert (f"jac-{VERSION}-macos-x86_64" in out) , "the refusal must name the missing asset: "
            + out;
        assert publish_call(fx) == "" , "a refusal must not touch the draft's published state";
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "a non-required platform missing: publish the release without it" {
    required = ["linux-x86_64", "linux-aarch64", "macos-aarch64"];
    fx = scaffold(assets_for(required));
    try {
        res = run_guard(fx, required);
        out = res.stdout + res.stderr;
        assert res.returncode == 0 , "a platform left off the required list must not hold the release: "
            + out;
        call = publish_call(fx);
        assert ("--draft=false" in call) , "the release must still be revealed: "
            + call;
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "both compiler variants are required before publishing" {
    required = ["linux-x86_64", "linux-x86_64-jacpython"];
    for missing in required {
        fx = scaffold(
            assets_for(
                [
                    p
                    for p in required
                    if p != missing
                ]
            )
        );
        try {
            res = run_guard(fx, required);
            assert res.returncode != 0;
            assert f"jac-{VERSION}-{missing}" in res.stdout + res.stderr;
            assert publish_call(fx) == "";
        } finally {
            shutil.rmtree(fx["base"], ignore_errors=True);
        }
    }
    fx = scaffold(assets_for(required));
    try {
        res = run_guard(fx, required);
        assert res.returncode == 0 , res.stdout + res.stderr;
        assert "--draft=false" in publish_call(fx);
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "no required platforms given: refuse rather than publish an unchecked release" {
    fx = scaffold(assets_for(ALL_PLATFORMS));
    try {
        res = run_guard(fx, []);
        out = res.stdout + res.stderr;
        assert res.returncode != 0 , "an empty required list must fail loudly: " + out;
        assert publish_call(fx) == "" , "nothing may be published on an unchecked list";
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "a backport release publishes without moving the latest pointer" {
    fx = scaffold(assets_for(ALL_PLATFORMS), latest="v0.38.0");
    try {
        res = run_guard(fx, ALL_PLATFORMS);
        out = res.stdout + res.stderr;
        assert res.returncode == 0 , "a backport must still publish: " + out;
        call = publish_call(fx);
        assert ("--latest=false" in call) , "a newer release must keep the latest pointer: "
            + call;
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "an already-published release is left exactly as it is" {
    fx = scaffold(assets_for(ALL_PLATFORMS), is_draft="false");
    try {
        res = run_guard(fx, ALL_PLATFORMS);
        out = res.stdout + res.stderr;
        assert res.returncode == 0 , "a re-run over a published release must converge: "
            + out;
        assert publish_call(fx) == "" , "a published release's latest pointer must not be re-flipped";
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "an unreadable release API is reported as such, and publishes nothing" {
    fx = scaffold(assets_for(ALL_PLATFORMS));
    try {
        res = run_guard(fx, ALL_PLATFORMS, api_fails=True);
        out = res.stdout + res.stderr;
        assert res.returncode != 0 , "an API the guard cannot read must not pass for a complete release: "
            + out;
        assert ("502" in out) , "the refusal must carry the API's own error rather than blame missing assets: "
            + out;
        assert publish_call(fx) == "" , "nothing may be published while the release cannot be read";
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}
