"""Tests for project-kind-aware `jac run` dispatch.

`jac run` with no explicit file resolves the project kind from jac.toml (or
infers it from the entry-point codespace) and dispatches to execute / serve /
build. These tests cover the planner (`plan_project_run`) for every project
kind, kind inference, entry-point resolution, error paths, and real execution
of the two cheap runnable kinds (cli, cli-native)."""

import io;
import os;
import sys;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.commands { execution }
import from jaclang.project.config { JacConfig, set_config }
import from jaclang.project.kinds {
    plan_project_run,
    resolve_project_kind,
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

"""Build the RunPlan for a freshly-created project."""
def _plan(
    toml_extra: str,
    entry_name: str = "",
    entry_body: str = "with entry { print(\"ok\"); }"
) -> RunPlan {
    d = _mk_project(toml_extra, entry_name, entry_body);
    cfg = JacConfig.discover(start_path=Path(d));
    assert cfg is not None , "expected a discovered config";
    plan = plan_project_run(cfg, d);
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
    p = _plan("kind = \"cli-native\"\nentry-point = \"main.na.jac\"\n", "main.na.jac");
    assert p.kind == "cli-native";
    assert p.action == "execute";
    assert p.verb == "run";
}

test "kind native-binary -> build via nacompile" {
    p = _plan(
        "kind = \"native-binary\"\nentry-point = \"main.na.jac\"\n", "main.na.jac"
    );
    assert p.action == "build";
    assert p.verb == "nacompile";
    assert "output" in p.flags;
    assert "nacompile" in p.command_line();
}

test "kind native-lib -> build shared via nacompile" {
    p = _plan("kind = \"native-lib\"\nentry-point = \"lib.na.jac\"\n", "lib.na.jac");
    assert p.action == "build";
    assert p.verb == "nacompile";
    assert p.flags.get("shared") == True;
    assert "--shared" in p.command_line();
}

test "kind service -> serve headless" {
    p = _plan("kind = \"service\"\nentry-point = \"api.sv.jac\"\n", "api.sv.jac");
    assert p.action == "serve";
    assert p.verb == "start";
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
    assert p.verb == "start";
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
    p = _plan("kind = \"web-app\"\nentry-point = \"app.cl.jac\"\n", "app.cl.jac");
    assert p.action == "serve";
    assert p.verb == "start";
    assert p.flags.get("dev") == True;
    # A web-app serves the default web client, so it carries no --client flag.
    assert "client" not in p.flags;
}

test "kind web-static -> serve (client framework is core)" {
    p = _plan("kind = \"web-static\"\nentry-point = \"page.cl.jac\"\n", "page.cl.jac");
    assert p.action == "serve";
    assert p.verb == "start";
    assert "client" not in p.flags;
}

test "kind desktop -> serve the desktop client target (core)" {
    p = _plan("kind = \"desktop\"\nentry-point = \"app.cl.jac\"\n", "app.cl.jac");
    assert p.action == "serve";
    assert p.verb == "start";
    # The desktop target is a core client target -- it must reach `start`,
    # not be turned away as a missing plugin.
    assert p.flags.get("client") == "desktop";
    assert "--client desktop" in p.command_line();
}

test "kind mobile -> build the mobile client shell (core)" {
    p = _plan("kind = \"mobile\"\nentry-point = \"app.cl.jac\"\n", "app.cl.jac");
    assert p.action == "build";
    assert p.verb == "build";
    # Must build the mobile shell, not fall through to a default .jab build.
    assert p.flags.get("client") == "mobile";
    assert "as" not in p.flags;
    assert "--client mobile" in p.command_line();
}

# ---------------------------------------------------------------------------
# Kind inference (no explicit [project] kind)
# ---------------------------------------------------------------------------
test "infer cli-native from .na.jac entry" {
    p = _plan("entry-point = \"main.na.jac\"\n", "main.na.jac");
    assert p.kind == "cli-native";
}

test "infer service from .sv.jac entry" {
    p = _plan("entry-point = \"main.sv.jac\"\n", "main.sv.jac");
    assert p.kind == "service";
}

test "infer web-app from .cl.jac entry" {
    p = _plan("entry-point = \"main.cl.jac\"\n", "main.cl.jac");
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
test "stale entry-point resolves by stem to the real codespace file" {
    # entry-point says main.jac but only main.na.jac exists on disk.
    p = _plan("entry-point = \"main.jac\"\n", "main.na.jac");
    assert p.entry_path.endswith("main.na.jac");
    assert p.kind == "cli-native";
}

test "missing entry yields no plan for runnable kinds" {
    d = _mk_project("kind = \"cli\"\nentry-point = \"nope.jac\"\n", "");
    cfg = JacConfig.discover(start_path=Path(d));
    assert plan_project_run(cfg, d) is None;
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
        assert spec.verb in ["run", "start", "nacompile", "build"];
        assert spec.description;
        assert spec.entry;
        # kind_entry() reads the table rather than a second hardcoded list.
        assert kind_entry(kname) == spec.entry;
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
        rc = execution.run(filename="", show=True);
    } finally {
        sys.stdout = sys.__stdout__;
        os.chdir(old);
    }
    out = captured.getvalue();
    assert rc == 0;
    assert "project kind : cli" in out;
    assert "action       : execute" in out;
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
        rc = execution.run(filename="");
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
        "kind = \"cli-native\"\nentry-point = \"main.na.jac\"\n",
        "main.na.jac",
        "with entry { print(\"RAN_NA_OK\"); }"
    );
    old = os.getcwd();
    os.chdir(d);
    cap = tempfile.TemporaryFile(mode="w+");
    saved_fd = os.dup(1);
    os.dup2(cap.fileno(), 1);
    try {
        rc = execution.run(filename="");
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
        "kind = \"native-binary\"\nentry-point = \"app.na.jac\"\n",
        "app.na.jac",
        "with entry { print(\"x\"); }"
    );
    old = os.getcwd();
    os.chdir(d);
    saved_fd = os.dup(1);
    devnull = os.open(os.devnull, os.O_WRONLY);
    os.dup2(devnull, 1);
    try {
        rc = execution.run(filename="");
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
        rc = execution.run(filename="");
    } finally {
        sys.stderr = sys.__stderr__;
        os.chdir(old);
    }
    err = captured.getvalue();
    assert rc == 1;
    assert "Unknown" in err and "banana" in err;
    _cleanup();
}
