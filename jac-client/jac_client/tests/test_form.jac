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

def _setup_form_project(
    app_name: str, build: bool = False, start_server: bool = False
) -> tuple {
    """Create a test project with the form-handling example copied in."""
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
        [*jac_cmd, "create", "--use", "client", app_name],
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
        if entry in {"node_modules","build","dist",".pytest_cache",".jac"} {
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

def _cleanup_form_project(temp_dir: str, original_cwd: str) -> None {
    """Clean up the test project."""
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

test "form validation with browser" {
    (project_path, temp_dir, original_cwd, jac_cmd, env, server, server_port, url) = _setup_form_project(
        "test-form-validation-browser", build=False, start_server=True
    );
    try {
        time.sleep(3);

        # Use Playwright to test form validation
        with sync_playwright() as p {
            browser = p.chromium.launch(headless=True);
            context = browser.new_context();
            page = context.new_page();
            try {
                page.goto(url, wait_until="networkidle", timeout=60000);
                page.wait_for_timeout(2000);

                # Submit button should be disabled initially
                submit_btn = page.locator('button[type="submit"]').first;
                is_disabled = submit_btn.evaluate("el => el.disabled");
                assert is_disabled , "Submit button should be disabled initially";
                # Test 1: Invalid email validation
                email_input = page.locator('input[name="emailField"]').first;
                email_input.fill("not-an-email");
                email_input.blur();
                page.wait_for_timeout(500);
                is_valid = email_input.evaluate("el => el.validity.valid");
                assert not is_valid , "Invalid email should not be valid";
                # Test 2: Valid email should pass validation
                email_input.fill("test@example.com");
                email_input.blur();
                page.wait_for_timeout(500);
                is_valid_now = email_input.evaluate("el => el.validity.valid");
                assert is_valid_now , "Valid email should be valid";
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
