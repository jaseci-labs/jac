"""Tests for kind-aware `jac run` dispatch.

`jac run` with no explicit file resolves the app (the implicit single app of a
plain jac.toml here), its kind (explicit `[project] kind` or inferred from the
entry-point codespace) and dispatches to execute / serve / build. These tests
cover the planner (`plan_app_run`) for every kind, kind inference
(`resolve_app_kind`), entry-point resolution, error paths, and real execution
of the two cheap runnable kinds (cli, cli-native)."""

import io;
import os;
import sys;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.commands { execution }
import from jaclang.project.config { JacConfig, set_config }
import from jaclang.project.apps { AppConfig }
import from jaclang.project.kinds {
    plan_app_run,
    plan_workspace,
    resolve_app_kind,
    resolve_entry,
    is_valid_kind,
    kind_entry,
    kind_spec,
    RunPlan,
    KIND_SPECS,
    VALID_KINDS
}

glob _tmp_dirs: list[str] = [];

"""Create a throwaway project dir with a jac.toml and (optionally) an entry file."""
def _mk_project(
    toml_extra: str,
    entry_name: str = "",
    entry_body: str = "with entry { print(\"ok\"); }"
) -> str {
    d = tempfile.mkdtemp(prefix="jackind_");
    _tmp_dirs.append(d);
    with open(os.path.join(d, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"p\"\n" + toml_extra);
    }
    if entry_name {
        with open(os.path.join(d, entry_name), "w") as f {
            f.write(entry_body);
        }
    }
    return d;
}

"""Build the RunPlan for a freshly-created project (its implicit single app)."""
def _plan(
    toml_extra: str,
    entry_name: str = "",
    entry_body: str = "with entry { print(\"ok\"); }"
) -> RunPlan {
    d = _mk_project(toml_extra, entry_name, entry_body);
    cfg = JacConfig.discover(start_path=Path(d));
    assert cfg is not None , "expected a discovered config";
    plan = plan_app_run(cfg, d, cfg.resolve_app(""));
    assert plan is not None , "expected a run plan";
    return plan;
}

def _cleanup {
    for d in _tmp_dirs {
        shutil.rmtree(d, ignore_errors=True);
    }
    _tmp_dirs.clear();
}

# ---------------------------------------------------------------------------
# One planner test per project kind (explicit [project] kind)
# ---------------------------------------------------------------------------
test "kind cli -> execute via run" {
    p = _plan("kind = \"cli\"\nentry-point = \"main.jac\"\n", "main.jac");
    assert p.kind == "cli";
    assert p.action == "execute";
    assert p.verb == "run";
}

test "kind cli-native -> execute via run" {
    p = _plan("kind = \"cli-native\"\nentry-point = \"main.jac\"\n", "main.jac");
    assert p.kind == "cli-native";
    assert p.action == "execute";
    assert p.verb == "run";
}

test "kind native-binary -> build via jac build --native" {
    p = _plan("kind = \"native-binary\"\nentry-point = \"main.jac\"\n", "main.jac");
    assert p.action == "build";
    assert p.verb == "native";
    assert "output" in p.flags;
    assert "--native" in p.command_line();
}

test "kind native-lib -> build a shared library via jac build --native --lib" {
    p = _plan("kind = \"native-lib\"\nentry-point = \"lib.jac\"\n", "lib.jac");
    assert p.action == "build";
    assert p.verb == "native";
    assert "--native" in p.command_line();
    assert p.flags.get("lib") == True;
    assert "--lib" in p.command_line();
}

test "kind service -> serve headless" {
    p = _plan("kind = \"service\"\nentry-point = \"api.sv.jac\"\n", "api.sv.jac");
    assert p.action == "serve";
    assert p.verb == "run";
    assert p.flags.get("no_client") == True;
    assert "--no-client" in p.command_line();
    # default port is not carried (keeps --show clean)
    assert "port" not in p.flags;
}

