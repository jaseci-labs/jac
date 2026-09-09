"""`jac run <file>` must not adopt a project the named file does not belong to.

A dev server for a project is a live session: its client entry, its compiled
output tree and its `.jac/` state all belong to one project root. Running an
unrelated one-off script from a cwd inside that project used to commandeer
that session -- config discovery started at the script's own directory, found
no jac.toml, and the very next bare `get_config()` silently re-discovered from
the *cwd*, handing the script the running project's plan and output tree. The
project's `_entry.js` was then rewritten to import the script, and every page
of the live site broke with a missing-export error.

Scope rule pinned here: a named file is run under the project that *owns* it
(the nearest jac.toml at or above the file). A file that owns no project runs
standalone even when the cwd sits inside one, and `--takeover` /
`--no-takeover` are the explicit overrides.
"""

import io;
import os;
import shutil;
import tempfile;
import from contextlib { redirect_stderr, redirect_stdout }
import from pathlib { Path }

import from jaclang.cli.commands { execution as execution_cmds }


"""Reset the config singleton so each run rediscovers from scratch."""
def reset_config {
    import from jaclang.project { config as config_mod }
    config_mod._config = None;
    config_mod._config_explicit = False;
    config_mod._config_by_root = {};
}


"""Write *body* to *path*, creating parent directories."""
def write(path: str, body: str) {
    os.makedirs(os.path.dirname(path), exist_ok=True);
    Path(path).write_text(body, encoding="utf-8");
}


"""Build a servable web-app project and an unrelated script outside it.

Returns (project_root, outside_script). The project is the kind whose plan
serves, which is what makes takeover destructive."""
def make_world -> tuple[str, str] {
    world = tempfile.mkdtemp(prefix="jacscope-");
    proj = os.path.join(world, "site");
    write(
        os.path.join(proj, "jac.toml"),
        '[project]\nname = "site"\nkind = "web-app"\nentry-point = "main.jac"\n'
    );
    write(
        os.path.join(proj, "main.jac"),
        'def:pub Home -> JsxPage {\n    return <div>home</div>;\n}\n'
    );
    write(os.path.join(proj, "helper.jac"), 'with entry {\n    print("inside");\n}\n');
    outside = os.path.join(world, "elsewhere", "probe.jac");
    write(outside, 'with entry {\n    print("outside");\n}\n');
    return (world, outside);
}


"""Run `jac run --show <filename>` with *cwd* as the working directory and
return everything it printed on both streams. `--show` resolves the plan and
prints it without executing, so the plan is observable without serving
anything; the scope notice is diagnostic chatter and goes to stderr, since a
run's stdout belongs to the program."""
def show_from(cwd: str, filename: str, takeover: (bool | None) = None) -> str {
    buf = io.StringIO();
    old = os.getcwd();
    os.chdir(cwd);
    reset_config();
    try {
        with redirect_stdout(buf), redirect_stderr(buf) {
            execution_cmds.run(target=filename, show=True, takeover=takeover);
        }
    } finally {
        os.chdir(old);
        reset_config();
    }
    return buf.getvalue();
}


test "a file outside the project does not inherit the project's serve plan" {
    (world, outside) = make_world();
    proj = os.path.join(world, "site");
    try {
        out = show_from(proj, outside);
    } finally {
        shutil.rmtree(world, ignore_errors=True);
    }
    # The bug: the plan came back as the *project's* web-app serve plan, so
    # running the probe would have served it as the project's client entry.
    assert "kind         : web-app" not in out , (
        "a script outside the project must not resolve to the project's "
        f"web-app plan; got:\n{out}"
    );
    assert "action       : serve" not in out , (
        f"a script outside the project must not resolve to a serve plan; got:\n{out}"
    );
    assert "execute" in out , (
        f"the outside script should resolve to a standalone execute; got:\n{out}"
    );
}


