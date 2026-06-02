"""Test [plugins.desktop.bundle] extra_data support in the PyInstaller spec."""

import from _helpers { _DESKTOP_HELPERS_IMPL }

test "spec template reads desktop bundle extra_data from jac_toml" {
    assert _DESKTOP_HELPERS_IMPL.exists();

    content = _DESKTOP_HELPERS_IMPL.read_text(encoding="utf-8");

    assert "plugins_section = toml_data.get('plugins'" in content , (
        "Spec template should read the [plugins] table from jac.toml"
    );
    assert "desktop_cfg = plugins_section.get('desktop'" in content , (
        "Spec template should read the [plugins.desktop] sub-table"
    );
    assert "bundle_cfg.get('extra_data'" in content , (
        "Spec template should read extra_data from [plugins.desktop.bundle]"
    );
    assert "project_dir.glob(pattern)" in content , (
        "extra_data patterns must be evaluated as globs rooted at project_dir"
    );
    assert "datas.append((str(match), str(rel.parent) or '.'))" in content , (
        "Matched files should be appended to PyInstaller datas with their "
        "relative parent directory as the destination"
    );
}
