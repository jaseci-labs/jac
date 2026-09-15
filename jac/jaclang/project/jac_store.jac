import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.project.tool_paths { jac_global_prefix }
import from jaclang.cli.console { console }

glob TREE_HASH_PREFIX: str = "sha256-",
     STORE_DIR_NAME: str = "store",
     TMP_DIR_NAME: str = "_tmp",
     ORIGIN_MARKER: str = ".jac-origin",
     HASH_EXCLUDE: set = {".git", ".jac", "node_modules", "__pycache__", ORIGIN_MARKER};


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
            if d not in HASH_EXCLUDE
        );
        for fname in sorted(files) {
            if fname in HASH_EXCLUDE {
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


def _ref_agreement(url: str, ref: str, sha: str) -> tuple[bool, bool] | None {
    try {
        out = _run_git(["ls-remote", url, ref]);
    } except JacDepError {
        return None;
    }
    canonical = {
        "refs/heads/" + ref,
        "refs/tags/" + ref,
        "refs/tags/" + ref + "^{}",
        ref
    };
    matched = False;
    is_tag = False;
    agrees = False;
    for line in out.splitlines() {
        parts = line.split(None, 1);
        if len(parts) != 2 {
            continue;
        }
        (oid, refname) = (parts[0], parts[1].strip());
        if refname not in canonical {
            continue;
        }
        matched = True;
        if refname.startswith("refs/tags/") {
            is_tag = True;
        }
        if oid == sha {
            agrees = True;
        }
    }
    if not matched {
        return None;
    }
    return (agrees, is_tag);
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
        if expected_tree and candidate.name == expected_tree {
            return {"path": str(candidate), "sha": sha, "tree": expected_tree};
        }
        if not verify and not expected_tree {
            return {
                "path": str(candidate),
                "sha": sha,
                "tree": str(meta.get("tree", ""))
            };
        }
        expected = expected_tree or candidate.name;
        if dirhash(candidate) == expected {
            return {"path": str(candidate), "sha": sha, "tree": expected};
        }
    }
    return None;
}


def _tree_matches(tree_dir: Path, expected: str) -> bool {
    try {
        return dirhash(tree_dir) == expected;
    } except OSError {
        return False;
    }
}


def fetch_package(
    url: str,
    ref: str = "",
    sha: str | None = None,
    expected_tree: str = "",
    verify: bool = True,
    frozen: bool = False
) -> dict {
    url = normalize_git_url(url);
    store_dir = store_root();
    (store_dir / TMP_DIR_NAME).mkdir(parents=True, exist_ok=True);
    if sha and ref and ref != sha and not frozen {
        agreement = _ref_agreement(url, ref, sha);
        if agreement is not None {
            (agrees, is_tag) = agreement;
            if not agrees and is_tag {
                raise JacDepError(
                    f"Tag '{ref}' of {url} no longer resolves to recorded "
                    f"commit {sha}. The tag was moved; verify upstream and "
                    f"re-lock with 'jac update'."
                );
            }
            if not agrees {
                console.warning(
                    f"ref '{ref}' of {url} moved past recorded commit "
                    f"{sha[:12]}; replaying the recorded commit "
                    "(run 'jac update' to advance)"
                );
                ref = "";
            }
        }
    }
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
        } else {
            _write_origin_meta(
                tree_dest, {"url": url, "sha": resolved_sha, "tree": tree_hash}
            );
            try {
                os.rename(str(tree_dest), str(final));
            } except OSError {
                if _tree_matches(final, tree_hash) {
                    shutil.rmtree(tree_dest, ignore_errors=True);
                } else {
                    shutil.rmtree(final, ignore_errors=True);
                    os.rename(str(tree_dest), str(final));
                }
            }
        }
        return {"path": str(final), "sha": resolved_sha, "tree": tree_hash};
    } finally {
        shutil.rmtree(staging, ignore_errors=True);
    }
}


def _copy_tree(src: Path, dest: Path) {
    dest.mkdir(parents=True);
    for item in sorted(src.iterdir()) {
        target = dest / item.name;
        if item.is_symlink() or not item.is_dir() {
            shutil.copy2(item, target, follow_symlinks=False);
        } else {
            _copy_tree(item, target);
        }
    }
}


def materialize(src: Path, dest: Path) -> Path {
    if dest.exists() {
        shutil.rmtree(dest);
    }
    dest.parent.mkdir(parents=True, exist_ok=True);
    _copy_tree(src, dest);
    return dest;
}
