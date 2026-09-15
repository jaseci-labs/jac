"""The host client build runs on the same staged, filtered copy that defines
the .jab's membership (issue #8104): what .jacignore parks and what the deploy
strips (.env, raw jac.toml, key material) is invisible to the build, so host
build inputs equal pod inputs by construction. A build that references a file
outside membership fails loud on the host, naming the file and the exclusion.

These drive the real ManifestBuilder; the recording builds use the codebase's
own JAC_EXECUTABLE substitution seam, not a mock."""

import io;
import os;
import shutil;
import subprocess;
import tempfile;
import time;
import from contextlib { redirect_stderr, redirect_stdout }
import from pathlib { Path }
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    _CLIENT_BUILD_ATTEMPTS,
    _CLIENT_BUILD_RETRY_PAUSE_S,
    _is_transient_client_build_failure,
    _membership_diagnosis,
    ManifestBuilder
}
import from jaclang.scale.injector.bundle { bundle_source_files, source_filter_for }
import from jaclang.scale.runtime.context.util { jac_executable }

glob _PARKED: str = "# parked for the deploy\ndocsite/\nevaluation/\n",
     _SECRET: str = "sk-live-8104";


def _builder(
    project_dir: str, client_entry: (str | None) = "main.jac"
) -> ManifestBuilder {
    mb = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="shop", namespace="jb-shop"),
        client_entry=client_entry
    );
    mb.project_dir = project_dir;
    return mb;
}


"""The issue-8044 tree shape, with the pieces the raw-tree build used to see:
a .env, a [scale.secrets] table, and two trees .jacignore parks."""
def _app(jacignore: (str | None) = None) -> str {
    d = tempfile.mkdtemp(prefix="client-stage-");
    files = {
        "jac.toml": (
            '[project]\nname = "shop"\nentry-point = "main"\n\n'
            '[scale.secrets]\nAPI_KEY = "sk-live-8104"\n'
        ),
        "main.jac": (
            "def:pub app() -> JsxElement {\n"
            "    return <div>shop</div>;\n"
            "}\n\n"
            "with entry {}\n"
        ),
        "svc.jac": "def:pub ping -> str { return \"pong\"; }\n",
        ".env": f"VITE_API_KEY={_SECRET}\n"
    };
    for (name, source) in files.items() {
        with open(os.path.join(d, name), "w", encoding="utf-8") as f {
            f.write(source);
        }
    }
    os.mkdir(os.path.join(d, "docsite"));
    with open(os.path.join(d, "docsite", "util.jac"), "w", encoding="utf-8") as f {
        f.write("def helper -> str { return \"x\"; }\n");
    }
    os.mkdir(os.path.join(d, "evaluation"));
    with open(
        os.path.join(d, "evaluation", "broken.jac"), "w", encoding="utf-8"
    ) as f {
        f.write("this is not valid jac\n");
    }
    if jacignore is not None {
        with open(os.path.join(d, ".jacignore"), "w", encoding="utf-8") as f {
            f.write(jacignore);
        }
    }
    return d;
}


"""A jac stand-in that records the build's working tree instead of building:
on `build` it writes the cwd, the sorted file listing, and the jac.toml it
sees into `record_dir`, then fabricates a dist. Every other subcommand (the
dependency install) exits clean without touching the network."""
def _recording_jac(tmp: str, record_dir: str, build_exit: int = 0) -> str {
    script = os.path.join(tmp, "recording-jac.sh");
    with open(script, "w", encoding="utf-8") as f {
        f.write(
            "#!/bin/sh\n"
                + 'if [ "$1" != "build" ]; then exit 0; fi\n'
                + f'pwd > "{record_dir}/cwd"\n'
                + "find . -type f | sed 's|^\\./||' | sort > "
                + f'"{record_dir}/files"\n'
                + f'cp jac.toml "{record_dir}/jac.toml" 2>/dev/null || true\n'
                + f'if [ "{build_exit}" != "0" ]; then\n'
                + '  echo "cannot import docsite/util.jac: no such module" >&2\n'
                + f"  exit {build_exit}\n"
                + "fi\n"
                + "mkdir -p .jac/client/dist\n"
                + 'echo "<html></html>" > .jac/client/dist/index.html\n'
                + "exit 0\n"
        );
    }
    os.chmod(script, 0o755);
    return script;
}


