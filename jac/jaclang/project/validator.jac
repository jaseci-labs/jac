"""Package manifest validator for jac.toml.

Validates the [package], [dependencies], [entrypoints], and
[optional-dependencies] sections required for jac publish / jac install.
"""

import from pathlib { Path }
import from jaclang.project.config { JacConfig }

"""Holds validation errors and warnings produced by validate_package."""
obj ValidationResult {
    has errors: list[str] = [],
        warnings: list[str] = [];

    def is_valid -> bool;
    def add_error(msg: str) -> None;
    def add_warning(msg: str) -> None;
}

"""Validate the [package], dependencies, and entrypoints sections of a JacConfig; return a ValidationResult."""
def validate_package(
    config: JacConfig, project_root: Path | None = None
) -> ValidationResult;