test "serve plan forwards a custom [serve] port from jac.toml" {
    p = _plan(
        "kind = \"service\"\nentry-point = \"api.sv.jac\"\n\n[serve]\nport = 3000\n",
        "api.sv.jac"
    );
    assert p.flags.get("port") == 3000;
    assert "--port 3000" in p.command_line();
}

test "kind service-mesh -> serve consumer" {
    p = _plan(
        "kind = \"service-mesh\"\nentry-point = \"consumer.sv.jac\"\n",
        "consumer.sv.jac"
    );
    assert p.action == "serve";
    assert p.verb == "run";
}

test "kind py-package -> build wheel via build --as" {
    p = _plan("kind = \"py-package\"\n", "main.jac");
    assert p.action == "build";
    assert p.verb == "build";
    assert p.flags.get("as") == "wheel";
    # bundle operates on the project, not a single entry file.
    assert p.entry_path == "";
}

test "kind js-package -> build npm via build --as" {
    p = _plan("kind = \"js-package\"\n", "main.jac");
    assert p.action == "build";
    assert p.verb == "build";
    assert p.flags.get("as") == "npm";
}

test "kind web-app -> serve dev (client framework is core)" {
    p = _plan("kind = \"web-app\"\nentry-point = \"app.jac\"\n", "app.jac");
    assert p.action == "serve";
    assert p.verb == "run";
    assert p.flags.get("dev") == True;
    # The kind decides the client; no plan carries a client flag.
    assert "client" not in p.flags;
    assert p.spec.ui == "dom";
}

test "kind web-static -> serve (client framework is core)" {
    p = _plan("kind = \"web-static\"\nentry-point = \"page.jac\"\n", "page.jac");
    assert p.action == "serve";
    assert p.verb == "run";
    assert "client" not in p.flags;
    assert p.spec.ui == "dom";
}

test "kind desktop -> serve the desktop client target (core)" {
    p = _plan("kind = \"desktop\"\nentry-point = \"app.jac\"\n", "app.jac");
    assert p.action == "serve";
    assert p.verb == "run";
    # The desktop target is a core client target -- it must reach the serve
    # path, not be turned away as a missing plugin. The kind alone selects
    # it: there is no --client flag on the plan or the command line.
    assert "client" not in p.flags;
    assert p.spec.ui == "dom";
    assert p.flags == {};
    assert p.command_line() == "jac run app.jac";
}

test "kind mobile -> build the mobile client shell (core)" {
    p = _plan("kind = \"mobile\"\nentry-point = \"app.jac\"\n", "app.jac");
    assert p.action == "build";
    assert p.verb == "build";
    # Must build the mobile shell, not fall through to a default .jab build:
    # the kind's ui says mobUI and there is no `as` projection.
    assert "client" not in p.flags;
    assert p.spec.ui == "mobui";
    assert "as" not in p.flags;
    assert p.command_line() == "jac build app.jac";
}

test "kind mobile with a platform carries it on the plan" {
    p = _plan("kind = \"mobile\"\nentry-point = \"app.jac\"\n", "app.jac");
    assert "platform" not in p.flags , "no platform unless the app names one";
    # A workspace app names its platform in its own table.
    d = _mk_project(
        "\n[apps.phone]\nkind = \"mobile\"\npath = \"phone\"\nplatform = \"ios\"\n"
    );
    os.makedirs(os.path.join(d, "phone"), exist_ok=True);
    with open(os.path.join(d, "phone", "main.jac"), "w") as f {
        f.write("with entry { print(\"ok\"); }");
    }
    cfg = JacConfig.discover(start_path=Path(d));
    assert cfg is not None;
    plan = plan_app_run(cfg, d, cfg.resolve_app(""));
    assert plan.flags == {"platform": "ios"};
    assert plan.command_line() == "jac build phone --platform ios";
}

