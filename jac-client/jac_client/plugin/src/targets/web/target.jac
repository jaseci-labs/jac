"""Web target implementation.

This is the default target for building web applications.
Builds to static HTML/JS/CSS that can be served by any web server.
"""
import from pathlib { Path }
import from ..types { ClientTargetType, BuildContext, BuildResult }
import from ..base { ClientTarget }

"""Web build target - the default target for Jac applications."""
class WebTarget(ClientTarget) {
    def init(self: WebTarget) {
        self.target_type = ClientTargetType.WEB;
        self.requires_setup = False;
        self.output_dir = Path(".jac/client/dist");
    }

    """Setup web target (no-op - web is ready by default)."""
    override def setup(self: WebTarget, ctx: BuildContext) -> BuildResult {
        return BuildResult.ok();
    }

    """Build web bundle using Vite pipeline."""
    override def build(self: WebTarget, ctx: BuildContext) -> BuildResult;

    """Start web dev server with hot reload."""
    override def dev(self: WebTarget, ctx: BuildContext) -> BuildResult;

    """Start web target in production mode."""
    override def start(self: WebTarget, ctx: BuildContext) -> BuildResult {
        # Web start is handled by the main jac server
        return BuildResult.ok();
    }
}
