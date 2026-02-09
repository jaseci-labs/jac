"""PWA (Progressive Web App) target implementation.

Extends the web target to add PWA capabilities:
- manifest.json generation
- Service worker for offline support
- Installability on mobile/desktop
"""
import from pathlib { Path }
import from ..types { ClientTargetType, BuildContext, BuildResult }
import from ..base { ClientTarget }

"""PWA build target - adds PWA capabilities to web builds."""
class PWATarget(ClientTarget) {
    def init(self: PWATarget) {
        self.target_type = ClientTargetType.PWA;
        self.requires_setup = False;  # Optional setup for icons
        self.output_dir = Path(".jac/client/dist");
    }

    """Check if PWA setup has been completed (optional)."""
    override def is_setup_complete(self: PWATarget, ctx: BuildContext) -> bool {
        icons_dir = ctx.project_dir / "pwa_icons";
        return icons_dir.exists();
    }

    """Setup PWA target - copies default icons and configures jac.toml."""
    override def setup(self: PWATarget, ctx: BuildContext) -> BuildResult;

    """Build PWA bundle - web bundle + manifest + service worker."""
    override def build(self: PWATarget, ctx: BuildContext) -> BuildResult;

    """Start PWA dev server (service worker disabled for better DX)."""
    override def dev(self: PWATarget, ctx: BuildContext) -> BuildResult;

    """Start PWA in production mode."""
    override def start(self: PWATarget, ctx: BuildContext) -> BuildResult {
        # PWA start builds first, then normal jac start serves
        return self.build(ctx);
    }
}
