import gc;
import os;
import re;
import shutil;
import tempfile;
import time;
import pytest;
import from pathlib { Path }
import from subprocess { Popen, PIPE, STDOUT, run }
import from urllib.error { HTTPError, URLError }
import from urllib.request { urlopen }
import from .test_helpers {
    get_jac_command,
    get_env_with_npm,
    get_free_port,
    wait_for_port
}
import from playwright.sync_api { sync_playwright }

"""Create a test project with the form-handling example copied in."""
def _setup_form_project(
    app_name: str, build: bool = False, start_server: bool = False
) -> tuple {
    tests_dir = os.path.dirname(__file__);
    jac_client_root = os.path.dirname(tests_dir);
    form_handling_path = os.path.join(jac_client_root, "examples", "form-handling");
    assert os.path.isdir(form_handling_path) , (
        f"form-handling example not found at {form_handling_path}"
    );
    temp_dir = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(temp_dir);

    jac_cmd = get_jac_command();
    env = get_env_with_npm();

    process = Popen(
        [*jac_cmd, "create", "--kind", "client", app_name],
        stdin=PIPE,
        stdout=PIPE,
        stderr=PIPE,
        text=True,
        env=env,
    );
    (stdout, stderr) = process.communicate();
    assert process.returncode == 0 , (f"Failed to create test app:\n{stderr}");

    project_path = os.path.join(temp_dir, app_name);
    for entry in os.listdir(form_handling_path) {
        src = os.path.join(form_handling_path, entry);
        dst = os.path.join(project_path, entry);
        if entry in {"node_modules", "build", "dist", ".pytest_cache", ".jac"} {
            continue;
        }
        if os.path.isdir(src) {
            shutil.copytree(src, dst, dirs_exist_ok=True);
        } else {
            shutil.copy2(src, dst);
        }
    }
    # build the project if requested
    if build {
        build_result = run(
            [*jac_cmd, "build"],
            cwd=project_path,
            capture_output=True,
            text=True,
            env=env,
        );
        assert build_result.returncode == 0 , (
            f"form-handling example failed to compile:\n"
            f"STDOUT:\n{build_result.stdout}\n"
            f"STDERR:\n{build_result.stderr}"
        );
    }
    # Start server if requested
    if start_server {
        server_port = get_free_port();
        server = Popen(
            [*jac_cmd, "start", "main.jac", "-p", str(server_port)],
            cwd=project_path,
            stdout=PIPE,
            stderr=STDOUT,
            env=env,
        );
        wait_for_port("127.0.0.1", server_port, timeout=90.0);
        url = f"http://127.0.0.1:{server_port}";
        return (
            project_path,
            temp_dir,
            original_cwd,
            jac_cmd,
            env,
            server,
            server_port,
            url
        );
    }

    return (project_path, temp_dir, original_cwd, jac_cmd, env);
}

"""Clean up the test project."""
def _cleanup_form_project(temp_dir: str, original_cwd: str) {
    os.chdir(original_cwd);
    gc.collect();
}

test "form validation rules in bundle" {
    (project_path, temp_dir, original_cwd, jac_cmd, env) = _setup_form_project(
        "test-form-validation", build=True
    );
    try {
        dist_dir = Path(project_path) / ".jac" / "client" / "dist";
        js_files = list(dist_dir.glob("**/*.js"));
        client_js = None;
        for js_file in js_files {
            if "client" in js_file.name {
                client_js = str(js_file);
                break;
            }
        }
        assert client_js is not None , "Client JS bundle not found";
        with open(client_js, "r", encoding="utf-8") as f {
            bundle_content = f.read();
        }
        assert "Invalid email" in bundle_content , (
            "Email validation message not found in bundle"
        );
        assert "uppercase letter" in bundle_content , (
            "Password uppercase validation not found in bundle"
        );
    } finally {
        _cleanup_form_project(temp_dir, original_cwd);
    }
}

