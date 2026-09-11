"""Tests for scripts/release_tag_guard.sh, the release pipeline's tag gate.

The v0.37.0 re-run built a five-day-old tree because the gate treated "the tag
already exists" as success without ever resolving what that tag pointed at.
These pin the three outcomes it has to tell apart: no tag creates one, a tag on
the same commit is an idempotent re-run, and a tag on a different commit is a
refusal that names both commits and leaves the tag where it is.
"""

import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }

glob REPO_ROOT: Path = Path(__file__).resolve().parents[3],
     GUARD: str = str(REPO_ROOT / "scripts" / "release_tag_guard.sh"),
     VERSION: str = "0.37.0",
     VTAG: str = "v0.37.0";

"""A git environment isolated from the developer's own config and identity."""
def git_env(home: str) -> dict[(str, str)] {
    env: dict[str, str] = dict(os.environ);
    env["HOME"] = home;
    env["GIT_CONFIG_GLOBAL"] = os.path.join(home, "gitconfig-absent");
    env["GIT_CONFIG_SYSTEM"] = os.path.join(home, "gitconfig-absent");
    env["GIT_AUTHOR_NAME"] = "release test";
    env["GIT_AUTHOR_EMAIL"] = "release-test@example.invalid";
    env["GIT_COMMITTER_NAME"] = "release test";
    env["GIT_COMMITTER_EMAIL"] = "release-test@example.invalid";
    return env;
}

def git(args: list[str], cwd: str, home: str) -> any {
    return subprocess.run(
        ["git"] + args,
        cwd=cwd,
        env=git_env(home),
        capture_output=True,
        text=True,
        check=True
    );
}

"""A bare remote plus a work clone carrying two commits on main."""
def scaffold -> dict[(str, str)] {
    base = tempfile.mkdtemp(prefix="jac-release-tag-guard-");
    remote = os.path.join(base, "remote.git");
    work = os.path.join(base, "work");
    subprocess.run(
        ["git", "init", "-q", "--bare", "-b", "main", remote],
        check=True,
        env=git_env(base)
    );
    subprocess.run(
        ["git", "init", "-q", "-b", "main", work], check=True, env=git_env(base)
    );
    (Path(work) / "a.txt").write_text("first\n");
    git(["add", "-A"], work, base);
    git(["commit", "-qm", "first"], work, base);
    old = git(["rev-parse", "HEAD"], work, base).stdout.strip();
    (Path(work) / "a.txt").write_text("second\n");
    git(["commit", "-qam", "second"], work, base);
    new = git(["rev-parse", "HEAD"], work, base).stdout.strip();
    git(["remote", "add", "origin", remote], work, base);
    git(["push", "-q", "origin", "main"], work, base);
    return {"base": base, "remote": remote, "work": work, "old": old, "new": new};
}

def run_guard(fx: dict[(str, str)], commit: str) -> any {
    return subprocess.run(
        ["bash", GUARD, VERSION, commit, "origin"],
        cwd=fx["work"],
        env=git_env(fx["base"]),
        capture_output=True,
        text=True
    );
}

"""What the remote tag resolves to, peeling an annotated tag; "" when absent."""
def remote_tag_commit(fx: dict[(str, str)]) -> str {
    out = git(
        [
            "ls-remote",
            "--tags",
            "origin",
            "refs/tags/" + VTAG,
            "refs/tags/" + VTAG + "^{}"
        ],
        fx["work"],
        fx["base"]
    ).stdout;
    plain = "";
    peeled = "";
    for line in out.splitlines() {
        parts = line.split("\t");
        if (len(parts) != 2) {
            continue;
        }
        if parts[1].strip().endswith("^{}") {
            peeled = parts[0].strip();
        } elif (parts[1].strip() == "refs/tags/" + VTAG) {
            plain = parts[0].strip();
        }
    }
    return peeled or plain;
}

def tag_at(fx: dict[(str, str)], commit: str, annotated: bool = True) {
    args = ["tag"];
    if annotated {
        args += ["-a", "-m", "jac " + VERSION];
    }
    args += [VTAG, commit];
    git(args, fx["work"], fx["base"]);
    git(["push", "-q", "origin", "refs/tags/" + VTAG], fx["work"], fx["base"]);
}

test "no existing tag: the guard creates it at the release commit" {
    fx = scaffold();
    try {
        res = run_guard(fx, fx["new"]);
        assert res.returncode == 0 , "tagging a fresh version must succeed: "
            + res.stdout
            + res.stderr;
        assert remote_tag_commit(fx) == fx["new"] , "the pushed tag must resolve to the commit being released";
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "existing tag on the release commit: the re-run is idempotent" {
    fx = scaffold();
    try {
        tag_at(fx, fx["new"]);
        res = run_guard(fx, fx["new"]);
        assert res.returncode == 0 , "a recovery re-run of the same commit must proceed: "
            + res.stdout
            + res.stderr;
        assert remote_tag_commit(fx) == fx["new"] , "the tag must still resolve to the release commit";
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "existing annotated tag on another commit: refuse, naming both commits" {
    fx = scaffold();
    try {
        tag_at(fx, fx["old"]);
        res = run_guard(fx, fx["new"]);
        out = res.stdout + res.stderr;
        assert res.returncode != 0 , "a tag pointing at a different commit must fail the release instead of building the old tree; got: "
            + out;
        assert (fx["old"] in out) , "the refusal must name the commit the tag already points at: "
            + out;
        assert (fx["new"] in out) , "the refusal must name the commit being released: "
            + out;
        assert remote_tag_commit(fx) == fx["old"] , "a refusal must leave the existing tag exactly where it was";
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "existing lightweight tag on another commit: refuse as well" {
    fx = scaffold();
    try {
        tag_at(fx, fx["old"], annotated=False);
        res = run_guard(fx, fx["new"]);
        out = res.stdout + res.stderr;
        assert res.returncode != 0 , "an unannotated stale tag must refuse too: " + out;
        assert (fx["old"] in out) , "the refusal must name the commit the tag already points at: "
            + out;
        assert remote_tag_commit(fx) == fx["old"] , "a refusal must leave the existing tag exactly where it was";
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}

test "an unresolved release commit is refused before anything is tagged" {
    fx = scaffold();
    try {
        res = run_guard(fx, "");
        assert res.returncode != 0 , "an empty release commit must fail loudly";
        assert remote_tag_commit(fx) == "" , "nothing may be tagged when the release commit is unknown";
    } finally {
        shutil.rmtree(fx["base"], ignore_errors=True);
    }
}
