"""Build / serve / config tests for the client toolchain (no browser).

Recovers config-matrix coverage dropped when PR #6840 merged jac-client into
core (the deleted `test_it.jac`). Each test copies a fixture into a temp dir,
mutates its config where needed, `jac start`s it, and asserts over the served
HTTP surface: the API base URL + Vite defines/env reach the bundle, profiles
swap served settings, walker reader/writer effects are classified, form
validation rules are bundled, multi-segment routes resolve assets, and a
syntax error surfaces a console diagnostic.

The app fixture is `fixtures/fullstack` (walkers + auth + form in one Router
app); the multi-segment case reuses the in-tree `fixtures/multi_segment_app`.
"""

import json;
import os;
import re;
import time;
import pytest;
import from subprocess { Popen, TimeoutExpired, run }
import from tempfile { TemporaryDirectory }

import from .test_helpers {
    copy_fixture,
    get_env_with_bun,
    get_free_port,
    get_jac_command,
    request_endpoint,
    start_app_server,
    stop_server
}

"""Append a block of text to a fixture copy's jac.toml."""
def _append_toml(project_path: str, block: str) {
    toml_path = os.path.join(project_path, "jac.toml");
    with open(toml_path, "a") as f {
        f.write(block);
    }
}

"""Parse the endpointEffects map embedded in a served page's __jac_init__."""
def _endpoint_effects(page_html: str) -> dict {
    init_hit = re.search(
        r'<script\s+id="__jac_init__"[^>]*>(.*?)</script>', page_html, re.DOTALL,
    );
    assert init_hit , "served page should embed a __jac_init__ script";
    data: dict = json.loads(init_hit.group(1));
    return data.get("endpointEffects", {});
}

"""A configured `[client.api] base_url` is baked into the bundle."""
test "configurable api base url in bundle" {
    with TemporaryDirectory() as temp_dir {
        project_path = copy_fixture("fullstack", temp_dir);
        base_url = "http://my-custom-backend:9000";
        _append_toml(project_path, f'\n[client.api]\nbase_url = "{base_url}"\n');
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_path);
            js_body = request_endpoint(
                f"http://127.0.0.1:{port}/static/client.js"
            ).decode(
                "utf-8", errors="ignore"
            );
            assert base_url in js_body , (
                f"configured base_url '{base_url}' should appear in the bundle"
            );
        } finally {
            stop_server(server);
        }
    }
}

"""`--profile prod` loads jac.prod.toml and swaps the served <title>."""
test "profile config applies to served page" {
    with TemporaryDirectory() as temp_dir {
        project_path = copy_fixture("fullstack", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(
                project_path, extra_args=["--profile", "prod"]
            );
            body = request_endpoint(f"http://127.0.0.1:{port}/").decode(
                "utf-8", errors="ignore"
            );
            assert "<title>Fullstack Prod</title>" in body , (
                f"prod profile title should be served; got:\n{body[:400]}"
            );
            assert "<title>Fullstack Base</title>" not in body , (
                "base title should be overridden by the prod profile"
            );
        } finally {
            stop_server(server);
        }
    }
}

"""Without a profile, only the base jac.toml settings are served."""
test "no profile keeps base settings" {
    with TemporaryDirectory() as temp_dir {
        project_path = copy_fixture("fullstack", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_path);
            body = request_endpoint(f"http://127.0.0.1:{port}/").decode(
                "utf-8", errors="ignore"
            );
            assert "<title>Fullstack Base</title>" in body , (
                f"base title should be served with no profile; got:\n{body[:400]}"
            );
            assert "<title>Fullstack Prod</title>" not in body , (
                "prod-only settings must not leak without --profile"
            );
        } finally {
            stop_server(server);
        }
    }
}

"""Vite `define` values and .env VITE_ vars are substituted into the bundle."""
test "vite define and env values reach the bundle" {
    with TemporaryDirectory() as temp_dir {
        project_path = copy_fixture("fullstack", temp_dir);
        build_time = "2099-01-02T03:04:05Z";
        app_name = "Vite Define Probe";
        _append_toml(
            project_path,
            f'\n[client.vite.define]\n'
            f'"globalThis.APP_BUILD_TIME" = "{build_time}"\n',
        );
        with open(os.path.join(project_path, ".env"), "w") as f {
            f.write(f"VITE_APP_NAME={app_name}\n");
        }
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_path);
            js_body = request_endpoint(
                f"http://127.0.0.1:{port}/static/client.js"
            ).decode(
                "utf-8", errors="ignore"
            );
            assert build_time in js_body , (
                f"vite define value '{build_time}' should be in the bundle"
            );
            assert app_name in js_body , (
                f"VITE_APP_NAME value '{app_name}' should be in the bundle"
            );
        } finally {
            stop_server(server);
        }
    }
}