test "form loads and renders" {
    (project_path, temp_dir, original_cwd, jac_cmd, env, server, server_port, url) = _setup_form_project(
        "test-form-e2e", build=False, start_server=True
    );
    try {
        try {
            with urlopen(url, timeout=30) as resp {
                page_body = resp.read().decode("utf-8", errors="ignore");
                assert resp.status == 200 , "Server did not return 200";
                assert "<html" in page_body.lower() , "No HTML in response";
                assert '<div id="root">' in page_body , ("React root div not found");
            }
        } except (URLError, HTTPError) as exc {
            raise AssertionError(f"Failed to load form page: {exc}");
        }

        try {
            script_match = re.search(r'src="(/static/client[^"]+)"', page_body);
            assert script_match , "Client JS bundle path not found in HTML";

            js_path = script_match.group(1);
            js_url = f"{url}{js_path}";
            with urlopen(js_url, timeout=30) as resp {
                js_content = resp.read().decode("utf-8", errors="ignore");
                assert resp.status == 200;
                assert len(js_content) > 0 , "JS bundle is empty";
                assert ("JacForm" in js_content or "JacSchema" in js_content) , "Form handling code not found in JS bundle";
            }
        } except (URLError, HTTPError) as exc {
            raise AssertionError(f"Failed to load JS bundle: {exc}");
        }
    } finally {
        server.terminate();
        try {
            server.wait(timeout=15);
        } except Exception {
            server.kill();
            server.wait(timeout=5);
        }
        time.sleep(1);
        gc.collect();
        _cleanup_form_project(temp_dir, original_cwd);
    }
}

"""Create a minimal single-email form project for submit semantics tests."""
def _setup_simple_submit_project(app_name: str, start_server: bool = False) -> tuple {
    temp_dir = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(temp_dir);

    jac_cmd = get_jac_command();
    env = get_env_with_npm();

    process = Popen(
        [*jac_cmd, "create", "--kind", "client", app_name],
        stdin=PIPE,
        stdout=PIPE,
        stderr=PIPE,
        text=True,
        env=env,
    );
    (stdout, stderr) = process.communicate();
    assert process.returncode == 0 , (f"Failed to create test app:\n{stderr}");

    project_path = os.path.join(temp_dir, app_name);

    form_src = (
        'cl {\n'
        '    import from "@jac/runtime" { JacForm, JacSchema }\n'
        '\n'
        '    def:pub SubmitTestForm -> JsxElement {\n'
        '        schema = JacSchema({\n'
        '            emailField: JacSchema.string().email("Invalid email")\n'
        '        });\n'
        '        async def handleSubmit(data: dict) {\n'
        '            window.__submitFired = True;\n'
        '        }\n'
        '        return (\n'
        '            <JacForm\n'
        '                schema={schema}\n'
        '                onSubmit={handleSubmit}\n'
        '                field_config={{"emailField": {\n'
        '                    label: "Email",\n'
        '                    type: "email",\n'
        '                    placeholder: "you@example.com"\n'
        '                }}}\n'
        '                submitLabel="Submit"\n'
        '            />\n'
        '        );\n'
        '    }\n'
        '}\n'
    );
    main_src = (
        'cl {\n'
        '    import from "@jac/runtime" { Router, Routes, Route }\n'
        '    import from .submit_test_form { SubmitTestForm }\n'
        '\n'
        '    def:pub app -> JsxElement {\n'
        '        return (\n'
        '            <Router>\n'
        '                <Routes>\n'
        '                    <Route path="/" element={<SubmitTestForm/>}/>\n'
        '                </Routes>\n'
        '            </Router>\n'
        '        );\n'
        '    }\n'
        '}\n'
    );
    with open(
        os.path.join(project_path, "submit_test_form.cl.jac"), "w", encoding="utf-8"
    ) as f {
        f.write(form_src);
    }
    with open(os.path.join(project_path, "main.jac"), "w", encoding="utf-8") as f {
        f.write(main_src);
    }

    if start_server {
        server_port = get_free_port();
        server = Popen(
            [*jac_cmd, "start", "main.jac", "-p", str(server_port)],
            cwd=project_path,
            stdout=PIPE,
            stderr=STDOUT,
            env=env,
        );
        wait_for_port("127.0.0.1", server_port, timeout=90.0);
        url = f"http://127.0.0.1:{server_port}";
        return (
            project_path,
            temp_dir,
            original_cwd,
            jac_cmd,
            env,
            server,
            server_port,
            url
        );
    }
    return (project_path, temp_dir, original_cwd, jac_cmd, env);
}

