"""Test [desktop.bundle] extra_data support in the PyInstaller spec.

Validates that the generated spec reads extra_data glob patterns from jac.toml
and appends matching files to the PyInstaller datas list.
"""

import from pathlib { Path }

glob _plugin_src = Path(__file__).parent.parent / "plugin" / "src",
     _desktop_target_impl_path = _plugin_src / "targets" / "impl" / "desktop_target.impl.jac";


test "spec template reads desktop bundle extra_data from jac_toml" {
    assert _desktop_target_impl_path.exists();

    content = _desktop_target_impl_path.read_text();

    # The spec template must reach under [desktop][bundle][extra_data].
    assert "toml_data.get('desktop'" in content , (
        "Spec template should read the [desktop] table from jac.toml"
    );
    assert "desktop_cfg.get('bundle'" in content , (
        "Spec template should read the [desktop.bundle] sub-table"
    );
    assert "bundle_cfg.get('extra_data'" in content , (
        "Spec template should read extra_data from [desktop.bundle]"
    );

    # Each pattern is evaluated as a glob rooted at the project directory.
    assert "project_dir.glob(pattern)" in content , (
        "extra_data patterns must be evaluated as globs rooted at project_dir"
    );

    # Matches are added to PyInstaller's datas list preserving their relative
    # path so runtime code like Path(__file__).parent / 'foo' still resolves.
    assert "datas.append((str(match), str(rel.parent) or '.'))" in content , (
        "Matched files should be appended to PyInstaller datas with their "
        "relative parent directory as the destination"
    );
}