# ---------------------------------------------------------------------------
# Kind inference (no explicit [project] kind)
# ---------------------------------------------------------------------------
test "plain .jac entry no longer infers cli-native (marker retired)" {
    # Pre-0.35 a main.na.jac entry inferred cli-native from the filename.
    # With the marker retired, native is a placement decision, not a kind
    # signal: plain .jac infers "cli" and cli-native must be explicit.
    p = _plan("entry-point = \"main.jac\"\n", "main.jac");
    assert p.kind == "cli";
}

test "infer web-app from a client-pinned entry" {
    p = _plan(
        "entry-point = \"main.jac\"\n\n[placement.pins]\nmain = \"client\"\n",
        "main.jac"
    );
    assert p.kind == "web-app";
}

test "infer cli from plain .jac entry" {
    p = _plan("entry-point = \"main.jac\"\n", "main.jac");
    assert p.kind == "cli";
}

test "infer web-app from plain .jac when jac-client is a dependency" {
    p = _plan(
        "entry-point = \"main.jac\"\n\n[dependencies]\njac-client = \"*\"\n", "main.jac"
    );
    assert p.kind == "web-app";
}

test "infer web-app from plain .jac when [client] is configured" {
    p = _plan("entry-point = \"main.jac\"\n\n[client]\npaths = {}\n", "main.jac");
    assert p.kind == "web-app";
}

# ---------------------------------------------------------------------------
# Entry-point resolution
# ---------------------------------------------------------------------------
test "stale entry-point resolves by stem to the real language file" {
    # entry-point says main.jac but only main.py exists on disk.
    p = _plan("entry-point = \"main.jac\"\n", "main.py", entry_body="print('ok')");
    assert p.entry_path.endswith("main.py");
}

test "missing entry is a planning error for runnable kinds" {
    d = _mk_project("kind = \"cli\"\nentry-point = \"nope.jac\"\n", "");
    cfg = JacConfig.discover(start_path=Path(d));
    assert cfg is not None;
    raised = "";
    try {
        plan_app_run(cfg, d, cfg.resolve_app(""));
    } except ValueError as e {
        raised = str(e);
    }
    assert "no entry file" in raised , raised;
    assert "nope.jac" in raised , raised;
}

# ---------------------------------------------------------------------------
# Kind resolution (resolve_app_kind)
# ---------------------------------------------------------------------------
test "resolve_app_kind: an explicit kind wins for any app" {
    d = _mk_project("kind = \"service\"\nentry-point = \"main.jac\"\n", "main.jac");
    cfg = JacConfig.discover(start_path=Path(d));
    assert cfg is not None;
    app = cfg.resolve_app("");
    assert app.implicit;
    assert resolve_app_kind(cfg, app, resolve_entry(cfg, d, app)) == "service";
    named = AppConfig(name="tool", kind="native-binary", path="tool");
    assert resolve_app_kind(cfg, named, "") == "native-binary";
}

test "resolve_app_kind: only the implicit app infers; an [apps] entry is cli" {
    d = _mk_project(
        "entry-point = \"main.jac\"\n\n[dependencies]\njac-client = \"*\"\n", "main.jac"
    );
    cfg = JacConfig.discover(start_path=Path(d));
    assert cfg is not None;
    implicit = cfg.resolve_app("");
    assert resolve_app_kind(cfg, implicit, resolve_entry(cfg, d, implicit))
        == "web-app";
    explicit = AppConfig(name="web", kind="", path="web");
    assert resolve_app_kind(cfg, explicit, "") == "cli";
}

test "plan_workspace on a plain project yields the implicit app's plan" {
    d = _mk_project("kind = \"cli\"\nentry-point = \"main.jac\"\n", "main.jac");
    cfg = JacConfig.discover(start_path=Path(d));
    assert cfg is not None;
    plans = plan_workspace(cfg, d);
    assert len(plans) == 1;
    assert plans[0].kind == "cli" and plans[0].app == "";
    assert plans[0].command_line() == "jac run main.jac";
}

# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------
test "is_valid_kind accepts known and rejects unknown kinds" {
    assert is_valid_kind("cli");
    assert is_valid_kind("service");
    assert not is_valid_kind("banana");
    assert len(VALID_KINDS) == 12;
}

test "KIND_SPECS is the single source of truth for every kind" {
    assert kind_spec("banana") is None;
    for kname in VALID_KINDS {
        spec = kind_spec(kname);
        assert spec is not None , f"no spec for {kname}";
        # The table key and the spec's own name can never drift apart.
        assert spec.name == kname;
        assert spec.action in ["execute", "build", "serve"];
        assert spec.verb in ["run", "build", "native"];
        assert spec.description;
        assert spec.`entry;
        # kind_entry() reads the table rather than a second hardcoded list.
        assert kind_entry(kname) == spec.`entry;
    }
}

test "a plan carries the spec it was planned from" {
    p = _plan("kind = \"cli\"\n", "main.jac");
    assert p.spec is KIND_SPECS["cli"];
    assert p.kind == "cli" and p.kind == p.spec.name;
    assert p.action == p.spec.action and p.verb == p.spec.verb;
}

test "planning never mutates the shared spec's flags" {
    p = _plan(
        "kind = \"service\"\nentry-point = \"api.sv.jac\"\n\n[serve]\nport = 3000\n",
        "api.sv.jac"
    );
    assert p.flags.get("port") == 3000;
    # The port landed on the plan, not on the table entry every project shares.
    assert "port" not in KIND_SPECS["service"].flags;
}

# ---------------------------------------------------------------------------
# CLI integration: --show plan + real execution of cheap kinds
# ---------------------------------------------------------------------------
test "jac run --show prints the plan without executing" {
    d = _mk_project(
        "kind = \"cli\"\n", "main.jac", "with entry { print(\"SHOULD_NOT_RUN\"); }"
    );
    old = os.getcwd();
    os.chdir(d);
    captured = io.StringIO();
    sys.stdout = captured;
    try {
        rc = execution.run(target="", show=True);
    } finally {
        sys.stdout = sys.__stdout__;
        os.chdir(old);
    }
    out = captured.getvalue();
    assert rc == 0;
    assert "kind         : cli" in out;
    assert "action       : execute" in out;
    # A plain project is its own implicit app: no app row is printed.
    assert "app          :" not in out;
    assert "SHOULD_NOT_RUN" not in out;
}

test "jac run with no file executes a cli project from cwd" {
    d = _mk_project(
        "kind = \"cli\"\n", "main.jac", "with entry { print(\"RAN_CLI_OK\"); }"
    );
    old = os.getcwd();
    os.chdir(d);
    captured = io.StringIO();
    sys.stdout = captured;
    try {
        rc = execution.run(target="");
    } finally {
        sys.stdout = sys.__stdout__;
        os.chdir(old);
    }
    out = captured.getvalue();
    assert rc == 0 , f"expected success, got rc={rc}, out={out}";
    assert "RAN_CLI_OK" in out;
}

test "jac run with no file executes a cli-native project from cwd" {
    # cli-native prints via the JIT'd binary, which writes to fd 1 directly
    # (C printf) -- so we capture at the file-descriptor level, not sys.stdout.
    d = _mk_project(
        "kind = \"cli-native\"\nentry-point = \"main.jac\"\n",
        "main.jac",
        "with entry { print(\"RAN_NA_OK\"); }"
    );
    old = os.getcwd();
    os.chdir(d);
    cap = tempfile.TemporaryFile(mode="w+");
    saved_fd = os.dup(1);
    os.dup2(cap.fileno(), 1);
    try {
        rc = execution.run(target="");
    } finally {
        sys.stdout.flush();
        os.dup2(saved_fd, 1);
        os.close(saved_fd);
        os.chdir(old);
    }
    cap.seek(0);
    out = cap.read();
    cap.close();
    assert rc == 0 , f"expected success, got rc={rc}";
    assert "RAN_NA_OK" in out , f"expected native output, got: {out}";
    _cleanup();
}

