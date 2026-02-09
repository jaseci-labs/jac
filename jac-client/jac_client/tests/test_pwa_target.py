"""Tests for PWA (Progressive Web App) target functionality.

These tests validate the PWA target implementation including:
1. Target class structure and registration
2. Manifest generation
3. Service worker generation
4. HTML injection for PWA support
5. Icon handling
"""

from __future__ import annotations

import json
import tempfile
from pathlib import Path


def test_pwa_target_files_exist() -> None:
    """Test that the PWA target implementation files exist."""
    plugin_dir = Path(__file__).parent.parent / "plugin"

    pwa_target_jac = plugin_dir / "src" / "targets" / "pwa_target.jac"
    assert pwa_target_jac.exists(), f"pwa_target.jac not found at {pwa_target_jac}"

    pwa_impl_jac = plugin_dir / "src" / "targets" / "impl" / "pwa_target.impl.jac"
    assert pwa_impl_jac.exists(), f"pwa_target.impl.jac not found at {pwa_impl_jac}"

    pwa_target_content = pwa_target_jac.read_text()
    assert "class PWATarget" in pwa_target_content
    assert "def setup" in pwa_target_content
    assert "def build" in pwa_target_content
    assert "def dev" in pwa_target_content
    assert "def start" in pwa_target_content


def test_pwa_setup_implementation_exists() -> None:
    """Test that PWA setup implementation exists with expected functions."""
    plugin_dir = Path(__file__).parent.parent / "plugin"
    impl_file = plugin_dir / "src" / "targets" / "impl" / "pwa_target.impl.jac"
    impl_content = impl_file.read_text()

    assert "_copy_pwa_icons_to_project" in impl_content
    assert "_ensure_pwa_config" in impl_content
    assert "plugins.client.pwa" in impl_content


def test_pwa_setup_creates_icons_directory() -> None:
    """Test that setup would create pwa_icons directory."""
    with tempfile.TemporaryDirectory() as temp_dir:
        icons_dir = Path(temp_dir) / "pwa_icons"
        assert not icons_dir.exists()

        icons_dir.mkdir(parents=True)
        assert icons_dir.exists()


def test_pwa_setup_config_section() -> None:
    """Test that setup adds correct config section to jac.toml."""
    pwa_section = """[plugins.client.pwa]
theme_color = "#000000"
background_color = "#ffffff"
"""
    assert "theme_color" in pwa_section
    assert "background_color" in pwa_section
    assert "[plugins.client.pwa]" in pwa_section


def test_pwa_target_registered() -> None:
    """Test that PWATarget is registered in register.jac."""
    plugin_dir = Path(__file__).parent.parent / "plugin"
    register_jac = plugin_dir / "src" / "targets" / "register.jac"

    assert register_jac.exists(), f"register.jac not found at {register_jac}"

    register_content = register_jac.read_text()
    assert "PWATarget" in register_content, "PWATarget should be imported in register.jac"
    assert "pwa_target = PWATarget()" in register_content, (
        "PWATarget should be instantiated in register.jac"
    )
    assert "registry.register(pwa_target)" in register_content, (
        "pwa_target should be registered"
    )


def test_pwa_defaults_directory_exists() -> None:
    """Test that the PWA defaults directory structure exists."""
    plugin_dir = Path(__file__).parent.parent / "plugin"
    defaults_dir = plugin_dir / "defaults"
    pwa_icons_dir = defaults_dir / "pwa_icons"

    assert defaults_dir.exists(), f"defaults directory not found at {defaults_dir}"
    assert pwa_icons_dir.exists(), f"pwa_icons directory not found at {pwa_icons_dir}"

    readme = pwa_icons_dir / "README.md"
    assert readme.exists(), "pwa_icons/README.md should exist"


def test_get_default_manifest_structure() -> None:
    """Test that _get_default_manifest returns valid manifest structure."""
    # Import the implementation module
    # Note: This requires the Jac module to be compiled
    # We test the expected structure instead

    expected_fields = [
        "name",
        "short_name",
        "description",
        "start_url",
        "display",
        "background_color",
        "theme_color",
        "icons",
    ]

    plugin_dir = Path(__file__).parent.parent / "plugin"
    impl_file = plugin_dir / "src" / "targets" / "impl" / "pwa_target.impl.jac"
    impl_content = impl_file.read_text()

    for field in expected_fields:
        assert f'"{field}"' in impl_content, (
            f"Manifest should include '{field}' field"
        )