"""Runs the builder with stderr captured, so the deploy's own warnings can be
asserted on; they land in `stderr` under `record_dir`."""
def _run_build(
    builder: ManifestBuilder, project_dir: str, record_dir: str
) -> (Exception | None) {
    raised = None;
    err = io.StringIO();
    try {
        with redirect_stderr(err) {
            builder._build_client_bundle(project_dir);
        }
    } except Exception as e {
        raised = e;
    }
    with open(os.path.join(record_dir, "stderr"), "w", encoding="utf-8") as f {
        f.write(err.getvalue());
    }
    return raised;
}


def _with_recording_build(
    project_dir: str, build_exit: int = 0
) -> tuple[(Exception | None), str] {
    tmp = tempfile.mkdtemp(prefix="client-stage-rec-");
    script = _recording_jac(tmp, tmp, build_exit);
    saved = os.environ.get("JAC_EXECUTABLE");
    os.environ["JAC_EXECUTABLE"] = script;
    try {
        raised = _run_build(_builder(project_dir), project_dir, tmp);
    } finally {
        if saved is None {
            os.environ.pop("JAC_EXECUTABLE", None);
        } else {
            os.environ["JAC_EXECUTABLE"] = saved;
        }
    }
    return (raised, tmp);
}


def _read(path: str) -> str {
    with open(path, encoding="utf-8") as f {
        return f.read();
    }
}


"""The raw-tree control build, retried on the same transient install/network
markers the deploy retries on, so a flaky bun install cannot fail the VITE_
leg for a reason unrelated to what it asserts."""
def _control_build(cwd: str) -> any {
    attempt = 0;
    while True {
        attempt += 1;
        result = subprocess.run(
            [jac_executable(), "build", "--as", "client", "main.jac"],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=900
        );
        output = (result.stdout or "") + "\n" + (result.stderr or "");
        if (
            result.returncode == 0
            or attempt >= _CLIENT_BUILD_ATTEMPTS
            or not _is_transient_client_build_failure(output)
        ) {
            return result;
        }
        time.sleep(_CLIENT_BUILD_RETRY_PAUSE_S);
    }
}


"""Every built dist under .jac/client: the deploy ships to .jac/client/dist,
while a raw `jac build` writes the app's own .jac/client/<app>/dist."""
def _dist_mentions(project_dir: str, needle: str) -> list[str] {
    client = Path(project_dir) / ".jac" / "client";
    dists = [client / "dist"]
        + [
            child / "dist"
            for child in sorted(client.iterdir())
            if child.is_dir() and child.name != "node_modules"
        ]
        if client.is_dir()
        else [];
    return [
        p.relative_to(client).as_posix()
        for dist in dists
        if dist.is_dir()
        for p in sorted(dist.rglob("*"))
        if p.is_file() and needle in p.read_bytes().decode("utf-8", errors="ignore")
    ];
}


test "the client build's inputs are the bundle's membership, nothing more" {
    project_dir = _app(_PARKED);
    base = Path(project_dir);
    expected: set[str] = {
        p.relative_to(base).as_posix() for p in bundle_source_files(base)
    };
    expected |= {"jac.toml", "__init__.jac"};
    (raised, rec) = _with_recording_build(project_dir);
    try {
        assert raised is None , f"the staged build must succeed: {raised}";
        with open(os.path.join(rec, "files"), encoding="utf-8") as f {
            staged: set[str] = set(f.read().splitlines());
        }
        assert staged == expected , (
            f"the build saw a different tree than the bundle ships:\n"
            f"extra: {sorted(staged - expected)}\n"
            f"missing: {sorted(expected - staged)}"
        );
        assert ".env" not in staged , staged;
        assert not any([n.startswith("docsite/") for n in staged]) , staged;
        assert not any([n.startswith("evaluation/") for n in staged]) , staged;
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
        shutil.rmtree(rec, ignore_errors=True);
    }
}


