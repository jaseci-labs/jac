"""Tests for Windows ICO generation in the desktop icon pipeline.

Validates that _generate_default_icons calls _generate_ico_from_png, that
the helper exists, and that its subprocess fallback picks the right Python
command per platform.
"""

import re;
import from pathlib { Path }

glob _plugin_src = Path(__file__).parent.parent / "plugin" / "src",
     _desktop_target_impl_path = _plugin_src / "targets" / "impl" / "desktop_target.impl.jac";


test "generate default icons also produces windows ico" {
    assert _desktop_target_impl_path.exists();

    content = _desktop_target_impl_path.read_text();

    # Isolate the _generate_default_icons function body so we don't match
    # other call sites.
    start = content.index("def _generate_default_icons");
    end = content.find("\ndef ", start + 10);
    assert end != -1 , "Could not find end of _generate_default_icons";
    section = content[start:end];

    assert "_generate_ico_from_png(icons_dir)" in section , (
        "_generate_default_icons should call _generate_ico_from_png(icons_dir) "
        "so Tauri's Windows bundler has an icon.ico to ship"
    );
}


test "ico helper exists and uses correct python per platform" {
    content = _desktop_target_impl_path.read_text();

    # The helper itself must exist.
    assert "def _generate_ico_from_png(" in content , (
        "_generate_ico_from_png helper should be defined"
    );

    # Isolate the helper body.
    start = content.index("def _generate_ico_from_png(");
    end = content.find("\ndef ", start + 10);
    assert end != -1 , "Could not find end of _generate_ico_from_png";
    section = content[start:end];

    # Tries Pillow in-process first (fast path, clearer errors).
    assert "from PIL {Image}" in section or "from PIL import Image" in section , (
        "ICO helper should try PIL in-process first"
    );

    # The subprocess fallback must pick 'python' on Windows and 'python3'
    # elsewhere: /usr/bin/python on old Unix systems is often Python 2, and
    # the Windows py launcher exposes only 'python'.
    assert 'python_cmd = "python" if sys.platform == "win32" else "python3"' in section , (
        "ICO subprocess fallback should select python vs python3 per platform"
    );

    # Writes icon.ico with multiple Windows sizes.
    assert '(256, 256)' in section and '(16, 16)' in section , (
        "ICO output should include standard Windows icon sizes"
    );
    assert 'format="ICO"' in section , (
        "ICO helper should save with format='ICO'"
    );
}
