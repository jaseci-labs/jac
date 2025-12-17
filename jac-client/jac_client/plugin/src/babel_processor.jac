"""Babel processing for JavaScript transpilation."""
import subprocess;
import from pathlib { Path }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from .asset_processor { AssetProcessor }
import from .vite_bundler { ViteBundler }

"""Handles Babel compilation of JavaScript files."""
class BabelProcessor {
    """Initialize the Babel processor."""
    def __init__(self: BabelProcessor, project_dir: Path) {
        self.project_dir = project_dir;
    }

    """Run Babel compilation (npm run compile)."""
    def compile(self: BabelProcessor) -> None {
        bundler = ViteBundler(self.project_dir);

        # Ensure root package.json exists temporarily for npm commands
        bundler._ensure_root_package_json();

        try {
            # Ensure dependencies are installed (check if node_modules exists)
            node_modules = self.project_dir / 'node_modules';
            if not node_modules.exists() {
                try {
                    subprocess.run(
                        ['npm', 'install'],
                        cwd=self.project_dir,
                        check=True,
                        capture_output=True,
                        text=True
                    );
                } except subprocess.CalledProcessError as e {
                    raise ClientBundleError(
                        f'Failed to install npm dependencies: {e.stderr}'
                    ) from e ;
                } except FileNotFoundError {
                    raise ClientBundleError(
                        'npm command not found. Ensure Node.js and npm are installed.'
                    ) from None ;
                }
            }

            command = ['npm', 'run', 'compile'];
            subprocess.run(
                command,
                cwd=self.project_dir,
                check=True,
                capture_output=True,
                text=True
            );
        } finally {
            # Always clean up root package.json and move package-lock.json
            bundler._cleanup_root_package_files();
        }
    }

    """Copy CSS, assets, and TypeScript files from compiled/ to build/ after Babel compilation."""
    def copy_assets_after_compile(
        self: BabelProcessor,
        compiled_dir: Path,
        build_dir: Path,
        asset_processor: AssetProcessor
    ) -> None {
        asset_processor.copy_assets(compiled_dir, build_dir);
        asset_processor.copy_typescript_files(compiled_dir, build_dir);
    }
}
