import os;
import subprocess;
import tempfile;
import from pathlib { Path }

def _sh(args: list[str], cwd: Path) -> None;

def _origin(base: Path) -> Path;

test "older lines keep the newest patch of each earlier minor line" {
    tags = [
        "v0.38.0",
        "v0.37.25",
        "v0.37.3",
        "v0.36.9",
        "v0.35.1",
        "v0.34.27",
        "v2.3.28",
        "dev"
    ];
    lines = older_lines("0.38.0", tags);
    assert [l.label for l in lines] == ["v0.37", "v0.36"];
    assert [l.tag for l in lines] == ["v0.37.25", "v0.36.9"];
    assert older_lines("0.38.0", tags, 4)[-1].tag == "v0.34.27";
}

test "the checkout follows the serving release or the newest one below it" {
    tags = ["v0.38.1", "v0.38.0", "v0.37.25"];
    assert checkout_target("0.38.0", tags) == "v0.38.0";
    assert checkout_target("0.38.5", tags) == "v0.38.1";
    assert checkout_target("dev", tags) == "origin/HEAD";
}

test "ensure_repo clones once, checks out the serving tag and exports older docs" {
    with tempfile.TemporaryDirectory() as tmp {
        base = Path(tmp);
        origin = _origin(base);
        saved = {k: os.environ.get(k) for k in [REPO_URL_ENV, DIR_ENV]};
        os.environ[REPO_URL_ENV] = "file://" + str(origin);
        os.environ[DIR_ENV] = str(base / "knowledge");
        try {
            status = ensure_repo("0.38.0");
            assert status.phase == "ready" , status.detail;
            assert status.checked_out == "v0.38.0";
            assert [l.tag for l in status.lines] == ["v0.37.2", "v0.36.1"];
            served = (repo_dir() / DOCS_PATH / "index.md").read_text();
            assert "release 0.38.0" in served;
            older = exported_docs(status.lines[0]) / "index.md";
            assert "release 0.37.2" in older.read_text();
            assert checkout_root() == repo_dir();
            again = ensure_repo("0.38.0");
            assert again.phase == "ready" and again.fetched_at == status.fetched_at;
            assert read_status().checked_out == "v0.38.0";
            moved = ensure_repo("0.37.2");
            assert moved.phase == "ready" and moved.checked_out == "v0.37.2" , (
                "a new serving release must check out its own tag, not wait for the next fetch"
            );
        } finally {
            for (k, v) in saved.items() {
                if v is None {
                    os.environ.pop(k, None);
                } else {
                    os.environ[k] = v;
                }
            }
        }
    }
}

impl _sh(args: list[str], cwd: Path) -> None {
    subprocess.run(args, cwd=str(cwd), check=True, capture_output=True);
}

impl _origin(base: Path) -> Path {
    work = base / "work";
    docs = work / "jac" / "jaclang" / "cli" / "docs";
    docs.mkdir(parents=True);
    _sh(["git", "init", "-q", "-b", "main"], work);
    _sh(["git", "config", "user.email", "t@example.com"], work);
    _sh(["git", "config", "user.name", "t"], work);
    for version in ["0.36.1", "0.37.0", "0.37.2", "0.38.0", "2.3.28"] {
        (docs / "index.md").write_text("# Jac\n\nrelease " + version + "\n");
        (docs / "nav.json").write_text(
            '{"version": 1, "nav": [{"title": "Jac", "page": "index.md"}]}'
        );
        _sh(["git", "add", "-A"], work);
        _sh(["git", "commit", "-q", "-m", "release " + version], work);
        _sh(["git", "tag", "v" + version], work);
    }
    bare = base / "origin.git";
    _sh(["git", "clone", "-q", "--bare", str(work), str(bare)], base);
    _sh(["git", "config", "uploadpack.allowFilter", "true"], bare);
    return bare;
}

test "a relative knowledge directory still reaches ready" {
    with tempfile.TemporaryDirectory() as tmp {
        base = Path(tmp);
        origin = _origin(base);
        saved = {k: os.environ.get(k) for k in [REPO_URL_ENV, DIR_ENV]};
        cwd = os.getcwd();
        os.environ[REPO_URL_ENV] = "file://" + str(origin);
        os.environ[DIR_ENV] = "knowledge";
        os.chdir(base);
        try {
            assert knowledge_dir().is_absolute();
            status = ensure_repo("0.38.0");
            assert status.phase == "ready" , status.detail;
            assert "release 0.37.2"
                in (exported_docs(status.lines[0]) / "index.md").read_text();
        } finally {
            os.chdir(cwd);
            for (k, v) in saved.items() {
                if v is None {
                    os.environ.pop(k, None);
                } else {
                    os.environ[k] = v;
                }
            }
        }
    }
}
