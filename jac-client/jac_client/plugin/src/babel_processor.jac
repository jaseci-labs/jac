"""Babel processing for JavaScript transpilation."""
import subprocess;
import from pathlib { Path }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from .asset_processor { AssetProcessor }
import from .vite_bundler { ViteBundler }

"""Handles Babel compilation of JavaScript files."""
class BabelProcessor {
    def init(self: BabelProcessor, project_dir: Path);
    def compile(self: BabelProcessor) -> None;
    def copy_assets_after_compile(
        self: BabelProcessor,
        compiled_dir: Path,
        build_dir: Path,
        asset_processor: AssetProcessor
    ) -> None;
}
