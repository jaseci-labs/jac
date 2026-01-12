"""Copy CSS, assets, and TypeScript files from compiled/ to build/ after Babel compilation."""

impl BabelProcessor.copy_assets_after_compile(
    self: BabelProcessor,
    compiled_dir: Path,
    build_dir: Path,
    asset_processor: AssetProcessor
) -> None {
    asset_processor.copy_assets(compiled_dir, build_dir);
    asset_processor.copy_typescript_files(compiled_dir, build_dir);
}

"""Run Babel compilation (npm run compile)."""
impl BabelProcessor.compile(self: BabelProcessor) -> None {
    bundler = ViteBundler(self.project_dir);
    # Ensure root package.json exists temporarily for npm commands
    bundler._ensure_root_package_json();
    try {
        # Ensure dependencies are installed (check if node_modules exists)
        client_dir = bundler._get_client_dir();
        node_modules = client_dir / 'node_modules';
        if not node_modules.exists() {
            # Temporarily copy package.json to .jac/client/ for npm install
            build_package_json = client_dir / 'package.json';
            configs_package_json = client_dir / 'configs' / 'package.json';
            if configs_package_json.exists() and not build_package_json.exists() {
                import shutil;
                shutil.copy2(configs_package_json, build_package_json);
            }
            try {
                # Install to .jac/client/node_modules
                subprocess.run(
                    ['npm', 'install'],
                    cwd=client_dir,
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

        # Temporarily copy package.json to .jac/client/ for npm run compile
        build_package_json = client_dir / 'package.json';
        configs_package_json = client_dir / 'configs' / 'package.json';
        if configs_package_json.exists() and not build_package_json.exists() {
            import shutil;
            shutil.copy2(configs_package_json, build_package_json);
        }
        command = ['npm', 'run', 'compile'];
        result = subprocess.run(
            command, cwd=client_dir, capture_output=True, text=True
        );
        if result.returncode != 0 {
            # Show the actual error from npm/babel
            error_output = result.stderr or result.stdout or "Unknown error";
            raise RuntimeError(f"Client bundle compilation failed:\n{error_output}") ;
        }
    } finally {
        # Clean up temporary package.json in .jac/client/
        build_package_json = client_dir / 'package.json';
        if build_package_json.exists() {
            build_package_json.unlink();
        }
        # Move package-lock.json to configs/ if it exists
        build_package_lock = client_dir / 'package-lock.json';
        if build_package_lock.exists() {
            configs_package_lock = client_dir / 'configs' / 'package-lock.json';
            if configs_package_lock.exists() {
                configs_package_lock.unlink();
            }
            build_package_lock.rename(configs_package_lock);
        }
        # Always clean up root package.json and move package-lock.json
        bundler._cleanup_root_package_files();
    }
}

"""Initialize the Babel processor."""
impl BabelProcessor.init(self: BabelProcessor, project_dir: Path) {
    self.project_dir = project_dir;
}