test "the standalone decision is announced, with the override named" {
    (world, outside) = make_world();
    proj = os.path.join(world, "site");
    try {
        out = show_from(proj, outside);
    } finally {
        shutil.rmtree(world, ignore_errors=True);
    }
    assert "standalone" in out , (
        f"the scope decision must be stated on stdout; got:\n{out}"
    );
    assert "--takeover" in out , (
        f"the notice must name the flag that opts back in; got:\n{out}"
    );
}


test "--takeover runs an outside file as the surrounding project" {
    (world, outside) = make_world();
    proj = os.path.join(world, "site");
    try {
        out = show_from(proj, outside, takeover=True);
    } finally {
        shutil.rmtree(world, ignore_errors=True);
    }
    assert "kind         : web-app" in out , (
        f"--takeover must adopt the surrounding project's plan; got:\n{out}"
    );
}


test "a file inside the project tree still runs as the project" {
    (world, _) = make_world();
    proj = os.path.join(world, "site");
    inside = os.path.join(proj, "helper.jac");
    try {
        out = show_from(proj, inside);
    } finally {
        shutil.rmtree(world, ignore_errors=True);
    }
    assert "kind         : web-app" in out , (
        f"a file inside the project must keep the project plan; got:\n{out}"
    );
}


test "--no-takeover runs an inside file standalone" {
    (world, _) = make_world();
    proj = os.path.join(world, "site");
    inside = os.path.join(proj, "helper.jac");
    try {
        out = show_from(proj, inside, takeover=False);
    } finally {
        shutil.rmtree(world, ignore_errors=True);
    }
    assert "action       : serve" not in out , (
        f"--no-takeover must decline the project's serve plan; got:\n{out}"
    );
    assert "standalone" in out , (
        f"--no-takeover must state that it is running standalone; got:\n{out}"
    );
}


test "an in-tree file that is not the entry announces the takeover" {
    # The destructive case: `jac run scoring_service.jac` inside a serving
    # project with the dev server up rewrites _entry.js. It ran silently.
    (world, _) = make_world();
    proj = os.path.join(world, "site");
    inside = os.path.join(proj, "helper.jac");
    try {
        out = show_from(proj, inside);
    } finally {
        shutil.rmtree(world, ignore_errors=True);
    }
    assert "takeover" in out , (
        f"taking over a serving project's build must say so; got:\n{out}"
    );
    assert "--no-takeover" in out , (
        f"the notice must name the flag that opts out; got:\n{out}"
    );
}


test "the project's own entry-point runs without a notice" {
    (world, _) = make_world();
    proj = os.path.join(world, "site");
    entry_file = os.path.join(proj, "main.jac");
    try {
        out = show_from(proj, entry_file);
    } finally {
        shutil.rmtree(world, ignore_errors=True);
    }
    assert "takeover" not in out , (
        f"serving a project's own entry is the plain case; got:\n{out}"
    );
}


test "explicit --takeover on an owned file still reports what it did" {
    (world, _) = make_world();
    proj = os.path.join(world, "site");
    entry_file = os.path.join(proj, "main.jac");
    try {
        out = show_from(proj, entry_file, takeover=True);
    } finally {
        shutil.rmtree(world, ignore_errors=True);
    }
    assert "takeover" in out , (
        f"an explicit --takeover must always report; got:\n{out}"
    );
}


test "an in-tree file keeps its project when the shell is somewhere else" {
    # Ownership is the file's, not the shell's: running the project's file
    # from outside the tree must still resolve to that project.
    (world, _) = make_world();
    proj = os.path.join(world, "site");
    entry_file = os.path.join(proj, "main.jac");
    outside_cwd = os.path.join(world, "elsewhere");
    try {
        out = show_from(outside_cwd, entry_file);
    } finally {
        shutil.rmtree(world, ignore_errors=True);
    }
    assert "kind         : web-app" in out , (
        f"a file's own project follows it wherever the shell is; got:\n{out}"
    );
}
