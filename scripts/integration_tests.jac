"""Integration tests requiring all Jac plugins to be installed.

This script tests the full Jac ecosystem with all plugins loaded.
It is designed to run in CI (test-pypi-build) after all packages are installed,
or locally when you have all plugins installed.

Requirements:
    - jaclang (jac) installed
    - jac-client installed
    - jac-scale installed
    - byllm installed

Usage:
    jac run scripts/integration_tests.jac

Note: This script should NOT be run with JAC_DISABLED_PLUGINS set, as it needs
all plugins to be loaded to verify the plugin system works correctly.
"""

import os;
import subprocess;
import sys;

"""Runner for integration tests with detailed output."""
obj IntegrationTestRunner {
    has passed: int = 0,
        failed: int = 0,
        errors: list[str] = [];

    """Run a command and verify output contains/excludes expected strings."""
    def run(
        cmd: list[str],
        check_contains: list[str] | None = None,
        check_not_contains: list[str] | None = None,
        description: str | None = None
    ) -> subprocess.CompletedProcess {
        desc = description or " ".join(cmd);
        print(f"\n{'=' * 60}");
        print(f"TEST: {desc}");
        print(f"CMD:  {' '.join(cmd)}");
        print("-" * 60);

        result = subprocess.run(cmd, capture_output=True, text=True);

        if result.returncode != 0 {
            print(f"FAIL: Command exited with code {result.returncode}");
            print(f"STDERR:\n{result.stderr}");
            self.failed += 1;
            self.errors.append(f"{desc}: non-zero exit code {result.returncode}");
            return result;
        }

        if check_contains {
            for s in check_contains {
                if s not in result.stdout and s.lower() not in result.stdout.lower() {
                    print(f"FAIL: Expected '{s}' not found in output");
                    print(f"OUTPUT:\n{result.stdout[:500]}...");
                    self.failed += 1;
                    self.errors.append(f"{desc}: '{s}' not in output");
                    return result;
                }
            }
        }

        if check_not_contains {
            for s in check_not_contains {
                if s in result.stdout {
                    print(f"FAIL: Unexpected '{s}' found in output");
                    self.failed += 1;
                    self.errors.append(f"{desc}: unexpected '{s}' in output");
                    return result;
                }
            }
        }

        print("PASS");
        self.passed += 1;
        return result;
    }

    """Print test summary and return exit code."""
    def summary -> int {
        print(f"\n{'=' * 60}");
        print("INTEGRATION TEST SUMMARY");
        print("=" * 60);
        print(f"Passed: {self.passed}");
        print(f"Failed: {self.failed}");

        if self.errors {
            print("\nFailures:");
            for err in self.errors {
                print(f"  - {err}");
            }
            return 1;
        }
        print("\nAll integration tests passed!");
        return 0;
    }
}

"""Verify the test environment is correctly configured."""
def check_environment -> bool {
    if os.environ.get("JAC_DISABLED_PLUGINS") {
        print(
            "WARNING: JAC_DISABLED_PLUGINS is set. Integration tests require all plugins."
        );
        print("         Unsetting JAC_DISABLED_PLUGINS for this test run.");
        os.environ.pop("JAC_DISABLED_PLUGINS", None);
    }
    result = subprocess.run(["jac", "--version"], capture_output=True, text=True);
    if result.returncode != 0 {
        print("ERROR: 'jac' command not found. Please install jaclang first.");
        return False;
    }
    print(f"Jac version: {result.stdout.strip()}");
    return True;
}

