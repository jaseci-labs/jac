"""Assert `jac setup desktop` prints install hints for every supported platform."""

import from pathlib { Path }

glob _desktop_target_impl_path = Path(__file__).parent.parent / "plugin" / "src" / "targets" / "impl" / "desktop_target.impl.jac";


test "setup desktop prints install hints for every platform" {
    content = _desktop_target_impl_path.read_text();

    expected_hints = [
        "https://sh.rustup.rs",
        "winget install Rustlang.Rustup",
        "sudo apt-get update && sudo apt-get install -y build-essential",
        "sudo dnf install -y gcc gcc-c++",
        "sudo pacman -S --noconfirm base-devel",
        "sudo apt-get install libwebkit2gtk-4.1-dev",
        "sudo dnf install webkit2gtk3-devel",
        "sudo pacman -S webkit2gtk base-devel",
        "xcode-select --install",
        "Microsoft.VisualStudio.2022.BuildTools"
    ];
    for hint in expected_hints {
        assert hint in content , f"Missing install hint: {hint!r}";
    }

    assert "Re-run `jac setup desktop`" in content;
}