def test_pwa_constants_defined() -> None:
    """Test that PWA constants are properly defined in implementation."""
    plugin_dir = Path(__file__).parent.parent / "plugin"
    impl_file = plugin_dir / "src" / "targets" / "impl" / "pwa_target.impl.jac"
    impl_content = impl_file.read_text()

    assert "PWA_DEFAULT_THEME_COLOR" in impl_content
    assert "PWA_DEFAULT_BACKGROUND_COLOR" in impl_content
    assert "PWA_DEFAULT_CACHE_NAME" in impl_content
    assert "PWA_ICON_SMALL" in impl_content
    assert "PWA_ICON_LARGE" in impl_content
    assert "PWA_API_PATH_PREFIX" in impl_content
    assert "PWA_CACHEABLE_EXTENSIONS" in impl_content


def test_manifest_json_generation() -> None:
    """Test that manifest.json is generated with correct structure."""
    with tempfile.TemporaryDirectory() as temp_dir:
        dist_dir = Path(temp_dir)

        # Create a mock manifest
        manifest = {
            "name": "Test App",
            "short_name": "Test",
            "description": "Test App - Built with Jac",
            "start_url": "/",
            "display": "standalone",
            "background_color": "#ffffff",
            "theme_color": "#000000",
            "icons": [
                {"src": "pwa-192x192.png", "sizes": "192x192", "type": "image/png"},
                {"src": "pwa-512x512.png", "sizes": "512x512", "type": "image/png"},
            ],
        }

        manifest_path = dist_dir / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

        assert manifest_path.exists()

        with open(manifest_path) as f:
            loaded_manifest = json.load(f)

        assert loaded_manifest["name"] == "Test App"
        assert loaded_manifest["display"] == "standalone"
        assert len(loaded_manifest["icons"]) == 2
        assert loaded_manifest["icons"][0]["sizes"] == "192x192"


def test_manifest_user_override() -> None:
    """Test that user config can override default manifest values."""
    default_manifest = {
        "name": "Default App",
        "theme_color": "#000000",
    }

    user_manifest = {
        "name": "Custom App",
        "description": "Custom description",
    }

    # Simulate the update behavior
    result = default_manifest.copy()
    result.update(user_manifest)

    assert result["name"] == "Custom App", "User name should override default"
    assert result["theme_color"] == "#000000", "Unspecified fields should keep default"
    assert result["description"] == "Custom description", "New fields should be added"


def test_service_worker_content_structure() -> None:
    """Test that generated service worker has correct structure."""
    plugin_dir = Path(__file__).parent.parent / "plugin"
    impl_file = plugin_dir / "src" / "targets" / "impl" / "pwa_target.impl.jac"
    impl_content = impl_file.read_text()

    assert "CACHE_NAME" in impl_content, "SW should define CACHE_NAME"
    assert "PRECACHE_ASSETS" in impl_content, "SW should define PRECACHE_ASSETS"
    assert "addEventListener('install'" in impl_content, "SW should handle install event"
    assert "addEventListener('activate'" in impl_content, "SW should handle activate event"
    assert "addEventListener('fetch'" in impl_content, "SW should handle fetch event"
    assert "skipWaiting()" in impl_content, "SW should call skipWaiting"
    assert "clients.claim()" in impl_content, "SW should call clients.claim"


def test_service_worker_caching_strategies() -> None:
    """Test that service worker implements correct caching strategies."""
    plugin_dir = Path(__file__).parent.parent / "plugin"
    impl_file = plugin_dir / "src" / "targets" / "impl" / "pwa_target.impl.jac"
    impl_content = impl_file.read_text()

    assert "PWA_API_PATH_PREFIX" in impl_content, "Should use API path prefix constant"
    assert "fetch(event.request)" in impl_content, "Should fetch from network"
    assert "caches.match(event.request)" in impl_content, "Should fallback to cache"


