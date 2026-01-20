"""Tests for template bundling infrastructure."""

from __future__ import annotations

import json
from collections.abc import Callable
from pathlib import Path

import pytest


class TestBundleTemplate:
    """Tests for bundling templates from directory to .jacpack."""

    def test_bundle_creates_jacpac_file(
        self, temp_dir: Path, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that bundle_template creates a .jacpack file."""
        from jaclang.project.template_loader import bundle_template

        template_dir = Path(fixture_path("templates/minimal"))
        output_path = temp_dir / "minimal.jacpack"

        bundle_template(template_dir, output_path)

        assert output_path.exists()
        assert output_path.stat().st_size > 0

    def test_bundle_contains_required_fields(
        self, temp_dir: Path, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that bundled .jacpack contains all required fields."""
        from jaclang.project.template_loader import bundle_template

        template_dir = Path(fixture_path("templates/minimal"))
        output_path = temp_dir / "minimal.jacpack"

        bundle_template(template_dir, output_path)

        with open(output_path) as f:
            data = json.load(f)

        assert data["name"] == "minimal"
        assert data["description"] == "A minimal test template"
        assert "config" in data
        assert "files" in data
        assert "directories" in data
        assert "gitignore_entries" in data

    def test_bundle_includes_version_metadata(
        self, temp_dir: Path, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that bundled .jacpack includes jaclang and plugin versions."""
        from jaclang.project.template_loader import bundle_template

        template_dir = Path(fixture_path("templates/minimal"))
        output_path = temp_dir / "minimal.jacpack"

        bundle_template(template_dir, output_path)

        with open(output_path) as f:
            data = json.load(f)

        assert data["jaclang"] == "0.9.0"
        assert "plugins" in data
        assert len(data["plugins"]) == 1
        assert data["plugins"][0]["name"] == "test-plugin"
        assert data["plugins"][0]["version"] == "1.0.0"

    def test_bundle_embeds_file_contents(
        self, temp_dir: Path, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that bundled .jacpack embeds file contents correctly."""
        from jaclang.project.template_loader import bundle_template

        template_dir = Path(fixture_path("templates/minimal"))
        output_path = temp_dir / "minimal.jacpack"

        bundle_template(template_dir, output_path)

        with open(output_path) as f:
            data = json.load(f)

        assert "main.jac" in data["files"]
        assert "README.md" in data["files"]
        assert "{{name}}" in data["files"]["main.jac"]

    def test_bundle_missing_directory_raises(self, temp_dir: Path) -> None:
        """Test that bundling missing directory raises ValueError."""
        from jaclang.project.template_loader import bundle_template

        with pytest.raises(ValueError, match="Template directory not found"):
            bundle_template(temp_dir / "nonexistent", temp_dir / "out.jacpack")

    def test_bundle_missing_manifest_raises(self, temp_dir: Path) -> None:
        """Test that bundling without jac.toml raises ValueError."""
        from jaclang.project.template_loader import bundle_template

        empty_dir = temp_dir / "empty"
        empty_dir.mkdir()

        with pytest.raises(ValueError, match="No jac.toml found"):
            bundle_template(empty_dir, temp_dir / "out.jacpack")


class TestLoadTemplateFromJson:
    """Tests for loading templates from bundled .jacpack files."""

    def test_load_returns_project_template(
        self, temp_dir: Path, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that load_template_from_json returns ProjectTemplate."""
        from jaclang.project.template_loader import (
            bundle_template,
            load_template_from_json,
        )
        from jaclang.project.template_registry import ProjectTemplate

        template_dir = Path(fixture_path("templates/minimal"))
        jacpack_path = temp_dir / "minimal.jacpack"
        bundle_template(template_dir, jacpack_path)

        template = load_template_from_json(jacpack_path)

        assert isinstance(template, ProjectTemplate)
        assert template.name == "minimal"
        assert template.description == "A minimal test template"

    def test_load_preserves_files(
        self, temp_dir: Path, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that loaded template preserves file contents."""
        from jaclang.project.template_loader import (
            bundle_template,
            load_template_from_json,
        )

        template_dir = Path(fixture_path("templates/minimal"))
        jacpack_path = temp_dir / "minimal.jacpack"
        bundle_template(template_dir, jacpack_path)

        template = load_template_from_json(jacpack_path)

        assert "main.jac" in template.files
        assert "README.md" in template.files

    def test_load_missing_file_raises(self, temp_dir: Path) -> None:
        """Test that loading missing .jacpack raises ValueError."""
        from jaclang.project.template_loader import load_template_from_json

        with pytest.raises(ValueError, match="Template JSON not found"):
            load_template_from_json(temp_dir / "nonexistent.jacpack")


class TestLoadTemplateFromDirectory:
    """Tests for loading templates directly from directories."""

    def test_load_from_directory(self, fixture_path: Callable[[str], str]) -> None:
        """Test loading template directly from directory."""
        from jaclang.project.template_loader import load_template_from_directory
        from jaclang.project.template_registry import ProjectTemplate

        template_dir = Path(fixture_path("templates/minimal"))
        template = load_template_from_directory(template_dir)

        assert isinstance(template, ProjectTemplate)
        assert template.name == "minimal"

    def test_load_extracts_config(self, fixture_path: Callable[[str], str]) -> None:
        """Test that loaded template has correct config."""
        from jaclang.project.template_loader import load_template_from_directory

        template_dir = Path(fixture_path("templates/minimal"))
        template = load_template_from_directory(template_dir)

        assert "project" in template.config
        assert template.config["project"]["name"] == "{{name}}"
        assert template.config["project"]["entry-point"] == "main.jac"


class TestRoundTrip:
    """Tests for round-trip bundling and loading."""

    def test_round_trip_preserves_data(
        self, temp_dir: Path, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that bundle -> load preserves all template data."""
        from jaclang.project.template_loader import (
            bundle_template,
            load_template_from_directory,
            load_template_from_json,
        )

        template_dir = Path(fixture_path("templates/minimal"))
        jacpack_path = temp_dir / "minimal.jacpack"

        # Load directly
        original = load_template_from_directory(template_dir)

        # Bundle and reload
        bundle_template(template_dir, jacpack_path)
        loaded = load_template_from_json(jacpack_path)

        # Compare
        assert original.name == loaded.name
        assert original.description == loaded.description
        assert original.config == loaded.config
        assert original.files == loaded.files
        assert original.directories == loaded.directories
        assert original.gitignore_entries == loaded.gitignore_entries
        assert original.root_gitignore_entries == loaded.root_gitignore_entries


class TestProjectTemplateToDict:
    """Tests for ProjectTemplate.to_dict() serialization."""

    def test_to_dict_includes_all_fields(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that to_dict includes all template fields."""
        from jaclang.project.template_loader import load_template_from_directory

        template_dir = Path(fixture_path("templates/minimal"))
        template = load_template_from_directory(template_dir)

        data = template.to_dict()

        assert "name" in data
        assert "description" in data
        assert "config" in data
        assert "files" in data
        assert "directories" in data
        assert "gitignore_entries" in data
        assert "root_gitignore_entries" in data

    def test_to_dict_excludes_post_create(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that to_dict excludes non-serializable post_create."""
        from jaclang.project.template_loader import load_template_from_directory

        template_dir = Path(fixture_path("templates/minimal"))
        template = load_template_from_directory(template_dir)

        data = template.to_dict()

        # post_create is a callable, shouldn't be in dict
        assert "post_create" not in data


class TestTemplateRegistration:
    """Tests for template registration in the registry."""

    def test_register_template_from_dict(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test registering a template from dict representation."""
        from jaclang.project.template_loader import load_template_from_directory
        from jaclang.project.template_registry import (
            get_template_registry,
            initialize_template_registry,
        )

        initialize_template_registry()
        registry = get_template_registry()

        template_dir = Path(fixture_path("templates/minimal"))
        template = load_template_from_directory(template_dir)
        registry.register(template.to_dict())

        assert registry.has_template("minimal")

    def test_get_registered_template(self, fixture_path: Callable[[str], str]) -> None:
        """Test retrieving a registered template."""
        from jaclang.project.template_loader import load_template_from_directory
        from jaclang.project.template_registry import (
            get_template_registry,
            initialize_template_registry,
        )

        initialize_template_registry()
        registry = get_template_registry()

        template_dir = Path(fixture_path("templates/minimal"))
        template = load_template_from_directory(template_dir)
        registry.register(template.to_dict())

        retrieved = registry.get("minimal")
        assert retrieved is not None
        assert retrieved.name == "minimal"
        assert retrieved.description == "A minimal test template"

    def test_list_templates_includes_registered(
        self, fixture_path: Callable[[str], str]
    ) -> None:
        """Test that list_templates includes registered template."""
        from jaclang.project.template_loader import load_template_from_directory
        from jaclang.project.template_registry import (
            get_template_registry,
            initialize_template_registry,
        )

        initialize_template_registry()
        registry = get_template_registry()

        template_dir = Path(fixture_path("templates/minimal"))
        template = load_template_from_directory(template_dir)
        registry.register(template.to_dict())

        templates = registry.list_templates()
        names = [name for (name, _) in templates]
        assert "minimal" in names