test "jac run builds a native-binary project into dist/" {
    d = _mk_project(
        "kind = \"native-binary\"\nentry-point = \"app.jac\"\n",
        "app.jac",
        "with entry { print(\"x\"); }"
    );
    old = os.getcwd();
    os.chdir(d);
    saved_fd = os.dup(1);
    devnull = os.open(os.devnull, os.O_WRONLY);
    os.dup2(devnull, 1);
    try {
        rc = execution.run(target="");
    } finally {
        sys.stdout.flush();
        os.dup2(saved_fd, 1);
        os.close(saved_fd);
        os.close(devnull);
        os.chdir(old);
    }
    artifact = os.path.join(d, "dist", "app");
    assert rc == 0 , f"expected build success, got rc={rc}";
    assert os.path.isfile(artifact) , f"expected binary at {artifact}";
    _cleanup();
}

# ---------------------------------------------------------------------------
# Unknown explicit kind is rejected by the CLI with a clear message
# ---------------------------------------------------------------------------
test "unknown explicit kind is reported by jac run" {
    d = _mk_project("kind = \"banana\"\n", "main.jac");
    old = os.getcwd();
    os.chdir(d);
    captured = io.StringIO();
    sys.stderr = captured;
    try {
        rc = execution.run(target="");
    } finally {
        sys.stderr = sys.__stderr__;
        os.chdir(old);
    }
    err = captured.getvalue();
    assert rc == 2 , f"rc={rc}, err={err}";
    assert "unknown kind" in err and "banana" in err , err;
    _cleanup();
}

# ---------------------------------------------------------------------------
# The merged `jac run`: explicit-file kind resolution and flag gating
# ---------------------------------------------------------------------------
test "an explicitly named file resolves the project kind, not a bare execute" {
    d = _mk_project(
        "kind = \"service\"\nentry-point = \"main.jac\"\n",
        "main.jac",
        entry_body="with entry { }"
    );
    cfg = JacConfig.discover(start_path=Path(d));
    assert cfg is not None;
    plan = plan_app_run(
        cfg, d, cfg.resolve_app(""), entry_override=os.path.join(d, "main.jac")
    );
    assert plan is not None;
    # `jac run main.jac` in a service project serves, exactly as bare `jac run`
    # does -- the pre-merge asymmetry (file => execute) is gone.
    assert plan.action == "serve";
    assert plan.entry_path == os.path.join(d, "main.jac");
}

test "a named file executes in a build kind; only a bare run builds" {
    d = _mk_project(
        "kind = \"mobile\"\nentry-point = \"main.jac\"\n",
        "main.jac",
        entry_body="with entry { }"
    );
    saved = os.getcwd();
    try {
        os.chdir(d);
        # A bare `jac run` builds the mobile app shell; naming the file runs it.
        # Without this split, `jac run main.jac` would shell out to gradle.
        rc = execution.run(target="main.jac", show=True);
    } finally {
        os.chdir(saved);
    }
    assert rc == 0;
    _cleanup();
}

test "entry_override keeps a named file for kinds that plan without one" {
    d = _mk_project("kind = \"py-package\"\n", "lib.jac");
    cfg = JacConfig.discover(start_path=Path(d));
    assert cfg is not None;
    app = cfg.resolve_app("");
    bare = plan_app_run(cfg, d, app);
    assert bare is not None and bare.entry_path == "";
    named = plan_app_run(cfg, d, app, entry_override=os.path.join(d, "lib.jac"));
    assert named is not None;
    assert named.entry_path == os.path.join(d, "lib.jac");
}