test "the build reads the sanitized jac.toml, not the raw one" {
    project_dir = _app(_PARKED);
    (raised, rec) = _with_recording_build(project_dir);
    try {
        assert raised is None , f"the staged build must succeed: {raised}";
        with open(os.path.join(rec, "jac.toml"), encoding="utf-8") as f {
            staged_toml = f.read();
        }
        assert "[project]" in staged_toml , staged_toml;
        assert "scale.secrets" not in staged_toml , staged_toml;
        assert "sk-live-8104" not in staged_toml , staged_toml;
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
        shutil.rmtree(rec, ignore_errors=True);
    }
}


test "the build runs in an ephemeral stage and the dist is copied back" {
    project_dir = _app(_PARKED);
    client_dir = os.path.join(project_dir, ".jac", "client");
    os.makedirs(os.path.join(client_dir, "dist"));
    with open(
        os.path.join(client_dir, "dist", "stale.js"), "w", encoding="utf-8"
    ) as f {
        f.write("from the last deploy");
    }
    (raised, rec) = _with_recording_build(project_dir);
    try {
        assert raised is None , f"the staged build must succeed: {raised}";
        with open(os.path.join(rec, "cwd"), encoding="utf-8") as f {
            build_cwd = f.read().strip();
        }
        assert Path(build_cwd).resolve() != Path(project_dir).resolve() , (
            "the build still ran on the raw project tree"
        );
        assert not os.path.isdir(build_cwd) , (
            "the deploy left its staging directory behind"
        );
        index_html = os.path.join(project_dir, ".jac", "client", "dist", "index.html");
        assert os.path.isfile(index_html) , (
            "the built dist never made it back to where the bundle pack "
            "ships it from"
        );
        assert not os.path.exists(os.path.join(client_dir, "dist", "stale.js")) , (
            "last deploy's dist survived under the new one"
        );
        assert os.listdir(client_dir) == ["dist"] , os.listdir(client_dir);
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
        shutil.rmtree(rec, ignore_errors=True);
    }
}


