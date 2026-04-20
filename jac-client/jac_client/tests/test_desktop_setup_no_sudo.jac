"""Validates that `jac setup desktop` prints platform-specific install
hints for every required dependency.

Removing an auto-installer without leaving a hint strands the user. This
test asserts each expected install command is present in the generator
source so the user always has something actionable to copy.
"""

import from pathlib { Path }

glob _desktop_target_impl_path = Path(__file__).parent.parent / "plugin" / "src" / "targets" / "impl" / "desktop_target.impl.jac";


test "setup desktop prints install hints for every platform" {
    assert _desktop_target_impl_path.exists();
    content = _desktop_target_impl_path.read_text();

    expected_hints = [
        # Rust toolchain
        "https://sh.rustup.rs",
        "winget install Rustlang.Rustup",
        # Linux build tools
        "sudo apt-get update && sudo apt-get install -y build-essential",
        "sudo dnf install -y gcc gcc-c++",
        "sudo pacman -S --noconfirm base-devel",
        # Linux webkit/gtk system deps
        "sudo apt-get install libwebkit2gtk-4.1-dev",
        "sudo dnf install webkit2gtk3-devel",
        "sudo pacman -S webkit2gtk base-devel",
        # macOS
        "xcode-select --install",
        # Windows
        "Microsoft.VisualStudio.2022.BuildTools"
    ];
    for hint in expected_hints {
        assert hint in content , (
            f"Expected install hint missing from setup generator: {hint!r}"
        );
    }

    # Every hint helper must point the user back to re-run setup.
    assert "Re-run `jac setup desktop`" in content , (
        "Install hints should tell the user to re-run `jac setup desktop` after installation"
    );
}
