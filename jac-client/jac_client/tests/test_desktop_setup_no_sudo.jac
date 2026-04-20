"""Tests that `jac setup desktop` does not invoke sudo-based package
installs, pipe curl installers to sh, or auto-invoke xcode-select --install.

Policy: `jac setup desktop` detects missing system dependencies and prints
platform-specific install commands; the user runs those commands themselves.
This test locks the policy in by scanning the generator source for forbidden
invocations while asserting that the detection and instruction surfaces are
still present.
"""

import from pathlib { Path }

glob _desktop_target_impl_path = Path(__file__).parent.parent / "plugin" / "src" / "targets" / "impl" / "desktop_target.impl.jac";


test "setup desktop does not invoke sudo package managers" {
    assert _desktop_target_impl_path.exists();

    content = _desktop_target_impl_path.read_text();

    # No subprocess.run call should pass a sudo-based install command. The
    # sudo-prefixed strings that remain must be inside console.print / hint
    # messages ONLY -- never the first element of a subprocess argv list.
    forbidden_argv_fragments = [
        '["sudo", "apt-get", "install"',
        '["sudo", "apt-get", "update"',
        '["sudo", "dnf", "install"',
        '["sudo", "pacman", "-S"'
    ];
    for frag in forbidden_argv_fragments {
        assert frag not in content , (
            f"Forbidden sudo install argv fragment still present: {frag}. "
            "jac setup desktop must not run sudo commands -- print instructions instead."
        );
    }
}


test "setup desktop does not pipe curl to sh for rustup" {
    content = _desktop_target_impl_path.read_text();

    # The rustup installer command may appear inside a printed hint, but it
    # must not be the body of a subprocess.run(["sh", "-c", ...]) call.
    forbidden = 'curl --proto \'=https\' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y';
    assert forbidden not in content , (
        "Found the rustup `curl | sh` pipe used as a subprocess payload. "
        "That was the auto-installer; it should only appear in printed hints."
    );

    # The caller must never invoke `sh -c` with a curl-to-rustup payload.
    assert 'subprocess.run(\n                    [\n                        "sh",\n                        "-c"' not in content , (
        "Found a subprocess invocation that shells out to pipe an installer script. "
        "Print the command and let the user run it themselves."
    );
}


test "setup desktop does not auto-invoke xcode-select --install" {
    content = _desktop_target_impl_path.read_text();

    # `xcode-select -p` is fine (that's detection). What we forbid is
    # `subprocess.run(["xcode-select", "--install"], ...)` which triggers
    # Apple's installer dialog without explicit user opt-in.
    assert 'subprocess.run(["xcode-select", "--install"]' not in content , (
        "Found auto-invoke of xcode-select --install. The install command "
        "must be printed as a hint; the user runs it."
    );

    # And there must be no 'Open installer? [Y/n]' prompt -- that was part
    # of the same interactive auto-install flow.
    assert "Open installer?" not in content , (
        "Found 'Open installer?' prompt -- interactive auto-install was removed."
    );
}


test "setup desktop still prints platform install hints" {
    content = _desktop_target_impl_path.read_text();

    # Removing auto-install without adding instructions would leave users
    # stranded. These anchor strings confirm each platform still gets a hint.
    expected_hints = [
        # Linux webkit/gtk deps
        "sudo apt-get install libwebkit2gtk-4.1-dev",
        "sudo dnf install webkit2gtk3-devel",
        "sudo pacman -S webkit2gtk base-devel",
        # Linux build tools
        "sudo apt-get update && sudo apt-get install -y build-essential",
        "sudo dnf install -y gcc gcc-c++",
        "sudo pacman -S --noconfirm base-devel",
        # Rust
        "https://sh.rustup.rs",
        "winget install Rustlang.Rustup",
        # Windows VS build tools
        "Microsoft.VisualStudio.2022.BuildTools",
        # macOS
        "xcode-select --install"
    ];
    for hint in expected_hints {
        assert hint in content , (
            f"Expected platform install hint missing from source: {hint!r}. "
            "Removing an auto-installer without leaving a hint strands the user."
        );
    }

    # And the helper that prints webkit hints must tell the user to re-run setup.
    assert "Re-run `jac setup desktop`" in content , (
        "Hints should point users back to `jac setup desktop` after install."
    );
}


test "old install-helper function names are gone" {
    content = _desktop_target_impl_path.read_text();

    # Renames (cosmetic, but double-check we updated all call sites).
    forbidden_defs = [
        "def _check_and_install_rust",
        "def _check_and_install_build_tools",
        "def _check_and_install_linux_dependencies",
        "def _try_install_linux_build_tools",
        "def _try_install_linux_system_deps"
    ];
    for d in forbidden_defs {
        assert d not in content , (
            f"Stale install-helper definition still present: {d!r}"
        );
    }

    # New entry points must be reachable from the orchestrator.
    expected_defs = [
        "def _check_dependencies",
        "def _check_rust",
        "def _check_build_tools",
        "def _check_linux_dependencies",
        "def _print_linux_build_tools_instructions"
    ];
    for d in expected_defs {
        assert d in content , (
            f"Expected renamed function missing: {d!r}"
        );
    }
}