test "a client entry parked by .jacignore fails the deploy, naming the pattern" {
    project_dir = _app(_PARKED + "main.jac\n");
    raised = None;
    try {
        _builder(project_dir)._build_client_bundle(project_dir);
    } except ValueError as e {
        raised = e;
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    assert raised is not None , (
        "a parked client entry must fail the deploy loud, not silently skip "
        "the build"
    );
    message = str(raised);
    assert "main.jac" in message , message;
    assert ".jacignore" in message , message;
    assert "'main.jac'" in message , (
        f"the error must name the matching pattern: {message}"
    );
}


test "a build that references a parked file names it and the pattern" {
    project_dir = _app(_PARKED);
    (raised, rec) = _with_recording_build(project_dir, build_exit=1);
    try {
        assert raised is not None , "a broken client build must fail the deploy";
        message = str(raised);
        assert "client build failed" in message , message;
        assert "docsite/util.jac" in message , message;
        assert "'docsite'" in message , (
            f"the error must name the matching .jacignore pattern: {message}"
        );
        assert "never ship" in message , message;
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
        shutil.rmtree(rec, ignore_errors=True);
    }
}


test "the same reference fails silently nowhere: unparked, it just builds" {
    project_dir = _app(None);
    (raised, rec) = _with_recording_build(project_dir);
    try {
        assert raised is None , f"an unparked tree must build: {raised}";
        with open(os.path.join(rec, "files"), encoding="utf-8") as f {
            staged: set[str] = set(f.read().splitlines());
        }
        assert "docsite/util.jac" in staged , staged;
        assert ".env" not in staged , (".env never ships, .jacignore or not");
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
        shutil.rmtree(rec, ignore_errors=True);
    }
}


test "a .env with VITE_ keys is called out before the build, naming the keys" {
    project_dir = _app(_PARKED);
    (raised, rec) = _with_recording_build(project_dir);
    try {
        assert raised is None , f"the staged build must succeed: {raised}";
        err = _read(os.path.join(rec, "stderr"));
        assert "'.env'" in err , (
            f"the deploy must say which env file it is ignoring: {err}"
        );
        assert "VITE_API_KEY" in err , (
            f"the deploy must name the keys that compile to undefined: {err}"
        );
        assert "[client.vite.define]" in err , (
            f"the warning must point at where build-time values belong: {err}"
        );
        assert _SECRET not in err , "the warning names keys, never values";
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
        shutil.rmtree(rec, ignore_errors=True);
    }
}


test "a tree without VITE_ env values gets no env warning" {
    project_dir = _app(_PARKED);
    with open(os.path.join(project_dir, ".env"), "w", encoding="utf-8") as f {
        f.write("# server-side only\nOPENAI_API_KEY=sk-server\nexport DB_URL=x\n");
    }
    (raised, rec) = _with_recording_build(project_dir);
    try {
        assert raised is None , f"the staged build must succeed: {raised}";
        err = _read(os.path.join(rec, "stderr"));
        assert "compile to undefined" not in err , (
            f"non-VITE_ values never reached the client, so no warning: {err}"
        );
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
        shutil.rmtree(rec, ignore_errors=True);
    }
}


"""The motivating case, end to end with the real toolchain: a client that reads
`import.meta.env.VITE_API_KEY` used to get the .env value inlined into the
served JS. The control build on the raw tree shows Vite still does that; the
deploy build, on the staged sources, ships a dist that never contains it."""
test "a VITE_ value in .env never reaches the shipped dist" {
    project_dir = _app(_PARKED);
    with open(os.path.join(project_dir, "main.jac"), "w", encoding="utf-8") as f {
        f.write(
            "def:pub app() -> JsxElement {\n"
            "    return <div>{`import.meta.env.VITE_API_KEY or \"unset\"}</div>;\n"
            "}\n\n"
            "with entry {}\n"
        );
    }
    control = tempfile.mkdtemp(prefix="client-stage-control-");
    shutil.copytree(project_dir, control, dirs_exist_ok=True);
    rec = tempfile.mkdtemp(prefix="client-stage-rec-");
    try {
        raw = _control_build(control);
        assert raw.returncode == 0 , (
            f"the raw-tree control build failed:\n{raw.stdout}\n{raw.stderr}"
        );
        assert _dist_mentions(control, _SECRET) , (
            "control: a raw-tree build inlines the .env value, so the "
            "deploy assertion below is not vacuous"
        );

        raised = _run_build(_builder(project_dir), project_dir, rec);
        assert raised is None , f"the staged deploy build must succeed: {raised}";
        leaked = _dist_mentions(project_dir, _SECRET);
        assert not leaked , (
            f"the .env value reached the shipped client dist via: {leaked}"
        );
        assert "VITE_API_KEY" in _read(os.path.join(rec, "stderr")) , (
            "the deploy must warn that the key compiles to undefined"
        );
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
        shutil.rmtree(control, ignore_errors=True);
        shutil.rmtree(rec, ignore_errors=True);
    }
}


test "a declared client entry that does not exist fails the deploy, not silently" {
    project_dir = _app(_PARKED);
    raised = None;
    try {
        _builder(project_dir, client_entry="man.jac")._build_client_bundle(project_dir);
    } except ValueError as e {
        raised = e;
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    assert raised is not None , (
        "a client entry that does not exist must fail the deploy, "
        "not ship a served app with nothing to serve"
    );
    message = str(raised);
    assert "man.jac" in message , message;
    assert "client_entry" in message , message;
    assert "client_entry = \"\"" in message , (
        f"the error must say how to deploy without a client: {message}"
    );
}


test "an undeclared entry that does not exist skips the build and says so" {
    project_dir = _app(_PARKED);
    os.remove(os.path.join(project_dir, "main.jac"));
    mb = _builder(project_dir, client_entry=None);
    assert mb._declared_client_entry() == "" , "nothing was declared";
    assert mb._client_entry() , "the default entry still resolves";
    out = io.StringIO();
    raised = None;
    try {
        with redirect_stdout(out) {
            mb._build_client_bundle(project_dir);
        }
    } except Exception as e {
        raised = e;
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    assert raised is None , (
        f"a guessed default that is absent is not the user's error: {raised}"
    );
    assert "skipping the client build" in out.getvalue() , (
        f"the skip must be said out loud: {out.getvalue()!r}"
    );
    assert "client target" in out.getvalue() , out.getvalue();
}


test "client_entry = \"\" is not a declared entry" {
    project_dir = _app(_PARKED);
    try {
        assert _builder(project_dir, client_entry="")._declared_client_entry() == "";
        assert _builder(project_dir, client_entry=" app.jac ")._declared_client_entry()
            == "app.jac";
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }
}


test "client_entry = \"\" with no client source skips the build and says so" {
    project_dir = _app(_PARKED);
    out = io.StringIO();
    try {
        with redirect_stdout(out) {
            _builder(project_dir, client_entry="")._build_client_bundle(project_dir);
        }
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }
    assert "skipping the client build" in out.getvalue() , (
        f"a deploy with no client must say it is skipping the build: "
        f"{out.getvalue()!r}"
    );
    assert 'client_entry = ""' in out.getvalue() , (
        f"the skip must name the explicit opt-out: {out.getvalue()!r}"
    );
}


test "client_entry = \"\" with client source still skips the build" {
    project_dir = _app(_PARKED);
    os.mkdir(os.path.join(project_dir, "pages"));
    mb = _builder(project_dir, client_entry="");
    out = io.StringIO();
    try {
        assert mb._client_entry() == "" , (
            "an explicit client_entry = \"\" must win over the client-source guess"
        );
        with redirect_stdout(out) {
            mb._build_client_bundle(project_dir);
        }
        built = os.path.isdir(os.path.join(project_dir, ".jac"));
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }
    assert not built , "the skip must happen before anything is built";
    assert 'client_entry = ""' in out.getvalue() , (
        f"the skip must name the explicit opt-out: {out.getvalue()!r}"
    );
    assert "skipping the client build" in out.getvalue() , (
        f"the skip must be said out loud: {out.getvalue()!r}"
    );
}


test "a jac.toml the loader rejects fails the deploy instead of skipping the client" {
    project_dir = _app(_PARKED);
    with open(os.path.join(project_dir, "jac.toml"), "w", encoding="utf-8") as f {
        f.write("[project\nname = \"shop\"\n");
    }
    mb = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="shop", namespace="jb-shop")
    );
    mb.project_dir = project_dir;
    reset_scale_config();
    get_scale_config(project_dir=Path(project_dir));
    out = io.StringIO();
    raised = None;
    try {
        with redirect_stdout(out) {
            mb._build_client_bundle(project_dir);
        }
    } except Exception as e {
        raised = e;
    } finally {
        reset_scale_config();
        shutil.rmtree(project_dir, ignore_errors=True);
    }
    assert raised is not None , (
        f"a jac.toml the loader cannot read must fail the deploy, not skip the "
        f"client build and ship a gateway with nothing to serve: {out.getvalue()!r}"
    );
    assert "skipping the client build" not in out.getvalue() , out.getvalue();
}


test "the membership diagnosis never blames a build or cache tree" {
    project_dir = _app(_PARKED);
    base = Path(project_dir);
    vite = base / ".jac" / "client" / "node_modules" / "vite" / "dist";
    vite.mkdir(parents=True);
    (vite / "cli.js").write_text("", encoding="utf-8");
    try {
        filt = source_filter_for(base);
        output = (
            "error during build:\n"
            "    at .jac/client/node_modules/vite/dist/cli.js:1:1\n"
            "cannot import docsite/util.jac: no such module\n"
        );
        diagnosis = _membership_diagnosis(output, base, filt);
        assert "docsite/util.jac" in diagnosis , diagnosis;
        assert "node_modules" not in diagnosis , (
            f"the diagnosis told the user to drop a tooling-tree exclusion: "
            f"{diagnosis}"
        );
        only_tooling = _membership_diagnosis(
            "error at .jac/client/node_modules/vite/dist/cli.js:1:1", base, filt
        );
        assert only_tooling == "" , only_tooling;
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }
}


test "a build referencing more parked files than fit says how many are left" {
    project_dir = _app(_PARKED);
    base = Path(project_dir);
    for n in range(6) {
        (base / "docsite" / f"m{n}.jac").write_text(
            f"def h{n} -> str {{ return \"x\"; }}\n", encoding="utf-8"
        );
    }
    try {
        filt = source_filter_for(base);
        output = "\n".join(
            [f"cannot import docsite/m{n}.jac: no such module" for n in range(6)]
        );
        diagnosis = _membership_diagnosis(output, base, filt);
        named = [
            n
            for n in range(6)
            if f"docsite/m{n}.jac" in diagnosis
        ];
        assert len(named) == 3 , (
            f"the diagnosis should name three files, named {named}: {diagnosis}"
        );
        assert "... and 3 more" in diagnosis , (
            f"an operator who fixes only the named files redeploys into the "
            f"same error; the diagnosis must say how many it withheld: "
            f"{diagnosis}"
        );
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }
}


test "a diagnosis that fits says nothing about a remainder" {
    project_dir = _app(_PARKED);
    base = Path(project_dir);
    try {
        filt = source_filter_for(base);
        diagnosis = _membership_diagnosis(
            "cannot import docsite/util.jac: no such module", base, filt
        );
        assert "docsite/util.jac" in diagnosis , diagnosis;
        assert "more" not in diagnosis , (
            f"nothing was withheld, so nothing should be claimed: {diagnosis}"
        );
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }
}


test "workspace served web app declares its client even without root client hints" {
    import from jaclang.scale.runtime.fleet { FleetMember, FleetSpec }
    project_dir = _app();
    try {
        Path(project_dir, "jac.toml").write_text(
            '[project]\nname = "shop"\ndefault-app = "svc"\n'
            '[apps.web]\nkind = "web-app"\nentry-point = "main"\n'
            '[apps.svc]\nkind = "service"\nentry-point = "svc"\n'
        );
        mb = _builder(project_dir, client_entry=None);
        mb.fleet = FleetSpec();
        mb.fleet.add(
            FleetMember(app="web", file="main.jac", is_root=True, client=True)
        );
        assert mb._declared_client_entry() == "main.jac";
        assert mb._client_entry() == "main.jac";
        mb.dry_run = True;
        out = io.StringIO();
        with redirect_stdout(out) {
            mb._build_client_bundle(project_dir);
        }
        assert "dry-run: skipped the host client bundle build (main.jac)"
            in out.getvalue();
        with tempfile.TemporaryDirectory() as record_dir {
            import from unittest.mock { patch }
            script = _recording_jac(record_dir, record_dir);
            script_path = Path(script);
            script_path.write_text(
                script_path.read_text().replace(
                    ".jac/client/dist", ".jac/client/web/dist"
                )
            );
            mb.dry_run = False;
            with patch.dict(os.environ, {"JAC_EXECUTABLE": script}) {
                raised = _run_build(mb, project_dir, record_dir);
            }
            assert raised is None , str(raised);
            assert Path(project_dir, ".jac", "client", "dist", "index.html").is_file();
            assert Path(record_dir, "cwd").is_file();
        }
        mb.fleet = FleetSpec();
        mb.fleet.add(FleetMember(app="svc", file="svc.jac", is_root=True));
        assert mb._client_entry() == "";
        mb.client_entry = "";
        assert mb._client_entry() == "";
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }
}

test "implicit deployment resolves a dotted client entry to a source path" {
    with tempfile.TemporaryDirectory() as directory {
        base = Path(directory);
        (base / 'web').mkdir();
        (base / 'web' / 'main.jac').write_text('with entry {}\n');
        (base / 'jac.toml').write_text(
            '[project]\nname="nested"\nkind="web-app"\nentry-point="web.main"\n'
        );
        builder = _builder(directory, client_entry=None);
        assert builder._client_entry() == os.path.join('web', 'main.jac');
    }
}