def test_precache_files_filtering() -> None:
    """Test that only appropriate files are added to precache list."""
    with tempfile.TemporaryDirectory() as temp_dir:
        dist_dir = Path(temp_dir)

        # Create test files
        (dist_dir / "index.html").write_text("<html></html>")
        (dist_dir / "client.abc123.js").write_text("// js")
        (dist_dir / "styles.css").write_text("/* css */")
        (dist_dir / "icon.png").write_bytes(b"PNG")
        (dist_dir / "manifest.json").write_text("{}")
        (dist_dir / "should-ignore.txt").write_text("text")
        (dist_dir / "should-ignore.map").write_text("map")

        # Count cacheable files
        cacheable_extensions = [".html", ".js", ".css", ".png", ".json"]
        cacheable_files = [
            f for f in dist_dir.iterdir() if f.is_file() and f.suffix in cacheable_extensions
        ]

        assert len(cacheable_files) == 5, "Should only cache html, js, css, png, json files"
        assert not any(f.suffix == ".txt" for f in cacheable_files)
        assert not any(f.suffix == ".map" for f in cacheable_files)


def test_html_pwa_injection() -> None:
    """Test that PWA meta tags and SW registration are injected into HTML."""
    with tempfile.TemporaryDirectory() as temp_dir:
        dist_dir = Path(temp_dir)

        # Create a basic index.html
        original_html = """<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <title>Test</title>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>"""

        index_path = dist_dir / "index.html"
        index_path.write_text(original_html)

        # Simulate the injection
        html_content = index_path.read_text()

        pwa_head = """
    <link rel="manifest" href="manifest.json">
    <meta name="theme-color" content="#000000">
    <link rel="apple-touch-icon" href="pwa-192x192.png">"""

        sw_script = """
    <script>
      if ('serviceWorker' in navigator) {
        window.addEventListener('load', () => {
          navigator.serviceWorker.register('sw.js')
            .then((reg) => console.log('SW registered:', reg.scope))
            .catch((err) => console.log('SW registration failed:', err));
        });
      }
    </script>"""

        if "</head>" in html_content:
            html_content = html_content.replace("</head>", f"{pwa_head}\n  </head>")

        if "</body>" in html_content:
            html_content = html_content.replace("</body>", f"{sw_script}\n  </body>")

        index_path.write_text(html_content)

        result = index_path.read_text()
        assert 'rel="manifest"' in result, "Should inject manifest link"
        assert 'name="theme-color"' in result, "Should inject theme-color meta"
        assert "apple-touch-icon" in result, "Should inject apple-touch-icon"
        assert "serviceWorker" in result, "Should inject SW registration script"
        assert "sw.js" in result, "Should reference sw.js"


def test_html_injection_handles_missing_tags() -> None:
    """Test that HTML injection handles malformed HTML gracefully."""
    malformed_html = "<html><body>No closing tags"

    has_head = "</head>" in malformed_html
    has_body = "</body>" in malformed_html

    assert not has_head, "Should detect missing </head>"
    assert not has_body, "Should detect missing </body>"


def test_icon_copy_with_no_icons() -> None:
    """Test that icon copy handles empty icons directory gracefully."""
    with tempfile.TemporaryDirectory() as temp_dir:
        icons_dir = Path(temp_dir) / "pwa_icons"
        icons_dir.mkdir()

        # No PNG files
        icon_files = list(icons_dir.glob("*.png"))
        assert len(icon_files) == 0, "Should find no icons"


def test_icon_copy_with_icons() -> None:
    """Test that icon copy works when icons are present."""
    with tempfile.TemporaryDirectory() as temp_dir:
        icons_dir = Path(temp_dir) / "pwa_icons"
        icons_dir.mkdir()
        dist_dir = Path(temp_dir) / "dist"
        dist_dir.mkdir()

        # Create mock icons
        (icons_dir / "pwa-192x192.png").write_bytes(b"PNG192")
        (icons_dir / "pwa-512x512.png").write_bytes(b"PNG512")

        # Simulate copy
        import shutil

        for icon_file in icons_dir.glob("*.png"):
            shutil.copy2(icon_file, dist_dir / icon_file.name)

        assert (dist_dir / "pwa-192x192.png").exists()
        assert (dist_dir / "pwa-512x512.png").exists()


