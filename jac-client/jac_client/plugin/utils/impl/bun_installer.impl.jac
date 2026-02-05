"""Implementation of Bun installer utility."""

"""Check if bun is available, add to PATH if needed, or prompt to install."""
impl ensure_bun_available -> bool {
    import os;
    import shutil;
    # Check if bun is already in PATH
    if shutil.which("bun") {
        return True;
    }
    # Check if bun exists at ~/.bun/bin but not in PATH
    bun_bin = os.path.expanduser("~/.bun/bin");
    bun_path = os.path.join(bun_bin, "bun");
    if os.path.exists(bun_path) {
        # Add to PATH for current process
        current_path = os.environ.get("PATH", "");
        os.environ["PATH"] = f"{bun_bin}:{current_path}";
        return True;
    }
    # Bun not found - prompt to install
    return prompt_install_bun();
}

"""Prompt user to install Bun and install if confirmed."""
impl prompt_install_bun -> bool {
    import os;
    import subprocess;
    import sys;
    import shutil;
    import from jaclang.cli.console { console }
    console.error("\n  ⚠ Bun is required but not installed.");
    console.error(
        "  Bun is a fast JavaScript runtime used for package management and bundling."
    );
    console.error("  Learn more: https://bun.sh\n");
    try {
        response = input("  Install Bun now? [Y/n]: ").strip().lower();
    } except (EOFError, KeyboardInterrupt) {
        console.error("");
        return False;
    }
    if response and response not in ('y', 'yes', '') {
        return False;
    }
    console.print("\n  ⏳ Installing Bun...");
    try {
        # Check if curl is available
        subprocess.run(
            ["curl", "--version"], capture_output=True, check=True, timeout=5
        );

        # Install Bun via official script
        result = subprocess.run(
            ["sh", "-c", "curl -fsSL https://bun.sh/install | bash"],
            timeout=120,
            check=False
        );

        if result.returncode == 0 {
            console.print("  ✔ Bun installed successfully!");
            # Add Bun to PATH for current session
            bun_bin = os.path.expanduser("~/.bun/bin");
            if os.path.exists(bun_bin) {
                current_path = os.environ.get("PATH", "");
                os.environ["PATH"] = f"{bun_bin}:{current_path}";
                # Verify installation
                if shutil.which("bun") {
                    verify = subprocess.run(
                        ["bun", "--version"], capture_output=True, text=True
                    );
                    if verify.returncode == 0 {
                        console.print(f"  ✔ Verified: Bun {verify.stdout.strip()}");
                        return True;
                    }
                }
            }
            console.error("  ⚠ Bun installed but may require terminal restart.");
            console.error("  Run: source ~/.bashrc (or restart terminal)");
            return True;
        } else {
            console.error("  ✖ Bun installation failed.");
            return False;
        }
    } except subprocess.TimeoutExpired {
        console.error("  ✖ Installation timed out.");
        return False;
    } except FileNotFoundError {
        console.error(
            "  ✖ curl not found. Please install Bun manually: https://bun.sh"
        );
        return False;
    } except Exception as e {
        console.error(f"  ✖ Installation failed: {e}");
        return False;
    }
}
