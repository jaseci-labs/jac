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
            "jac/tests/compiler/passes/main/fixtures/checker_type_ref.jac",

        ],
        description="jac check runs on test fixture",
    );
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
    run_cli_tests(runner);
    sys.exit(runner.summary());
}
