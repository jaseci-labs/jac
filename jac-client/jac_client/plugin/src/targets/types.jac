"""Core types for the client target system.

This module defines the fundamental types used across all build targets:
- ClientTargetType: Enum of available target platforms
- BuildContext: Shared state passed to all lifecycle methods
- BuildResult: Standardized result type for explicit error handling
"""
import from enum { StrEnum }
import from pathlib { Path }
import from typing { Any }

"""Enum of available client build targets.

Each target represents a platform that Jac applications can be built for.
"""
enum ClientTargetType ( StrEnum ) {
    WEB = "web",
    PWA = "pwa",
    DESKTOP = "desktop"
}

"""Build context containing all shared state for build operations.

This object is passed to all target lifecycle methods (setup, build, dev, start)
to provide consistent access to project configuration and build parameters.
"""
obj BuildContext {
    has target_type: ClientTargetType,
        entry_file: Path,
        project_dir: Path,
        config: Any,  # jaclang.project.config.ProjectConfig
        port: int = 8000,
        platform: str | None = None,  # windows, macos, linux, all (for desktop)
        dev_mode: bool = False,
        verbose: bool = False;

    """Create a BuildContext from CLI arguments and project config."""
    static def from_args(
        target_type: ClientTargetType,
        entry_file: Path,
        project_dir: Path,
        config: Any,
        port: int = 8000,
        platform: str | None = None,
        dev_mode: bool = False,
        verbose: bool = False
    ) -> BuildContext {
        return BuildContext(
            target_type=target_type,
            entry_file=entry_file,
            project_dir=project_dir,
            config=config,
            port=port,
            platform=platform,
            dev_mode=dev_mode,
            verbose=verbose
        );
    }

    """Get the output directory for build artifacts."""
    def get_output_dir -> Path {
        return self.project_dir / ".jac" / "client" / "dist";
    }
}

"""Result of a build operation with explicit success/error handling.

All target lifecycle methods return this type to provide consistent
error handling and output path reporting.
"""
obj BuildResult {
    has success: bool,
        output_path: Path | None = None,
        error: str | None = None,
        warnings: list[str] = [];

    """Create a successful result."""
    static def ok(output_path: Path | None = None) -> BuildResult {
        return BuildResult(success=True, output_path=output_path);
    }

    """Create a failed result with error message."""
    static def fail(error: str) -> BuildResult {
        return BuildResult(success=False, error=error);
    }

    """Create a result with warnings."""
    static def with_warnings(
        success: bool,
        warnings: list[str],
        output_path: Path | None = None,
        error: str | None = None
    ) -> BuildResult {
        return BuildResult(
            success=success,
            output_path=output_path,
            error=error,
            warnings=warnings
        );
    }

    """Check if the result has warnings."""
    def has_warnings -> bool {
        return len(self.warnings) > 0;
    }
}