"""Test the jac plugins command and plugin system."""
def run_plugin_tests(runner: IntegrationTestRunner) {
    runner.run(
        ["jac", "plugins", "list"],
        check_contains=[
            "Installed Jac plugins",
            "jaclang (built-in)",
            "jaclang:JacRuntimeInterfaceImpl",

        ],
        description="jac plugins list shows installed plugins with qualified names",
    );

    runner.run(
        ["jac", "plugins", "list"],
        check_contains=["jac-client", "jac-client:serve"],
        description="jac-client plugins use qualified name format",
    );

    result = subprocess.run(["jac", "plugins", "list"], capture_output=True, text=True);
    if "jac-scale" in result.stdout {
        runner.run(
            ["jac", "plugins", "list"],
            check_contains=["jac-scale", "jac-scale:scale"],
            description="jac-scale plugins use qualified name format",
        );
    } else {
        print("\n" + "=" * 60);
        print("SKIP: jac-scale plugins test (plugin not installed)");
        print("=" * 60);
    }

    if "byllm" in result.stdout {
        runner.run(
            ["jac", "plugins", "list"],
            check_contains=["byllm", "byllm:byllm"],
            description="byllm plugins use qualified name format",
        );
    } else {
        print("\n" + "=" * 60);
        print("SKIP: byllm plugins test (plugin not installed)");
        print("=" * 60);
    }

    if "Commands:" in result.stdout or "\U0001f4bb" in result.stdout {
        runner.run(
            ["jac", "plugins", "list"],
            check_contains=["Commands:"],
            description="Plugin commands are shown in plugins list",
        );
    } else {
        print("\n" + "=" * 60);
        print("SKIP: Plugin commands test (no plugins with commands installed)");
        print("=" * 60);
    }

    runner.run(
        ["jac", "--help"],
        check_contains=["create"],
        description="jac --help shows plugin commands (create)",
    );

    runner.run(
        ["jac", "plugins", "list", "--verbose"],
        check_contains=["Class:", "Module:"],
        description="jac plugins list --verbose shows detailed info",
    );

    runner.run(
        ["jac", "plugins", "disabled"],
        check_contains=["No plugins are currently disabled"],
        description="jac plugins disabled shows no disabled by default",
    );
}

"""Test that .jac modules can be imported without explicit 'import jaclang'."""
def run_pth_tests(runner: IntegrationTestRunner) {
    # Write a temporary .jac module
    import tempfile;
    tmpdir = tempfile.mkdtemp();
    jac_file = os.path.join(tmpdir, "hello_pth.jac");
    open(jac_file, "w").write('with entry { print("pth_import_ok"); }\n');

    # Import the .jac module from Python without 'import jaclang'
    runner.run(
        [
            sys.executable, "-c",
            f"import sys; sys.path.insert(0, {tmpdir!r}); import hello_pth",
        ],
        check_contains=["pth_import_ok"],
        description=".pth finder: import .jac module without explicit 'import jaclang'",
    );

    # Cleanup
    os.remove(jac_file);
    os.rmdir(tmpdir);
}

"""Test basic CLI functionality."""
def run_cli_tests(runner: IntegrationTestRunner) {
    runner.run(
        ["jac", "--version"],
        check_contains=["Version:"],
        description="jac --version shows version",
    );

    runner.run(
        [
            "jac",
            "check",
            "jac/tests/compiler/passes/main/fixtures/checker/checker_type_ref.jac",

        ],
        description="jac check runs on test fixture",
    );
}

