import hashlib;
import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from jaclang.packages.artifact { pack_source_tree }

obj GitError(Exception) {}

obj GitCheckout {
    has url: str,
        commit: str,
        tree: Path;
}

def _git(args: list[str], cwd: Path | None = None) -> str {
    try {
        done = subprocess.run(
            ["git", *args],
            cwd=str(cwd) if cwd is not None else None,
            capture_output=True,
            text=True,
            check=False
        );
    } except FileNotFoundError {
        raise GitError("git is not installed; git dependencies need it on PATH");
    }
    if done.returncode != 0 {
        raise GitError(f"git {' '.join(args)} failed: {done.stderr.strip()}");
    }
    return done.stdout.strip();
}

def _mirror_dir(url: str) -> Path {
    import from jaclang.cache.registry { bucket }
    return bucket("pkg-git").ensure() / hashlib.sha256(url.encode()).hexdigest()[:20];
}

def checkout(url: str, rev: str = "") -> GitCheckout {
    import from jaclang.toolchains.store { InstallLock, offline }
    mirror = _mirror_dir(url);
    with InstallLock(mirror.with_suffix(".lock")) {
        if not (mirror / "HEAD").is_file() {
            if offline() {
                raise GitError(f"{url} is not cached and JAC_OFFLINE is set");
            }
            shutil.rmtree(mirror, ignore_errors=True);
            _git(["clone", "--mirror", "--quiet", url, str(mirror)]);
        } elif not offline() {
            _git(["remote", "update", "--prune"], cwd=mirror);
        }
        wanted = rev or "HEAD";
        try {
            commit = _git(
                ["rev-parse", "--verify", f"{wanted}^{{commit}}"], cwd=mirror
            );
        } except GitError {
            raise GitError(f"{url}: no branch, tag or commit named '{wanted}'");
        }
        work = mirror.parent / f"{mirror.name}-{commit[:16]}";
        done_marker = mirror.parent / f"{work.name}.ok";
        if not done_marker.is_file() or not work.is_dir() {
            shutil.rmtree(work, ignore_errors=True);
            work.mkdir(parents=True);
            archive = subprocess.run(
                ["git", "archive", "--format=tar", commit],
                cwd=str(mirror),
                capture_output=True,
                check=False
            );
            if archive.returncode != 0 {
                raise GitError(f"{url}@{commit[:12]}: git archive failed");
            }
            import io;
            import tarfile;
            with tarfile.open(fileobj=io.BytesIO(archive.stdout), mode="r:") as tf {
                tf.extractall(work, filter="data");
            }
            done_marker.write_text(commit, encoding="utf-8");
        }
    }
    return GitCheckout(url=url, commit=commit, tree=work);
}

def pack_checkout(co: GitCheckout) -> tuple[bytes, str] {
    data = pack_source_tree(co.tree);
    return (data, hashlib.sha256(data).hexdigest());
}

def resolve_path(base: Path, rel: str) -> Path {
    target = Path(rel);
    if not target.is_absolute() {
        target = base / target;
    }
    return Path(os.path.realpath(str(target)));
}
