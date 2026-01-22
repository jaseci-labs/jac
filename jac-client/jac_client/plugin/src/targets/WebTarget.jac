"""Web target implementation.

This is the default target for building web applications.
"""
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.vite_bundler { ViteBundler }
import from jac_client.plugin.src.config_loader { JacClientConfig }
import from .registry { Target }

"""Web build target."""
class WebTarget(Target) {
    def init(self: WebTarget) {
        self.name = "web";
        self.default = True;
        self.requires_setup = False;
        self.config_section = "plugin.client";
        self.output_dir = Path(".jac/client/dist");
    }

    """Setup web target (no-op for web, already set up by default)."""
    override def setup(self: WebTarget, project_dir: Path) -> None {
        # Web target doesn't need setup
    }

    """Build web bundle using existing Vite pipeline."""
    override def build(
        self: WebTarget,
        entry_file: Path,
        project_dir: Path,
        platform: Optional[str] = None
    ) -> Path {
        # ViteBundler creates its own JacClientConfig internally
        bundler = ViteBundler(
            project_dir=project_dir,
            output_dir=None,
            minify=False,
            config_path=None
        );
        
        bundler.build(entry_file);
        bundle_path = bundler.find_bundle();
        if not bundle_path {
            raise RuntimeError("Web build failed: bundle not found");
        }
        return bundle_path;
    }

    """Start web dev server."""
    override def dev(self: WebTarget, entry_file: Path, project_dir: Path) -> None {
        # Web dev is handled by existing jac start command
        # This is a placeholder - actual dev server logic is in the CLI
    }
}

