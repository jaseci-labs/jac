"""Desktop target implementation.

Builds native desktop applications using Tauri.
Wraps the web bundle in a native container for Windows, macOS, and Linux.
"""
import from pathlib { Path }
import from ..types { ClientTargetType, BuildContext, BuildResult }
import from ..base { ClientTarget }

glob ERR_SETUP_REQUIRED = "Desktop target not set up. Run 'jac setup desktop' first.";

"""Desktop build target - native apps via Tauri."""
class DesktopTarget(ClientTarget) {
    def init(self: DesktopTarget) {
        self.target_type = ClientTargetType.DESKTOP;
        self.requires_setup = True;
        self.output_dir = Path("src-tauri/target/release/bundle");
    }

    """Check if desktop setup has been completed."""
    override def is_setup_complete(self: DesktopTarget, ctx: BuildContext) -> bool {
        tauri_dir = ctx.project_dir / "src-tauri";
        return tauri_dir.exists();
    }

    """Validate desktop build context."""
    override def validate(self: DesktopTarget, ctx: BuildContext) -> BuildResult {
        if not self.is_setup_complete(ctx) {
            return BuildResult.fail(ERR_SETUP_REQUIRED);
        }
        return BuildResult.ok();
    }

    """Setup desktop target - scaffold Tauri project structure."""
    override def setup(self: DesktopTarget, ctx: BuildContext) -> BuildResult;

    """Build desktop app - web bundle + Tauri."""
    override def build(self: DesktopTarget, ctx: BuildContext) -> BuildResult;

    """Start desktop dev server - Vite + Tauri hot reload."""
    override def dev(self: DesktopTarget, ctx: BuildContext) -> BuildResult;

    """Start desktop app - build and launch."""
    override def start(self: DesktopTarget, ctx: BuildContext) -> BuildResult;
}
