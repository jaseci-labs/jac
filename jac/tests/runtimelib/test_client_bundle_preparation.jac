"""Production client builds finish before initialization and can recover on retry."""

import os;
import socket;
import subprocess;
import time;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

test "a failed production client build prevents initialization and a corrected run succeeds" {
    import from jaclang.testing.requires { require_tool }
    import from jaclang.scale.runtime.context.util { jac_executable }
    import from urllib.request { urlopen }
    require_tool('bun');
    with TemporaryDirectory(prefix='jac-bundle-preparation-') as tmp {
        project = Path(tmp);
        (project / 'jac.toml').write_text(
            '[project]\nname="bundleretry"\nkind="web-app"\nentry-point="main"\n'
        );
        source = project / 'main.jac';
        source.write_text(
            'import from pathlib { Path }\n'
                + 'with entry { Path("initialized").write_text("yes"); }\n'
                + 'import from "totally-not-a-real-package-7998" { boom }\n'
                + 'def:pub app -> JsxElement { return <div>{boom()}</div>; }\n'
        );
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock {
            sock.bind(('127.0.0.1', 0));
            port = sock.getsockname()[1];
        }
        command = [jac_executable(), 'run', '--no-dev', '--port', str(port)];
        failed = subprocess.run(
            command, cwd=tmp, capture_output=True, text=True, timeout=300
        );
        assert failed.returncode != 0;
        assert 'Preparing application' in failed.stdout;
        assert not (project / 'initialized').exists();
        assert 'Initializing application' not in failed.stdout;
        assert 'totally-not-a-real-package-7998' in failed.stdout + failed.stderr;
        source.write_text(
            'import from pathlib { Path }\n'
                + 'with entry { Path("initialized").write_text("yes"); }\n'
                + 'def:pub app -> JsxElement { return <div>recovered</div>; }\n'
        );
        log = project / 'server.log';
        with log.open('w') as output {
            server = subprocess.Popen(
                command, cwd=tmp, stdout=output, stderr=subprocess.STDOUT
            );
        }
        try {
            ready = False;
            deadline = time.monotonic() + 300;
            while time.monotonic() < deadline {
                assert server.poll() is None , log.read_text(errors='replace');
                try {
                    with urlopen(f'http://127.0.0.1:{port}/', timeout=2) as response {
                        ready = response.status == 200;
                    }
                    if ready {
                        break;
                    }
                } except OSError {
                    time.sleep(0.5);
                }
            }
            assert ready , log.read_text(errors='replace');
            assert (project / 'initialized').read_text() == 'yes';
        } finally {
            server.terminate();
            try {
                server.`wait(timeout=15);
            } except subprocess.TimeoutExpired {
                server.kill();
                server.`wait();
            }
        }
    }
}


"""Prepare the web app at `path` and report whether it restored the recorded application."""
def _restored(path: Path, `root: str) -> bool {
    import contextlib;
    import io;
    import from jaclang.compiler.driver.application { prepare_application }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.runtime.prepared { forget }
    err = io.StringIO();
    try {
        with contextlib.redirect_stderr(err) {
            prepare_application(str(path), JacProgram(), `root, client=True);
        }
    } finally {
        forget(str(path));
    }
    return 'Restoring prepared application' in err.getvalue();
}


test "files a web app writes at runtime do not invalidate its prepared record" {
    import from jaclang.testing.requires { require_tool }
    require_tool('bun');
    with TemporaryDirectory(prefix='jac-prepared-data-') as tmp {
        base = Path(tmp);
        path = base / 'main.jac';
        path.write_text(
            'import from "@jac/runtime" { renderJsxTree, }\n\n'
            'def:pub app(children: any) -> JsxElement {\n    <div class="root">{children}</div>\n}\n'
        );
        asset = base / 'assets' / 'brand.css';
        asset.parent.mkdir();
        asset.write_text('.root { color: red; }');
        assert not _restored(path, tmp);
        data = base / 'storage' / 'orgs' / 'state.json';
        data.parent.mkdir(parents=True);
        data.write_text('{"n": 1}');
        assert _restored(path, tmp) , (
            "a data file the app wrote at runtime discarded the prepared application"
        );
        data.write_text('{"n": 2}');
        (base / 'server.log').write_text('serving\n');
        assert _restored(path, tmp) , "a server log at the project root re-prepared";
        asset.write_text('.root { color: blue; }');
        assert not _restored(path, tmp) , "a change to a client asset must still re-prepare";
        assert _restored(path, tmp);
        page = base / 'pages' / 'about.jac';
        page.parent.mkdir();
        page.write_text('def:pub page -> JsxPage {\n    return <div>about</div>;\n}\n');
        assert not _restored(path, tmp) , "a new page must re-prepare";
        import os;
        import from jaclang.compiler.driver.application { prepare_application }
        import from jaclang.compiler.driver.program { JacProgram }
        import from jaclang.runtime.prepared { forget }
        try {
            prepared = prepare_application(str(path), JacProgram(), tmp, client=True);
            routes = str(
                prepared.manifests[os.path.realpath(str(path))].get('spa_routes')
            );
            assert 'about' in routes , f"the first page is not routed: {routes}";
        } finally {
            forget(str(path));
        }
    }
}

test "an edit to a client module the entry imports re-prepares the application" {
    import from jaclang.testing.requires { require_tool }
    require_tool('bun');
    with TemporaryDirectory(prefix='jac-prepared-imports-') as tmp {
        base = Path(tmp);
        path = base / 'main.jac';
        path.write_text(
            'import from "@jac/runtime" { renderJsxTree, }\n\n'
            'def:pub app(children: any) -> JsxElement {\n    <div class="root">{children}</div>\n}\n'
        );
        (base / 'jac.toml').write_text('[project]\nname = "prepared-imports"\n');
        page = base / 'pages' / 'index.jac';
        page.parent.mkdir();
        page.write_text(
            'import from shared.widget { Widget }\n\n'
            'def:pub page -> JsxPage {\n    return <Widget/>;\n}\n'
        );
        widget = base / 'shared' / 'widget.jac';
        widget.parent.mkdir();
        widget.write_text(
            'def label -> str;\n\n'
            'def:pub Widget -> JsxElement {\n    <span>{label()}</span>\n}\n'
        );
        annex = base / 'shared' / 'widget.impl.jac';
        annex.write_text('impl label -> str {\n    return "one";\n}\n');
        assert not _restored(path, tmp);
        assert _restored(path, tmp);
        path.write_text(path.read_text().replace('class="root"', 'class="app"'));
        assert not _restored(path, tmp) , "an edit to the entry was restored from the old record";
        widget.write_text(
            'def label -> str;\n\n'
            'def:pub Widget -> JsxElement {\n    <b>{label()}</b>\n}\n'
        );
        assert not _restored(path, tmp) , "an edit to an imported client module was restored from the old record";
        assert _restored(path, tmp);
        annex.write_text('impl label -> str {\n    return "two";\n}\n');
        assert not _restored(path, tmp) , "an edit to an imported module's impl annex was restored from the old record";
        compiled = [
            p
            for p in base.rglob('widget.js')
            if '.jac' in p.parts
        ];
        assert compiled and '"two"' in compiled[0].read_text() , "the client bundle kept the old annex";
    }
}
