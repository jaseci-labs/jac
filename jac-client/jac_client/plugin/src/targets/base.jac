"""Base class for all client build targets.

This module defines the ClientTarget abstract base class that all build targets
(web, pwa, desktop, mobile) must inherit from and implement.
"""
import from pathlib { Path }
import from .types { ClientTargetType, BuildContext, BuildResult }

"""Abstract base class for all build targets.

All targets must inherit from this class and implement the required lifecycle methods.
Each method receives a BuildContext and returns a BuildResult for consistent handling.
"""
class ClientTarget {
    has target_type: ClientTargetType,
        requires_setup: bool = False,
        output_dir: Path;

    # -------------------------------------------------------------------------
    # Core Lifecycle Methods (must be implemented by subclasses)
    # -------------------------------------------------------------------------
    """Setup the target (one-time initialization).

    Called by `jac setup <target>`. Should create necessary directories,
    config files, and install dependencies.
    """
    def setup(self: ClientTarget, ctx: BuildContext) -> BuildResult abs;

    """Build the target for production.

    Called by `jac build --client <target>`. Should compile, bundle,
    and output production-ready artifacts.
    """
    def build(self: ClientTarget, ctx: BuildContext) -> BuildResult abs;

    """Start development server with hot reload.

    Called by `jac start --client <target> --dev`. Should start a dev server
    with file watching and hot module replacement.
    """
    def dev(self: ClientTarget, ctx: BuildContext) -> BuildResult abs;

    """Start the target in production mode.

    Called by `jac start --client <target>`. Should build (if needed)
    and launch the application.
    """
    def start(self: ClientTarget, ctx: BuildContext) -> BuildResult abs;

    # -------------------------------------------------------------------------
    # Validation Hooks (optional, have default implementations)
    # -------------------------------------------------------------------------
    """Check if setup has been completed for this target.

    Returns True if the target is ready to build/run, False otherwise.
    Override this for targets that require setup (e.g., desktop).
    """
    def is_setup_complete(self: ClientTarget, ctx: BuildContext) -> bool {
        return True;
    }

    """Validate the build context before executing a lifecycle method.

    Returns a BuildResult with success=False if validation fails.
    Override this to add target-specific validation.
    """
    def validate(self: ClientTarget, ctx: BuildContext) -> BuildResult {
        return BuildResult.ok();
    }

    # -------------------------------------------------------------------------
    # Lifecycle Hooks (optional, have default implementations)
    # -------------------------------------------------------------------------
    """Called before build() executes.

    Use this for pre-build tasks like cleaning, validation, or setup checks.
    Return BuildResult.fail() to abort the build.
    """
    def pre_build(self: ClientTarget, ctx: BuildContext) -> BuildResult {
        return BuildResult.ok();
    }

    """Called after build() completes.

    Use this for post-build tasks like copying files, generating manifests, etc.
    The result parameter contains the build() result.
    """
    def post_build(self: ClientTarget, ctx: BuildContext, result: BuildResult) -> None { }

    # -------------------------------------------------------------------------
    # Utility Methods
    # -------------------------------------------------------------------------
    """Get the name of this target as a string."""
    def get_name(self: ClientTarget) -> str {
        return str(self.target_type.value);
    }
}
