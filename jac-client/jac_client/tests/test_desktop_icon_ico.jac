"""Tests for platform icon generation in the desktop build pipeline.

Validates that _generate_default_icons calls _generate_platform_icons to
produce .ico (Windows), .icns (macOS), and standard PNG sizes (Linux).
"""

import from pathlib { Path }

glob _plugin_src = Path(__file__).parent.parent / "plugin" / "src",
     _desktop_target_impl_path = _plugin_src / "targets" / "impl" / "desktop_target.impl.jac";


test "generate default icons calls platform icon generator" {
    assert _desktop_target_impl_path.exists();

    content = _desktop_target_impl_path.read_text();

    # Isolate _generate_default_icons body.
    start = content.index("def _generate_default_icons");
    end = content.find("\ndef ", start + 10);
    assert end != -1 , "Could not find end of _generate_default_icons";
    section = content[start:end];

    assert "_generate_platform_icons(icons_dir)" in section , (
        "_generate_default_icons should call _generate_platform_icons"
    );
}


test "platform icon generator produces ico icns and png sizes" {
    content = _desktop_target_impl_path.read_text();

    assert "def _generate_platform_icons(" in content , (
        "_generate_platform_icons should be defined"
    );
    assert "def _generate_icons_with_pillow(" in content , (
        "_generate_icons_with_pillow helper should be defined"
    );

    # Isolate _generate_icons_with_pillow body.
    start = content.index("def _generate_icons_with_pillow(");
    end = content.find("\n}", start + 10);
    assert end != -1 , "Could not find end of _generate_icons_with_pillow";
    section = content[start:end];

    # Must produce all three platform formats.
    assert 'format="ICO"' in section , ("Should save icon.ico for Windows");
    assert 'format="ICNS"' in section , ("Should save icon.icns for macOS");
    assert '"128x128@2x.png"' in section , ("Should generate 128x128@2x.png for Tauri");
    assert '.convert("RGBA")' in section , (
        "Should convert source to RGBA before generating derivatives"
    );
}


test "platform icon generator has subprocess fallback" {
    content = _desktop_target_impl_path.read_text();

    start = content.index("def _generate_platform_icons(");
    end = content.find("\ndef ", start + 10);
    assert end != -1;
    section = content[start:end];

    # Subprocess fallback for when Pillow is in a different env.
    assert 'python_cmd = "python" if sys.platform == "win32" else "python3"' in section , (
        "Subprocess fallback should pick python vs python3 per platform"
    );
    assert 'format="ICO"' in section , ("Subprocess fallback should also generate ICO");
    assert 'format="ICNS"' in section , (
        "Subprocess fallback should also attempt ICNS"
    );
}
