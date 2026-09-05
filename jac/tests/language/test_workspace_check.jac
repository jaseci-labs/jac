"""`jac check` and `jac test` in a workspace.

With no paths, `jac check` compiles one rooted program per app of jac.toml
(each with that app's facts) and then sweeps the files no app reached. A
shared module is checked once under every app that reaches it, and when
more than one app was checked every diagnostic carries a `[<app>] ` prefix.
`--app <name>` restricts the run to one app. `jac test <app>` re-roots test
collection at that app's root, and a bare `jac test` re-roots at the
default app, the same way a bare `jac run` does.

The fixture is copied to a temp dir before use: the runner never collects
test files that live under a `fixtures/` directory, and the workspace reader
caches by jac.toml path."""

import io;
import os;
import shutil;
import sys;
import tempfile;
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import from jaclang.cli.commands { analysis }
import from jaclang.project.config { JacConfig, set_config }

glob FIXTURE: str = os.path.join(
         JAC_ROOT, "tests", "language", "fixtures", "workspace"
     ),
     WEB_ENTRY: str = os.path.join("web", "main.jac"),
     SVC_ENTRY: str = os.path.join("core", "svc.jac"),
     CLI_ENTRY: str = os.path.join("cli", "main.jac"),
     HELPER: str = os.path.join("core", "helper.jac"),
     _tmp_dirs: list[str] = [],
     _orig_cwd: str = os.getcwd();

def _app_name(app: any) -> str {
    if app is None {
        raise AssertionError("expected an app, got None");
    }
    return str(app.name);
}


def _workspace -> str {
    parent = tempfile.mkdtemp(prefix="jacws_");
    _tmp_dirs.append(parent);
    d = os.path.join(parent, "wscheck");
    shutil.copytree(FIXTURE, d);
    return d;
}

def _capture_in(d: str, fn: any) -> tuple[int, str] {
    old = os.getcwd();
    os.chdir(d);
    set_config(None);
    captured = io.StringIO();
    sys.stdout = captured;
    sys.stderr = captured;
    try {
        rc = fn();
    } finally {
        sys.stdout = sys.__stdout__;
        sys.stderr = sys.__stderr__;
        os.chdir(old);
        set_config(None);
    }
    return (rc, captured.getvalue());
}

def _check_in(d: str, app: str = "", paths: list[str] = []) -> tuple[int, str] {
    def go -> int {
        return analysis.check(paths=list(paths), app=app, jobs="0");
    }
    return _capture_in(d, go);
}

