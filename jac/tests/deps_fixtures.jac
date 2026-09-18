"""Shared fixtures for the pure-jac dependency tests.

Real git origins, throwaway projects, and an isolated JAC_GLOBAL_DIR —
the fixture set every deps test needs, defined once. Import as
`from tests.project.deps_fixtures`, which resolves identically under the
single `jac` binary and a source checkout (same mechanism as
`tests.support`).
"""

import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }


def make_git_repo(
    path: Path, jac_toml: str, files: dict[str, str], branch: str = ""
) -> str {
    path.mkdir(parents=True, exist_ok=True);
    (path / "jac.toml").write_text(jac_toml, encoding="utf-8");
    for (name, content) in files.items() {
        target = path / name;
        target.parent.mkdir(parents=True, exist_ok=True);
        target.write_text(content, encoding="utf-8");
    }
    env = dict(os.environ);
    subprocess.run(
        ["git", "init", "-q"] + (["-b", branch] if branch else []) + [str(path)],
        check=True,
        env=env
    );
    subprocess.run(
        [
            "git",
            "-C",
            str(path),
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@t",
            "add",
            "-A"
        ],
        check=True,
        env=env
    );

    subprocess.run(
        [
            "git",
            "-C",
            str(path),
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@t",
            "commit",
            "-q",
            "-m",
            "init"
        ],
        check=True,
        env=env
    );
    return str(path);
}


def git_head(path: Path) -> str {
    return subprocess.run(
        ["git", "-C", str(path), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True
    ).stdout.strip();
}


def git_commit_all(path: Path, message: str = "next") -> str {
    env = dict(os.environ);
    subprocess.run(["git", "-C", str(path), "add", "-A"], check=True, env=env);
    subprocess.run(
        [
            "git",
            "-C",
            str(path),
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@t",
            "commit",
            "-q",
            "-m",
            message
        ],
        check=True,
        env=env
    );
    return git_head(path);
}

def git_branch(path: Path) -> str {
    return subprocess.run(
        ["git", "-C", str(path), "rev-parse", "--abbrev-ref", "HEAD"],
        check=True,
        capture_output=True,
        text=True
    ).stdout.strip();
}


def make_project(toml_text: str) -> tuple[JacConfig, str] {
    tmp = tempfile.mkdtemp(prefix="jac_dep_test_");
    project_dir = Path(tmp) / "proj";
    project_dir.mkdir();
    (project_dir / "jac.toml").write_text(toml_text, encoding="utf-8");
    config = JacConfig.load(project_dir / "jac.toml");
    config.project_root = project_dir;
    return (config, tmp);
}


def isolate_store -> tuple[str, str | None] {
    tmp = tempfile.mkdtemp(prefix="jac_store_test_");
    old = os.environ.get("JAC_GLOBAL_DIR");
    os.environ["JAC_GLOBAL_DIR"] = tmp;
    return (tmp, old);
}


def restore_store(tmp: str, old: str | None) {
    if old is None {
        os.environ.pop("JAC_GLOBAL_DIR", None);
    } else {
        os.environ["JAC_GLOBAL_DIR"] = old;
    }
    shutil.rmtree(tmp, ignore_errors=True);
}