"""A deeply nested SPA route still resolves the client asset (leading slash)."""
test "multi-segment route resolves assets" {
    with TemporaryDirectory() as temp_dir {
        project_path = copy_fixture("multi_segment_app", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_path);
            base = f"http://127.0.0.1:{port}";
            nested = request_endpoint(f"{base}/dashboard/settings").decode(
                "utf-8", errors="ignore"
            );
            asset_hit = re.search(
                r'src="(/static/client\.js\?hash=[a-f0-9]+)"', nested
            );
            if not asset_hit {
                asset_hit = re.search(r'src="(/client\.[A-Za-z0-9_-]+\.js)"', nested);
            }
            assert asset_hit , (
                f"nested route should reference a root-absolute asset; got:\n{nested[:500]}"
            );
            asset = request_endpoint(f"{base}{asset_hit.group(1)}");
            assert len(asset) > 0 , "referenced asset should be reachable + non-empty";
        } finally {
            stop_server(server);
        }
    }
}

"""Walker reader/writer effects are classified in the served __jac_init__.

This is the metadata the client auto-cache keys off: readers (no graph
mutation) are de-duplicated, writers invalidate. `create_item` mutates Root
(`++>`) so it is a writer; the two report-only walkers are readers.
"""
test "endpoint effects classify readers and writers" {
    with TemporaryDirectory() as temp_dir {
        project_path = copy_fixture("fullstack", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_path);
            body = request_endpoint(f"http://127.0.0.1:{port}/").decode(
                "utf-8", errors="ignore"
            );
            effects = _endpoint_effects(body);
            for reader in ["walker:ping_server", "walker:get_server_message"] {
                assert reader in effects , f"{reader} should be classified";
                assert not effects[reader]["is_writer"] , (
                    f"{reader} should be a reader (is_writer=false)"
                );
            }
            assert "walker:create_item" in effects , "writer should be classified";
            assert effects["walker:create_item"]["is_writer"] , (
                "create_item mutates Root and should be a writer"
            );
        } finally {
            stop_server(server);
        }
    }
}

"""Zod/JacSchema validation messages are compiled into the client bundle."""
test "form validation rules are bundled" {
    with TemporaryDirectory() as temp_dir {
        project_path = copy_fixture("fullstack", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_path);
            js_body = request_endpoint(
                f"http://127.0.0.1:{port}/static/client.js"
            ).decode(
                "utf-8", errors="ignore"
            );
            assert "Invalid email" in js_body , (
                "email validation message should be bundled"
            );
            assert "uppercase letter" in js_body , (
                "password validation message should be bundled"
            );
        } finally {
            stop_server(server);
        }
    }
}

"""A syntax error in a source file surfaces a coded console diagnostic."""
test "syntax error surfaces a console diagnostic" {
    with TemporaryDirectory() as temp_dir {
        project_path = copy_fixture("fullstack", temp_dir);
        main_path = os.path.join(project_path, "main.jac");
        with open(main_path) as f {
            source = f.read();
        }
        with open(main_path, "w") as f {
            f.write(source.replace("cl {", "cl {{{{", 1));
        }
        port = get_free_port();
        jac_cmd = get_jac_command();
        env = get_env_with_bun();
        # The broken build aborts `jac start`, so capture its console output.
        captured = "";
        try {
            result = run(
                [*jac_cmd, "start", "main.jac", "-p", str(port)],
                cwd=project_path,
                env=env,
                capture_output=True,
                text=True,
                timeout=120,
            );
            captured = (result.stdout or "") + (result.stderr or "");
        } except TimeoutExpired as exc {
            captured = "";
            if exc.stdout {
                captured += exc.stdout
                    if isinstance(exc.stdout, str)
                    else exc.stdout.decode("utf-8", errors="ignore");
            }
            if exc.stderr {
                captured += exc.stderr
                    if isinstance(exc.stderr, str)
                    else exc.stderr.decode("utf-8", errors="ignore");
            }
        }
        assert "error[" in captured , (
            f"a syntax error should print a coded diagnostic; got:\n{captured[:600]}"
        );
        assert ("Unexpected token" in captured or "Syntax" in captured) , (
            f"diagnostic should describe the syntax problem; got:\n{captured[:600]}"
        );
    }
}