"""Test that pre-built admin UI assets are bundled and served correctly."""
def run_admin_prebuild_tests(runner: IntegrationTestRunner) {
    import tempfile;
    import time;
    import shutil;

    # --- Package-level checks ---

    # Verify _dist directory exists with index.html in the installed package
    runner.run(
        [
            sys.executable, "-c",
            "from pathlib import Path;"
            "import jac_scale;"
            "d = Path(jac_scale.__file__).parent / 'admin' / '_dist';"
            "idx = d / 'index.html';"
            "assert d.exists(), f'_dist not found at {d}';"
            "assert idx.exists(), f'index.html not found at {idx}';"
            "files = list(d.rglob('*'));"
            "count = len([f for f in files if f.is_file()]);"
            "print(f'Pre-built admin UI: {count} files bundled at {d}');"
            "print(f'index.html size: {idx.stat().st_size} bytes')",
        ],
        check_contains=["Pre-built admin UI"],
        description="jac-scale package includes pre-built admin UI assets",
    );

    # Verify index.html is a real Vite build output (not a placeholder)
    runner.run(
        [
            sys.executable, "-c",
            "from pathlib import Path;"
            "import jac_scale;"
            "idx = Path(jac_scale.__file__).parent / 'admin' / '_dist' / 'index.html';"
            "html = idx.read_text();"
            "assert '<html' in html.lower(), 'Not valid HTML';"
            "assert 'script' in html.lower(), 'No script tags (not a Vite build)';"
            "print('index.html is valid Vite build output')",
        ],
        check_contains=["valid Vite build output"],
        description="Pre-built admin index.html is valid Vite output",
    );

    # --- E2E server test ---

    # Create a minimal jac project in a temp directory
    tmpdir = tempfile.mkdtemp(prefix="admin-e2e-");
    main_jac = os.path.join(tmpdir, "main.jac");
    open(main_jac, "w").write(
        'walker:pub Health {\n'
        '    can check with `root entry {\n'
        '        report {"status": "healthy"};\n'
        '    }\n'
        '}\n'
    );
    jac_toml = os.path.join(tmpdir, "jac.toml");
    open(jac_toml, "w").write(
        '[project]\n'
        'name = "admin-e2e-test"\n'
        'version = "0.0.1"\n'
    );
    log_file = os.path.join(tmpdir, "server.log");
    port = 18899;
    server_proc: subprocess.Popen | None = None;
    desc = "Admin E2E";

    try {
        # Start server in background
        print(f"\n{'=' * 60}");
        print(f"TEST: {desc} - start jac-scale server");
        print(f"CMD:  jac start main.jac --port {port}");
        print("-" * 60);

        log_fh = open(log_file, "w");
        server_proc = subprocess.Popen(
            ["jac", "start", "main.jac", "--port", str(port)],
            cwd=tmpdir,
            stdout=log_fh,
            stderr=subprocess.STDOUT
        );

        # Wait for server readiness via /healthz
        for _i in range(30) {
            if server_proc.poll() is not None {
                print(f"FAIL: Server exited with code {server_proc.returncode}");
                log_fh.flush();
                print(f"LOG:\n{open(log_file).read()[-500:]}");
                runner.failed += 1;
                runner.errors.append(f"{desc}: server died during startup");
                return;
            }
            probe = subprocess.run(
                [sys.executable, "-c",
                 f"import urllib.request; urllib.request.urlopen('http://localhost:{port}/healthz', timeout=3)"],
                capture_output=True
            );
            if probe.returncode == 0 {
                break;
            }
            time.sleep(2);
        } else {
            print("FAIL: Server did not become ready in 60s");
            log_fh.flush();
            print(f"LOG:\n{open(log_file).read()[-500:]}");
            runner.failed += 1;
            runner.errors.append(f"{desc}: server not ready after 60s");
            return;
        }
        print("PASS");
        runner.passed += 1;

        # Hit /admin/ and verify response
        print(f"\n{'=' * 60}");
        print(f"TEST: {desc} - /admin/ serves pre-built dashboard");
        print(f"CMD:  GET http://localhost:{port}/admin/");
        print("-" * 60);

        check_script = (
            "import urllib.request, time, sys;"
            "start = time.monotonic();"
            "resp = urllib.request.urlopen('http://localhost:" + str(port) + "/admin/', timeout=15);"
            "elapsed = int((time.monotonic() - start) * 1000);"
            "body = resp.read().decode();"
            "code = resp.status;"
            "assert code == 200, f'HTTP {code}';"
            "assert '<html' in body.lower(), 'Not HTML';"
            "print(f'HTTP {code} in {elapsed}ms');"
            "print(f'body_length={len(body)}')"
        );

        result = subprocess.run(
            [sys.executable, "-c", check_script],
            capture_output=True, text=True, timeout=30
        );

        if result.returncode != 0 {
            print(f"FAIL: /admin/ request failed");
            print(f"STDERR: {result.stderr}");
            runner.failed += 1;
            runner.errors.append(f"{desc}: /admin/ request failed");
            return;
        }

        # Check server logs for build path
        log_fh.flush();
        log_content = open(log_file).read();
        if "Building admin client from source" in log_content {
            print("FAIL: Server built from source instead of using pre-built assets");
            runner.failed += 1;
            runner.errors.append(f"{desc}: built from source, pre-built assets not used");
            return;
        }

        used_prebuilt = "Using pre-built admin client from package" in log_content;
        print(f"{result.stdout.strip()}, pre-built path: {used_prebuilt}");
        print("PASS");
        runner.passed += 1;

    } finally {
        # Cleanup server process
        if server_proc is not None and server_proc.poll() is None {
            server_proc.terminate();
            try {
                server_proc.wait(timeout=5);
            } except subprocess.TimeoutExpired {
                server_proc.kill();
                server_proc.wait();
            }
        }
        # Cleanup temp files
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

with entry {
    print("=" * 60);
    print("JAC INTEGRATION TESTS");
    print("Testing full plugin ecosystem");
    print("=" * 60);

    if not check_environment() {
        sys.exit(1);
    }
}

glob runner = IntegrationTestRunner();

with entry {
    run_plugin_tests(runner);
    run_pth_tests(runner);
    run_cli_tests(runner);
    run_admin_prebuild_tests(runner);
    sys.exit(runner.summary());
}
