#!/usr/bin/env python3
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
    python scripts/integration_tests.py

Note: This script should NOT be run with JAC_DISABLED_PLUGINS set, as it needs
all plugins to be loaded to verify the plugin system works correctly.
"""

import os
import subprocess
import sys


class IntegrationTestRunner:
    """Runner for integration tests with detailed output."""

    def __init__(self) -> None:
        self.passed = 0
        self.failed = 0
        self.errors: list[str] = []

    def run(
        self,
        cmd: list[str],
        check_contains: list[str] | None = None,
        check_not_contains: list[str] | None = None,
        description: str | None = None,
    ) -> subprocess.CompletedProcess:
        """Run a command and verify output contains/excludes expected strings.

        Args:
            cmd: Command to run as list of strings
            check_contains: Strings that must appear in stdout
            check_not_contains: Strings that must NOT appear in stdout
            description: Human-readable description of the test

        Returns:
            The completed process result
        """
        desc = description or " ".join(cmd)
        print(f"\n{'=' * 60}")
        print(f"TEST: {desc}")
        print(f"CMD:  {' '.join(cmd)}")
        print("-" * 60)

        result = subprocess.run(cmd, capture_output=True, text=True)

        # Check return code
        if result.returncode != 0:
            print(f"FAIL: Command exited with code {result.returncode}")
            print(f"STDERR:\n{result.stderr}")
            self.failed += 1
            self.errors.append(f"{desc}: non-zero exit code {result.returncode}")
            return result

        # Check for required strings (case-insensitive for Rich console compatibility)
        if check_contains:
            for s in check_contains:
                # Check both exact match and case-insensitive match
                if s not in result.stdout and s.lower() not in result.stdout.lower():
                    print(f"FAIL: Expected '{s}' not found in output")
                    print(f"OUTPUT:\n{result.stdout[:500]}...")
                    self.failed += 1
                    self.errors.append(f"{desc}: '{s}' not in output")
                    return result

        # Check for excluded strings
        if check_not_contains:
            for s in check_not_contains:
                if s in result.stdout:
                    print(f"FAIL: Unexpected '{s}' found in output")
                    self.failed += 1
                    self.errors.append(f"{desc}: unexpected '{s}' in output")
                    return result

        print("PASS")
        self.passed += 1
        return result

    def summary(self) -> int:
        """Print test summary and return exit code."""
        print(f"\n{'=' * 60}")
        print("INTEGRATION TEST SUMMARY")
        print("=" * 60)
        print(f"Passed: {self.passed}")
        print(f"Failed: {self.failed}")

        if self.errors:
            print("\nFailures:")
            for err in self.errors:
                print(f"  - {err}")
            return 1

        print("\nAll integration tests passed!")
        return 0


def check_environment() -> bool:
    """Verify the test environment is correctly configured."""
    # Warn if JAC_DISABLED_PLUGINS is set
    if os.environ.get("JAC_DISABLED_PLUGINS"):
        print(
            "WARNING: JAC_DISABLED_PLUGINS is set. Integration tests require all plugins."
        )
        print("         Unsetting JAC_DISABLED_PLUGINS for this test run.")
        os.environ.pop("JAC_DISABLED_PLUGINS", None)

    # Check jac is available
    result = subprocess.run(["jac", "--version"], capture_output=True, text=True)
    if result.returncode != 0:
        print("ERROR: 'jac' command not found. Please install jaclang first.")
        return False

    print(f"Jac version: {result.stdout.strip()}")
    return True


def run_plugin_tests(runner: IntegrationTestRunner) -> None:
    """Test the jac plugins command and plugin system."""

    # Test: jac plugins list runs successfully with expected structure
    runner.run(
        ["jac", "plugins", "list"],
        check_contains=[
            "Installed Jac plugins",
            "jaclang (built-in)",
            "jaclang:JacRuntimeInterfaceImpl",  # Core plugin with qualified name
        ],
        description="jac plugins list shows installed plugins with qualified names",
    )

    # Test: jac-client plugin is loaded with qualified names
    runner.run(
        ["jac", "plugins", "list"],
        check_contains=[
            "jac-client",  # Package name in output
            "jac-client:serve",  # Qualified plugin name format
        ],
        description="jac-client plugins use qualified name format",
    )

    # Test: jac-scale plugin is loaded with qualified names (optional - only if installed)
    result = subprocess.run(["jac", "plugins", "list"], capture_output=True, text=True)
    if "jac-scale" in result.stdout:
        runner.run(
            ["jac", "plugins", "list"],
            check_contains=[
                "jac-scale",  # Package name in output
                "jac-scale:scale",  # Qualified plugin name format
            ],
            description="jac-scale plugins use qualified name format",
        )
    else:
        print("\n" + "=" * 60)
        print("SKIP: jac-scale plugins test (plugin not installed)")
        print("=" * 60)

    # Test: byllm plugin is loaded with qualified names (optional - only if installed)
    if "byllm" in result.stdout:
        runner.run(
            ["jac", "plugins", "list"],
            check_contains=[
                "byllm",  # Package name in output
                "byllm:byllm",  # Qualified plugin name format
            ],
            description="byllm plugins use qualified name format",
        )
    else:
        print("\n" + "=" * 60)
        print("SKIP: byllm plugins test (plugin not installed)")
        print("=" * 60)

    # Test: Plugin commands are registered and associated with packages (optional)
    # Only check if plugins with commands are installed
    if "Commands:" in result.stdout or "💻" in result.stdout:
        runner.run(
            ["jac", "plugins", "list"],
            check_contains=["Commands:"],
            description="Plugin commands are shown in plugins list",
        )
    else:
        print("\n" + "=" * 60)
        print("SKIP: Plugin commands test (no plugins with commands installed)")
        print("=" * 60)

    # Test: jac --help shows plugin commands (depends on which plugins are installed)
    # Check for at least some common commands that should exist
    runner.run(
        ["jac", "--help"],
        check_contains=["create"],  # create is from jac-client which is installed
        description="jac --help shows plugin commands (create)",
    )

    # Test: Verbose mode works
    runner.run(
        ["jac", "plugins", "list", "--verbose"],
        check_contains=["Class:", "Module:"],
        description="jac plugins list --verbose shows detailed info",
    )

    # Test: jac plugins disabled shows no disabled plugins by default
    runner.run(
        ["jac", "plugins", "disabled"],
        check_contains=["No plugins are currently disabled"],
        description="jac plugins disabled shows no disabled by default",
    )


def run_cli_tests(runner: IntegrationTestRunner) -> None:
    """Test basic CLI functionality."""

    # Test: jac --version works
    # Note: New Rich console shows "Version:" in ASCII art format
    runner.run(
        ["jac", "--version"],
        check_contains=["Version:"],
        description="jac --version shows version",
    )

    # Test: jac check works on a simple file
    runner.run(
        [
            "jac",
            "check",
            "jac/tests/compiler/passes/main/fixtures/checker_type_ref.jac",
        ],
        description="jac check runs on test fixture",
    )


def main() -> int:
    """Run all integration tests."""
    print("=" * 60)
    print("JAC INTEGRATION TESTS")
    print("Testing full plugin ecosystem")
    print("=" * 60)

    if not check_environment():
        return 1

    runner = IntegrationTestRunner()

    # Run test suites
    run_plugin_tests(runner)
    run_cli_tests(runner)

    return runner.summary()


if __name__ == "__main__":
    sys.exit(main())
