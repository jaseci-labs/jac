"""Assert PyTauri setup guides users to install pytauri-wheel (no Rust toolchain)."""

import from _helpers { _PYTAURI_TARGET_IMPL }

test "setup desktop mentions pytauri wheel not rust toolchain" {
    content = _PYTAURI_TARGET_IMPL.read_text(encoding="utf-8");

    assert "pip install pytauri-wheel" in content , (
        "Setup should tell users to install pytauri-wheel"
    );
    assert "pytauri-wheel importable" in content , (
        "Setup should verify pytauri-wheel is importable"
    );
    assert "sh.rustup.rs" not in content , "PyTauri setup should not require Rust";
    assert "cargo install tauri-cli" not in content , (
        "PyTauri setup should not require cargo tauri"
    );
    assert "PyTauri desktop target setup complete" in content , (
        "Setup should print a completion message"
    );
}