test "form validation with browser" {
    (project_path, temp_dir, original_cwd, jac_cmd, env, server, server_port, url) = _setup_form_project(
        "test-form-validation-browser", build=False, start_server=True
    );
    try {
        with sync_playwright() as p {
            browser = p.chromium.launch(headless=True);
            context = browser.new_context();
            page = context.new_page();
            try {
                page.goto(url, wait_until="networkidle", timeout=60000);
                # Wait for React to hydrate: the email field must be visible before
                # we interact with anything.
                email_input = page.locator('input[name="emailField"]').first;
                email_input.wait_for(state="visible", timeout=30000);

                # Submit button should be disabled initially
                submit_btn = page.locator('button[type="submit"]').first;
                submit_btn.wait_for(state="visible", timeout=5000);
                is_disabled = submit_btn.evaluate("el => el.disabled");
                assert is_disabled , "Submit button should be disabled initially";

                # Test 1: Invalid email → Jac renders a ⚠️ error <p> after blur
                # (isTouched gates renderError in onTouched mode; blur sets it)
                email_input.fill("not-an-email");
                email_input.blur();
                page.wait_for_selector("p:has-text('Invalid email')", timeout=5000);
                email_err = page.locator("p:has-text('Invalid email')").first;
                assert email_err.is_visible() , (
                    "Jac 'Invalid email' error paragraph should be visible after blur"
                );
                assert "Invalid email" in (email_err.text_content() or "") , (
                    f"Error text mismatch: {email_err.text_content()!r}"
                );

                # Test 2: Valid email → error <p> must disappear
                email_input.fill("test@example.com");
                email_input.blur();
                page.wait_for_selector(
                    "p:has-text('Invalid email')", state="hidden", timeout=5000
                );
                assert not page.locator("p:has-text('Invalid email')").is_visible() , (
                    "Error paragraph should be gone after entering a valid email"
                );
            } finally {
                context.close();
                browser.close();
            }
        }
    } finally {
        server.terminate();
        try {
            server.wait(timeout=15);
        } except Exception {
            server.kill();
            server.wait(timeout=5);
        }
        time.sleep(1);
        gc.collect();
        _cleanup_form_project(temp_dir, original_cwd);
    }
}

test "form submit button enables when form is valid and onSubmit fires (Playwright)" {
    (project_path, temp_dir, original_cwd, jac_cmd, env, server, server_port, url) = (
        _setup_simple_submit_project("test-form-submit", start_server=True)
    );
    try {
        try {
            import from playwright.sync_api { sync_playwright }
        } except ImportError {
            pytest.skip("playwright not installed");
        }
        with sync_playwright() as p {
            browser = p.chromium.launch(headless=True);
            context = browser.new_context();
            page = context.new_page();
            try {
                page.goto(url, wait_until="networkidle", timeout=60000);
                email_input = page.locator('input[type="email"]').first;
                email_input.wait_for(state="visible", timeout=30000);
                submit_btn = page.locator('button[type="submit"]').first;
                submit_btn.wait_for(state="visible", timeout=5000);

                # 1. Disabled initially — form not dirty
                assert submit_btn.evaluate("el => el.disabled") , (
                    "Submit button must be disabled before the form is touched"
                );

                # 2. Fill a valid email and blur — onChange validates, isTouched
                #    gate is satisfied after blur; form is dirty + valid → enabled.
                email_input.fill("test@example.com");
                email_input.blur();
                page.wait_for_function(
                    "() => { const b = document.querySelector('button[type=\"submit\"]'); "
                    "return b && !b.disabled; }",
                    timeout=10000,
                );
                assert not submit_btn.evaluate("el => el.disabled") , (
                    "Submit button must be enabled after form is dirty and valid"
                );

                # 3. Click submit — async onSubmit sets window.__submitFired
                page.evaluate("() => { window.__submitFired = false; }");
                submit_btn.click();
                page.wait_for_function(
                    "() => window.__submitFired === true", timeout=10000
                );
                assert page.evaluate("() => window.__submitFired") , (
                    "onSubmit callback must fire after clicking the submit button"
                );
            } finally {
                context.close();
                browser.close();
            }
        }
    } finally {
        server.terminate();
        try {
            server.wait(timeout=15);
        } except Exception {
            server.kill();
            server.wait(timeout=5);
        }
        time.sleep(1);
        gc.collect();
        os.chdir(original_cwd);
        shutil.rmtree(temp_dir, ignore_errors=True);
    }
}