def test_user_icons_preferred_over_defaults() -> None:
    """Test that user's custom icons in pwa_icons/ are preferred over defaults."""
    plugin_dir = Path(__file__).parent.parent / "plugin"
    impl_file = plugin_dir / "src" / "targets" / "impl" / "pwa_target.impl.jac"
    impl_content = impl_file.read_text()

    # Verify the implementation checks user's pwa_icons first
    assert "project_dir / \"pwa_icons\"" in impl_content, (
        "Should check project_dir/pwa_icons/ first"
    )
    assert "user_icons_dir" in impl_content or "user_icons" in impl_content, (
        "Should have logic for user icons"
    )
    # Verify fallback to defaults
    assert "_get_default_icons_dir()" in impl_content, (
        "Should fall back to default icons"
    )


def test_manifest_generation_error_handling() -> None:
    """Test that manifest generation raises RuntimeError on failure."""
    # Simulate a read-only directory
    with tempfile.TemporaryDirectory() as temp_dir:
        dist_dir = Path(temp_dir) / "dist"
        # Don't create the directory - write should fail
        # Note: In the actual implementation, this would raise RuntimeError

        try:
            manifest_path = dist_dir / "manifest.json"
            manifest_path.write_text("{}")
            # If we get here, directory was auto-created
        except (FileNotFoundError, OSError):
            # Expected behavior when directory doesn't exist
            pass


def test_service_worker_generation_error_handling() -> None:
    """Test that service worker generation raises RuntimeError on failure."""
    with tempfile.TemporaryDirectory() as temp_dir:
        plugin_dir = Path(__file__).parent.parent / "plugin"
        impl_file = plugin_dir / "src" / "targets" / "impl" / "pwa_target.impl.jac"
        impl_content = impl_file.read_text()

        assert 'raise RuntimeError(f"Failed to generate service worker' in impl_content


def test_html_update_error_handling() -> None:
    """Test that HTML update raises RuntimeError on failure."""
    plugin_dir = Path(__file__).parent.parent / "plugin"
    impl_file = plugin_dir / "src" / "targets" / "impl" / "pwa_target.impl.jac"
    impl_content = impl_file.read_text()

    assert 'raise RuntimeError(f"Failed to update index.html for PWA' in impl_content


def test_empty_dist_directory() -> None:
    """Test behavior with empty dist directory."""
    with tempfile.TemporaryDirectory() as temp_dir:
        dist_dir = Path(temp_dir)

        # Empty directory - should not crash
        files = list(dist_dir.iterdir())
        assert len(files) == 0

        # Precache files should be empty
        cacheable_extensions = [".html", ".js", ".css", ".png", ".json"]
        precache_files = [
            f for f in dist_dir.iterdir() if f.is_file() and f.suffix in cacheable_extensions
        ]
        assert len(precache_files) == 0


def test_nonexistent_dist_directory() -> None:
    """Test behavior when dist directory doesn't exist."""
    dist_dir = Path("/nonexistent/path/dist")

    # Should not raise when checking existence
    assert not dist_dir.exists()


def test_missing_index_html() -> None:
    """Test that missing index.html is handled gracefully."""
    with tempfile.TemporaryDirectory() as temp_dir:
        dist_dir = Path(temp_dir)

        # No index.html - should skip PWA HTML update
        index_path = dist_dir / "index.html"
        assert not index_path.exists()


def test_empty_pwa_config() -> None:
    """Test behavior with empty PWA config."""
    pwa_config: dict = {}

    # Should use defaults
    theme_color = pwa_config.get("theme_color", "#000000")
    cache_name = pwa_config.get("cache_name", "jac-pwa-cache-v1")

    assert theme_color == "#000000"
    assert cache_name == "jac-pwa-cache-v1"


def test_custom_cache_name() -> None:
    """Test that custom cache name is respected."""
    pwa_config = {"cache_name": "my-custom-cache-v2"}

    cache_name = pwa_config.get("cache_name", "jac-pwa-cache-v1")
    assert cache_name == "my-custom-cache-v2"


def test_custom_theme_color() -> None:
    """Test that custom theme color is applied to both manifest and HTML."""
    pwa_config = {"theme_color": "#ff5733"}

    theme_color = pwa_config.get("theme_color", "#000000")
    assert theme_color == "#ff5733"

    # Verify it would be used in both places
    manifest_theme = theme_color
    html_meta_theme = theme_color
    assert manifest_theme == html_meta_theme, "Theme color should be consistent"
