import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.project.tool_paths { jac_global_prefix }

glob TREE_HASH_PREFIX: str = "sha256-",
     STORE_DIR_NAME: str = "store",
     TMP_DIR_NAME: str = "_tmp",
     ORIGIN_MARKER: str = ".jac-origin",
     HASH_EXCLUDE_DIRS: set = {".git", ".jac", "node_modules", "__pycache__"};


obj JacDepError(Exception) {
    has message: str = "";

    def postinit -> None;
}

impl JacDepError.postinit -> None {
    Exception.__init__(self, self.message);
}


def store_root -> Path {
    return jac_global_prefix() / STORE_DIR_NAME;
}


def normalize_git_url(spec: str) -> str {
    spec = spec.strip().rstrip("/");
    known = spec.startswith(("https://", "http://", "file://", "/", "./", "../", "~/"));
    if not known and spec.startswith("git@") and ":" in spec {
        spec = "https://" + spec[4:].replace(":", "/", 1);
    } elif not known and spec.startswith("ssh://") {
        rest = spec[len("ssh://"):];
        if rest.startswith("git@") {
            rest = rest[4:];
        }
        spec = "https://" + (rest.replace(":", "/", 1) if ":" in rest else rest);
    } elif not known and "://" in spec {
        raise JacDepError(f"Unsupported git URL scheme: {spec}");
    } elif not known {
        spec = "https://" + spec;
    }
    if spec.endswith(".git") {
        spec = spec[:-4];
    }
    return spec;
}


def git_package_name(spec: str) -> str {
    base = normalize_git_url(spec);
    return base.rsplit("/", 1)[-1];
}


def _run_git(args: list[str], cwd: str | None = None) -> str {
    result = subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True);
    if result.returncode != 0 {
        detail = (result.stderr or result.stdout or "").strip();
        raise JacDepError(f"git {' '.join(args)} failed:\n  {detail}");
    }
    return result.stdout.strip();
}


def dirhash(tree_dir: Path) -> str {
    import hashlib;
    entries: list[str] = [];
    prefix_len = len(str(tree_dir)) + 1;
    for (dir_root, dirs, files) in os.walk(tree_dir) {
        dirs[:] = sorted(
            d
            for d in dirs
            if d not in HASH_EXCLUDE_DIRS
        );
        for fname in sorted(files) {
            if fname in HASH_EXCLUDE_DIRS {
                continue;
            }
            fpath = Path(str(dir_root)) / str(fname);
            rel = str(fpath)[prefix_len:].replace(os.sep, "/");
            digest = hashlib.sha256(fpath.read_bytes()).hexdigest();
            entries.append(f"{rel}\n{digest}\n");
        }
    }
    joined = "".join(entries).encode("utf-8");
    return TREE_HASH_PREFIX + hashlib.sha256(joined).hexdigest();
}


def _clone_to(dest: Path, url: str) {
    if dest.exists() {
        shutil.rmtree(dest, ignore_errors=True);
    }
    dest.parent.mkdir(parents=True, exist_ok=True);
    try {
        _run_git(["clone", "--quiet", "--filter=blob:none", url, str(dest)]);
    } except JacDepError {
        raise JacDepError(
            f"Could not clone {url}. Check the URL and your credentials."
        ) from None;
    }
}