def _collect_in(d: str, target: str) -> tuple[int, str] {
    def go -> int {
        return analysis.`test(target=target, collect_only=True, jobs="0");
    }
    return _capture_in(d, go);
}

"""True when a `Checking <path>...` progress line names this file."""
def _checked(out: str, rel: str) -> bool {
    for line in out.splitlines() {
        text = line.strip();
        if text.startswith("Checking ") and text.rstrip(".").endswith(rel) {
            return True;
        }
    }
    return False;
}

def _cleanup {
    os.chdir(_orig_cwd);
    set_config(None);
    for d in _tmp_dirs {
        shutil.rmtree(d, ignore_errors=True);
    }
    _tmp_dirs.clear();
}

test "the fixture is a three-app workspace" {
    cfg = JacConfig.discover(start_path=Path(FIXTURE));
    assert cfg is not None and cfg.is_workspace;
    assert list(cfg.apps) == ["web", "svc", "cli"] , str(list(cfg.apps));
    assert cfg.default_app == "web";
    assert cfg.apps["svc"].is_file_rooted();
    assert not cfg.apps["web"].is_file_rooted();
    assert [a.name for a in cfg.serving_apps()] == ["web", "svc"];
    assert cfg.app_for_path(os.path.join(FIXTURE, HELPER)) is None , (
        "core/helper.jac belongs to no app: it is shared"
    );
    assert _app_name(cfg.app_for_path(os.path.join(FIXTURE, SVC_ENTRY))) == "svc";
    assert _app_name(cfg.app_for_path(os.path.join(FIXTURE, CLI_ENTRY))) == "cli";
    assert _app_name(cfg.app_for_path(os.path.join(FIXTURE, WEB_ENTRY))) == "web";
}

test "bare jac check roots one program per app and prefixes diagnostics" {
    d = _workspace();
    (rc, out) = _check_in(d);
    assert rc == 0 , f"rc={rc}\n{out}";
    for entry_file in [WEB_ENTRY, SVC_ENTRY, CLI_ENTRY] {
        assert _checked(out, entry_file) , f"{entry_file} was not checked as an app root:\n{out}";
    }
    # The shared helper carries one W2058; it is reported once per app that
    # reaches it, each under that app's prefix.
    assert out.count("W2058") == 3 , f"expected the shared warning under 3 apps:\n{out}";
    for app in ["web", "svc", "cli"] {
        assert f"[{app}] " in out , f"missing [{app}] prefix:\n{out}";
    }
    assert "helper.jac" in out , out;
    assert "[shared] " not in out , f"every shared file here is reached by an app:\n{out}";
    # The shared <div> component is imported only by the web app (a DOM ui,
    # not a mobile app), so the mobUI guard has nothing to say.
    assert "E1105" not in out , out;
    # Apps importing shared code, and shared code importing shared code, are
    # the legal directions of the layering laws.
    assert "E2039" not in out and "W2039" not in out , out;
    assert "E2040" not in out and "W2040" not in out , out;
    _cleanup();
}

test "jac check --app restricts the run to one app" {
    d = _workspace();
    (rc, out) = _check_in(d, app="cli");
    assert rc == 0 , f"rc={rc}\n{out}";
    assert _checked(out, CLI_ENTRY) , out;
    assert not _checked(out, WEB_ENTRY) , f"web must not be checked under --app cli:\n{out}";
    assert not _checked(out, SVC_ENTRY) , f"svc must not be checked under --app cli:\n{out}";
    # The helper is now reached by one program only, and a single-app run
    # prints no app prefixes.
    assert out.count("W2058") == 1 , out;
    assert "[cli] " not in out and "[web] " not in out and "[svc] " not in out , out;
    _cleanup();
}

test "jac check --app with an unknown name lists the apps" {
    d = _workspace();
    (rc, out) = _check_in(d, app="nope");
    assert rc == 2 , f"rc={rc}\n{out}";
    assert "no app named 'nope'" in out , out;
    assert "web" in out and "svc" in out and "cli" in out , out;
    _cleanup();
}

test "jac check <path> keeps the file-per-root behavior" {
    d = _workspace();
    (rc, out) = _check_in(d, paths=[HELPER]);
    assert rc == 0 , f"rc={rc}\n{out}";
    assert out.count("W2058") == 1 , out;
    assert not _checked(out, WEB_ENTRY) and not _checked(out, CLI_ENTRY) , out;
    assert "[shared] " not in out and "[web] " not in out , out;
    _cleanup();
}

test "jac test <app> re-roots collection at the app" {
    d = _workspace();
    (rc, out) = _collect_in(d, "cli");
    assert rc == 0 , f"rc={rc}\n{out}";
    assert os.path.join("cli", "test_greet.jac") in out , out;
    assert os.path.join("web", "test_page.jac") not in out , out;
    assert "test_greet.jac" in out and "2 test files collected" in out , out;
    assert "web/" not in out and "core/" not in out , out;
    (rc, out) = _collect_in(d, "web");
    assert rc == 0 , f"rc={rc}\n{out}";
    assert os.path.join("web", "test_page.jac") in out , out;
    assert os.path.join("cli", "test_greet.jac") not in out , out;
    _cleanup();
}

test "bare jac test in a workspace re-roots at the default app" {
    d = _workspace();
    (rc, out) = _collect_in(d, "");
    assert rc == 0 , f"rc={rc}\n{out}";
    assert os.path.join("web", "test_page.jac") in out , out;
    assert os.path.join("cli", "test_greet.jac") not in out , (
        f"default-app web must not collect the cli app's tests:\n{out}"
    );
    _cleanup();
}

test "jac test <name> that is neither an app nor a path errors" {
    d = _workspace();
    (rc, out) = _collect_in(d, "nope");
    assert rc == 1 , f"rc={rc}\n{out}";
    assert "neither an app of jac.toml nor a path" in out , out;
    _cleanup();
}

def _insert_import(path: str, line: str) {
    with open(path, "r") as f {
        text = f.read();
    }
    lines: list[str] = [str(part) for part in text.split("\n")];
    at = 0;
    if lines and lines[0].startswith('"""') {
        closing = [
            i
            for (i, l) in enumerate(lines)
            if i > 0 and '"""' in l
        ];
        at = (closing[0] + 1) if closing else 1;
        if lines[0].count('"""') >= 2 {
            at = 1;
        }
    }
    lines.insert(at, line);
    with open(path, "w") as f {
        f.write("\n".join(lines));
    }
}

test "the workspace gate reports E5107 for a walker module two serving apps reach with no default app" {
    d = _workspace();
    toml_path = os.path.join(d, "jac.toml");
    with open(toml_path, "r") as f {
        toml = f.read();
    }
    with open(toml_path, "w") as f {
        f.write(toml.replace('default-app = "web"\n', ""));
    }
    with open(os.path.join(d, "core", "graph.jac"), "w") as f {
        f.write("node Note {\n    has text: str = \"\";\n}\n");
    }
    _insert_import(
        os.path.join(d, "web", "main.jac"), "import from core.graph { Note }"
    );
    _insert_import(
        os.path.join(d, "core", "svc.jac"), "import from core.graph { Note }"
    );
    (rc, out) = _check_in(d);
    assert rc != 0 , out;
    assert "E5107" in out and "graph.jac" in out , out;
    assert "web" in out and "svc" in out , out;
}

test "the app-isolation law fires on a warm interface cache too" {
    d = _workspace();
    leak = os.path.join("web", "leak.jac");
    with open(os.path.join(d, leak), "w") as f {
        f.write(
            "import from cli.main { cli_secret }\n\n"
            "def leak -> str {\n    return cli_secret();\n}\n"
        );
    }
    (rc_cold, cold) = _check_in(d, paths=[leak]);
    # The second run hydrates cli/main.jac from the interface cache instead of
    # compiling it; the law must read the app off the file, not off a stamp
    # that only a full compile writes.
    (rc_warm, warm) = _check_in(d, paths=[leak]);
    assert cold.count("W2039") >= 1 , f"cold run:\n{cold}";
    assert warm.count("W2039") == cold.count("W2039") , (
        f"warm run lost the law:\n{warm}"
    );
    _cleanup();
}


test "the gate body-checks every module an app owns, not only its entry" {
    d = _workspace();
    bad = os.path.join(d, "cli", "cmd.jac");
    with open(bad, "w") as f {
        f.write("def total(n: int) -> int {\n    return \"not an int\";\n}\n");
    }
    with open(os.path.join(d, CLI_ENTRY), "a") as f {
        f.write(
            "\nimport from .cmd { total }\n\ndef use_total -> int {\n    return total(2);\n}\n"
        );
    }
    (rc, out) = _check_in(d);
    assert rc != 0 , f"a body type error in a module the cli app reaches must fail the gate:\n{out}";
    assert _checked(out, os.path.join("cli", "cmd.jac")) , f"cmd.jac was never checked as a root:\n{out}";
    assert "cmd.jac" in out and "[cli] " in out , out;
    (rc_app, out_app) = _check_in(d, app="cli");
    assert rc_app != 0 , f"--app cli must fail the same way:\n{out_app}";
    _cleanup();
}