test "serve flags are recognised only when they were actually typed" {
    # (port, dev, api_port, no_client, faux, host, platform, fleet, cfg): the
    # old `client` slot is gone with the --client flag.
    over = execution._serve_overrides(
        None, None, None, None, None, None, None, False, None
    );
    assert over == {};
    over = execution._serve_overrides(
        None, True, None, None, None, None, None, False, None
    );
    assert over == {"dev": True};
    # --no-client is a real choice, not an absence: False must survive.
    over = execution._serve_overrides(
        None, None, None, False, None, None, None, False, None
    );
    assert over == {"no_client": False};
    # --platform is the only client-side choice that survives.
    over = execution._serve_overrides(
        None, None, None, None, None, None, "ios", False, None
    );
    assert over == {"platform": "ios"};
    # --fleet is a plain switch: only True is an override.
    over = execution._serve_overrides(
        None, None, None, None, None, None, None, True, None
    );
    assert over == {"fleet": True};
}

test "a [serve] port from jac.toml is not mistaken for a typed --port" {
    d = _mk_project(
        "kind = \"cli\"\nentry-point = \"main.jac\"\n\n[serve]\nport = 3000\n",
        "main.jac"
    );
    cfg = JacConfig.discover(start_path=Path(d));
    assert cfg is not None;
    # Bridged from config: not an override, so it must not force the serve path
    # (and must not trip the "serve flag on a non-serving kind" error).
    assert not execution._port_is_explicit(3000, cfg);
    assert execution._port_is_explicit(9999, cfg);
    # With no config at all, any port is the user's own.
    assert execution._port_is_explicit(3000, None);
    assert not execution._port_is_explicit(None, None);
}

test "entry-only flags are reported by their CLI spelling" {
    assert execution._entry_flags_used("", "", "", False) == [];
    assert execution._entry_flags_used("w", "", "", False) == ["--entry"];
    assert execution._entry_flags_used("w", "n1", "r1", True)
        == ["--entry", "--node", "--root", "--debug"];
}

test "--port on a cli-kind project is a hard error, not a silent no-op" {
    d = _mk_project("kind = \"cli\"\nentry-point = \"main.jac\"\n", "main.jac");
    saved = os.getcwd();
    try {
        os.chdir(d);
        rc = execution.run(target="main.jac", show=True, port=3000);
    } finally {
        os.chdir(saved);
    }
    assert rc == 1;
}

test "--serve overrides a non-serving kind instead of erroring" {
    d = _mk_project("kind = \"cli\"\nentry-point = \"main.jac\"\n", "main.jac");
    saved = os.getcwd();
    try {
        os.chdir(d);
        rc = execution.run(target="main.jac", show=True, serve_mode=True, port=3000);
    } finally {
        os.chdir(saved);
    }
    assert rc == 0;
}

test "--entry against a serving kind is a hard error" {
    d = _mk_project("kind = \"service\"\nentry-point = \"main.jac\"\n", "main.jac");
    saved = os.getcwd();
    try {
        os.chdir(d);
        rc = execution.run(target="main.jac", show=True, entry_name="walk");
    } finally {
        os.chdir(saved);
    }
    assert rc == 1;
}

test "--no-serve forces execution of a serving kind" {
    d = _mk_project("kind = \"service\"\nentry-point = \"main.jac\"\n", "main.jac");
    saved = os.getcwd();
    try {
        os.chdir(d);
        rc = execution.run(target="main.jac", show=True, serve_mode=False);
    } finally {
        os.chdir(saved);
    }
    assert rc == 0;
}

test "temp projects from the merged-dispatch cases are removed" {
    _cleanup();
    assert _tmp_dirs == [];
}

test "a client build kind still accepts serve flags (mobile dev server)" {
    d = _mk_project("kind = \"mobile\"\nentry-point = \"main.jac\"\n", "main.jac");
    saved = os.getcwd();
    try {
        os.chdir(d);
        # `mobile` plans as a *build*, but its client target has a dev server:
        # --dev must reach it rather than be refused as a serve-only flag.
        rc = execution.run(target="main.jac", show=True, dev=True);
    } finally {
        os.chdir(saved);
    }
    assert rc == 0;
    _cleanup();
}