def checkout_tree(url: str, ref: str, sha: str | None, dest: Path) -> str {
    tmp = Path(tempfile.mkdtemp(prefix="jac_fetch_"));
    try {
        repo = tmp / "repo";
        _clone_to(repo, url);
        wanted = sha or ref or "HEAD";
        if sha and ref and ref != sha {
            resolved = _run_git(
                ["rev-parse", "--verify", ref + "^{commit}"], cwd=str(repo)
            );
            if resolved != sha {
                raise JacDepError(
                    f"Ref '{ref}' of {url} now points to {resolved}, "
                    f"but the recorded commit is {sha}"
                );
            }
        }
        try {
            _run_git(["checkout", "--quiet", "--detach", wanted], cwd=str(repo));
        } except JacDepError {
            raise JacDepError(f"Commit '{wanted}' not reachable in {url}") from None;
        }
        resolved = _run_git(["rev-parse", "HEAD"], cwd=str(repo));
        if sha and resolved != sha {
            raise JacDepError(f"Resolved {resolved} but expected {sha} for {url}");
        }
        if dest.exists() {
            shutil.rmtree(dest);
        }
        shutil.copytree(repo, dest, symlinks=True);
        shutil.rmtree(dest / ".git", ignore_errors=True);
        return resolved;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


def _read_origin_meta(marker: Path) -> dict {
    import json;
    return json.loads(marker.read_text(encoding="utf-8"));
}


def _write_origin_meta(dest: Path, meta: dict) {
    import json;
    (dest / ORIGIN_MARKER).write_text(
        json.dumps(meta, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    );
}


def _store_hit_for(
    store_dir: Path, url: str, sha: str, expected_tree: str, verify: bool
) -> dict | None {
    for candidate in sorted(store_dir.glob(TREE_HASH_PREFIX + "*")) {
        if not candidate.is_dir() {
            continue;
        }
        try {
            meta = _read_origin_meta(candidate / ORIGIN_MARKER);
        } except (OSError, ValueError) {
            continue;
        }
        if meta.get("sha") != sha or meta.get("url") != url {
            continue;
        }
        if not verify and not expected_tree {
            return {
                "path": str(candidate),
                "sha": sha,
                "tree": str(meta.get("tree", "")),
                "cached": True
            };
        }
        expected = expected_tree or candidate.name;
        if dirhash(candidate) == expected {
            return {
                "path": str(candidate),
                "sha": sha,
                "tree": expected,
                "cached": True
            };
        }
    }
    return None;
}


def fetch_package(
    url: str,
    ref: str = "",
    sha: str | None = None,
    expected_tree: str = "",
    verify: bool = True
) -> dict {
    url = normalize_git_url(url);
    store_dir = store_root();
    (store_dir / TMP_DIR_NAME).mkdir(parents=True, exist_ok=True);
    if sha {
        hit = _store_hit_for(store_dir, url, sha, expected_tree, verify);
        if hit is not None {
            return hit;
        }
    }
    staging = Path(tempfile.mkdtemp(prefix="jac_stage_", dir=store_dir / TMP_DIR_NAME));
    try {
        tree_dest = staging / "tree";
        resolved_sha = checkout_tree(url, ref, sha, tree_dest);
        tree_hash = dirhash(tree_dest);
        final = store_dir / tree_hash;
        if final.exists() {
            shutil.rmtree(tree_dest, ignore_errors=True);
            meta = _read_origin_meta(final / ORIGIN_MARKER);
        } else {
            _write_origin_meta(
                tree_dest, {"url": url, "sha": resolved_sha, "tree": tree_hash}
            );
            try {
                os.rename(str(tree_dest), str(final));
            } except OSError {
                shutil.rmtree(final, ignore_errors=True);
                os.rename(str(tree_dest), str(final));
            }
            meta = {"url": url, "sha": resolved_sha, "tree": tree_hash};
        }
        return {
            "path": str(final),
            "sha": meta["sha"],
            "tree": meta["tree"],
            "cached": bool(sha) and meta["sha"] == sha
        };
    } finally {
        shutil.rmtree(staging, ignore_errors=True);
    }
}


def prune_tmp {
    tmp_dir = store_root() / TMP_DIR_NAME;
    if tmp_dir.exists() {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}


def _link_tree(src: Path, dest: Path) {
    dest.mkdir(parents=True);
    for item in sorted(src.iterdir()) {
        target = dest / item.name;
        if item.is_dir() {
            _link_tree(item, target);
        } else {
            try {
                os.link(item, target);
            } except OSError {
                shutil.copy2(item, target, follow_symlinks=False);
            }
        }
    }
}


def materialize(src: Path, dest: Path) -> Path {
    if dest.exists() {
        shutil.rmtree(dest);
    }
    dest.parent.mkdir(parents=True, exist_ok=True);
    _link_tree(src, dest);
    return dest;
}