test "a library build kind refuses serve flags" {
    d = _mk_project("kind = \"py-package\"\n", "lib.jac");
    saved = os.getcwd();
    try {
        os.chdir(d);
        rc = execution.run(target="lib.jac", show=True, port=3000);
    } finally {
        os.chdir(saved);
    }
    assert rc == 1;
    _cleanup();
}

test "--serve is a plain serve: the kind's dev default does not ride along" {
    d = _mk_project("kind = \"web-app\"\nentry-point = \"main.jac\"\n", "main.jac");
    cfg = JacConfig.discover(start_path=Path(d));
    assert cfg is not None;
    plan = plan_app_run(cfg, d, cfg.resolve_app(""));
    assert plan is not None and plan.flags.get("dev") == True;
    # Bare `jac run` takes the kind's default (the dev loop)...
    assert execution._kind_serve_flags(plan, True, None).get("dev") == True;
    # ...but `--serve`, the successor to `jac run --serve`, serves plainly.
    assert "dev" not in execution._kind_serve_flags(plan, True, True);
    # Kind properties other than the dev default still ride along.
    svc = _plan("kind = \"service\"\nentry-point = \"api.jac\"\n", "api.jac");
    assert execution._kind_serve_flags(svc, True, True).get("no_client") == True;
    _cleanup();
}

test "python backend overrides a native project and restores compiler context" {
    import from jaclang.compiler.frontend.codeinfo {
        get_effective_default_codespace_override
    }
    d = _mk_project("kind = \"cli-native\"\n", "main.jac");
    previous = get_effective_default_codespace_override();
    captured = io.StringIO();
    saved = sys.stdout;
    try {
        sys.stdout = captured;
        rc = execution.run(target=os.path.join(d, "main.jac"), backend="python");
    } finally {
        sys.stdout = saved;
    }
    # Native printf bypasses StringIO: this proves Python executed the entry.
    assert rc == 0;
    assert captured.getvalue().strip() == "ok";
    assert get_effective_default_codespace_override() == previous;
    _cleanup();
}

test "backend flag selects either executor and forwards program arguments" {
    import subprocess;
    d = _mk_project(
        "kind = \"cli\"\n", "main.jac", "import sys; with entry { print(sys.argv[1]); }"
    );
    for backend in ["python", "native"] {
        result = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "run",
                "--backend",
                backend,
                os.path.join(d, "main.jac"),
                "--",
                "forwarded"
            ],
            capture_output=True,
            text=True,
            timeout=300
        );
        assert result.returncode == 0 , result.stderr;
        assert result.stdout.strip() == "forwarded" , result.stdout;
    }
    _cleanup();
}

test "backend override rejects unsupported execution modes" {
    d = _mk_project("kind = \"service\"\n", "main.jac");
    source = os.path.join(d, "main.jac");
    assert execution.run(target=source, backend="invalid") == 1;
    assert execution.run(target=source, backend="python", show=True) == 1;
    assert execution.run(target=source, backend="native", debug_mode=True) == 1;
    assert execution.run(target=source, backend="python", entry_name="f") == 1;
    assert execution.run(target="bundle.jab", backend="python") == 1;
    _cleanup();
}

test "python backend restores compiler context when compilation fails" {
    import from jaclang.compiler.frontend.codeinfo {
        get_effective_default_codespace_override
    }
    d = _mk_project("kind = \"cli\"\n", "broken.jac", "with entry { print(");
    previous = get_effective_default_codespace_override();
    assert execution.run(target=os.path.join(d, "broken.jac"), backend="python") == 1;
    assert get_effective_default_codespace_override() == previous;
    _cleanup();
}
