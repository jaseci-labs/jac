"""Get the client build directory from project config."""
impl ViteBundler._get_client_dir(self: ViteBundler) -> Path {
    # Try to get from project config
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
        if config is not None {
            return config.get_client_dir();
        }
    } except ImportError { }
    # Fallback to default
    return self.project_dir / '.jac' / 'client';
}

"""Create package.json from config.json during bundling."""
impl ViteBundler.create_package_json(
    self: ViteBundler, project_name: Optional[str] = None
) -> Path {
    build_dir = self._get_client_dir();
    build_dir.mkdir(parents=True, exist_ok=True);
    configs_dir = build_dir / 'configs';
    configs_dir.mkdir(exist_ok=True);
    package_config = self.config_loader.get_package_config();
    package_json_path = configs_dir / 'package.json';
    name = package_config.get('name', '');
    if (not name and project_name) {
        name = project_name;
    }
    if not name {
        existing_package = self.project_dir / 'package.json';
        if existing_package.exists() {
            try {
                with existing_package.open() as f {
                    existing_data = json.load(f);
                    name = existing_data.get('name', '');
                }
            } except (json.JSONDecodeError, KeyError) {
                ;
            }
        }
    }
    if not name {
        name = self.project_dir.name or 'jac-app';
    }
    dependencies = package_config.get('dependencies', {});
    dev_dependencies = package_config.get('devDependencies', {});
    scripts = {
        'build': 'npm run compile && vite build --config .jac/client/configs/vite.config.js',
        'dev': 'vite dev --config .jac/client/configs/vite.config.js',
        'preview': 'vite preview --config .jac/client/configs/vite.config.js',
        'compile': 'babel compiled --out-dir build --extensions ".jsx,.js" --out-file-extension .js'
    };
    user_scripts = package_config.get('scripts', {});
    scripts.update(user_scripts);
    babel_config = {
        'presets': [['@babel/preset-env', {'modules': False}], '@babel/preset-react']
    };
    package_data = {
        'name': name,
        'version': package_config.get('version', '1.0.0'),
        'description': package_config.get('description', f"Jac application: {name}"),
        'type': 'module',
        'main': 'index.js',
        'scripts': scripts,
        'dependencies': dependencies,
        'devDependencies': dev_dependencies,
        'babel': babel_config
    };
    for (key, value) in package_config.items() {
        if (
            key not in {'name','version','description','dependencies','devDependencies'}
        ) {
            package_data[key] = value;
        }
    }
    with package_json_path.open('w', encoding='utf-8') as f {
        json.dump(package_data, f, indent=2);
    }
    # Generate tsconfig.json during build time
    self.create_tsconfig();
    # Generate config files (postcss, tailwind, etc.) from jac.toml
    self.create_config_files();
    return package_json_path;
}

"""Create tsconfig.json during build time, merging user config from jac.toml."""
impl ViteBundler.create_tsconfig(self: ViteBundler) -> Path {
    build_dir = self._get_client_dir();
    build_dir.mkdir(parents=True, exist_ok=True);
    configs_dir = build_dir / 'configs';
    configs_dir.mkdir(exist_ok=True);
    tsconfig_path = configs_dir / 'tsconfig.json';
    # Default tsconfig settings
    default_compiler_options = {
        'target': 'ES2020',
        'useDefineForClassFields': True,
        'lib': ['ES2020', 'DOM', 'DOM.Iterable'],
        'module': 'ESNext',
        'skipLibCheck': True,
        'moduleResolution': 'bundler',
        'allowImportingTsExtensions': True,
        'resolveJsonModule': True,
        'isolatedModules': True,
        'noEmit': True,
        'jsx': 'react-jsx',
        'strict': True,
        'noUnusedLocals': True,
        'noUnusedParameters': True,
        'noFallthroughCasesInSwitch': True
    };
    default_include = ['components/**/*'];
    default_exclude = ['.jac'];
    # Get user config from [plugins.client.ts] in jac.toml
    user_ts_config = self.config_loader.get_ts_config();
    user_compiler_options = user_ts_config.get('compilerOptions', {});
    user_include = user_ts_config.get('include', []);
    user_exclude = user_ts_config.get('exclude', []);
    # Merge compiler options (user overrides defaults)
    merged_compiler_options = {** default_compiler_options, ** user_compiler_options};
    # For include/exclude, use user values if provided, otherwise defaults
    merged_include = user_include or default_include;
    merged_exclude = user_exclude or default_exclude;
    tsconfig_data = {
        'compilerOptions': merged_compiler_options,
        'include': merged_include,
        'exclude': merged_exclude
    };
    # Write the config to .jac/client/configs/tsconfig.json (no root config file)
    tsconfig_path.write_text(json.dumps(tsconfig_data, indent=2), encoding='utf-8');
    return tsconfig_path;
}

"""
Clean up root package.json and move package-lock.json to configs/.

        Remove root package.json and move package-lock.json to configs/.
"""
impl ViteBundler._cleanup_root_package_files(self: ViteBundler) -> None {
    root_package_json = self.project_dir / 'package.json';
    root_package_lock = self.project_dir / 'package-lock.json';
    build_dir = self._get_client_dir();
    configs_dir = build_dir / 'configs';
    configs_package_lock = configs_dir / 'package-lock.json';
    if root_package_lock.exists() {
        configs_dir.mkdir(exist_ok=True);
        if configs_package_lock.exists() {
            configs_package_lock.unlink();
        }
        shutil.move(str(root_package_lock), str(configs_package_lock));
    }
    if root_package_json.exists() {
        root_package_json.unlink();
    }
}

"""
Ensure root package.json exists temporarily for npm commands.

        Create root package.json temporarily if it doesn't exist.
"""
impl ViteBundler._ensure_root_package_json(self: ViteBundler) -> None {
    generated_package_json = self._get_client_dir() / 'configs' / 'package.json';
    root_package_json = self.project_dir / 'package.json';
    if not generated_package_json.exists() {
        self.create_package_json();
    }
    if not root_package_json.exists() {
        shutil.copy2(generated_package_json, root_package_json);
    }
}

"""Format config object as JavaScript object string."""
impl ViteBundler._format_config_object(
    self: ViteBundler, config: dict, indent: int = 0
) -> str {
    if not config {
        return '';
    }
    indent_str = ' ' * indent;
    items = [];
    for (key, value) in config.items() {
        if isinstance(value, str) {
            items.append(f"{indent_str}  {key}: '{value}',");
        } elif isinstance(value, bool) {
            items.append(f"{indent_str}  {key}: {str(value).lower()},");
        } elif isinstance(value, (int, float)) {
            items.append(f"{indent_str}  {key}: {value},");
        } elif isinstance(value, <>list) {
            list_str = ', '.join(repr(v) for v in value);
            items.append(f"{indent_str}  {key}: [{list_str}],");
        } elif isinstance(value, <>dict) {
            nested = self._format_config_object(value, (indent + 2));
            items.append(f"{indent_str}  {key}: {{{nested}{indent_str}  }},");
        } else {
            items.append(f"{indent_str}  {key}: {repr(value)},");
        }
    }
    return '\n'.join(items);
}

"""Format plugin options as JavaScript object string."""
impl ViteBundler._format_plugin_options(self: ViteBundler, options: dict) -> str {
    if not options {
        return '';
    }
    items = [];
    for (key, value) in options.items() {
        if isinstance(value, str) {
            items.append(f"{key}: '{value}'");
        } elif isinstance(value, bool) {
            items.append(f"{key}: {str(value).lower()}");
        } elif isinstance(value, (int, float)) {
            items.append(f"{key}: {value}");
        } elif isinstance(value, <>list) {
            items.append(f"{key}: [{', '.join(repr(v) for v in value)}]");
        } else {
            items.append(f"{key}: {repr(value)}");
        }
    }
    return '{ ' + ', '.join(items) + ' }';
}

"""Get a valid JavaScript variable name from plugin module name."""
impl ViteBundler._get_plugin_var_name(self: ViteBundler, plugin_name: str) -> str {
    name = plugin_name.split('/')[-1];
    name = name.replace('-', '_').replace('.', '_');
    name = name.lstrip('@');
    return name;
}

"""Create vite.config.js from config.json during bundling."""
impl ViteBundler.create_vite_config(self: ViteBundler, entry_file: Path) -> Path {
    build_dir = self._get_client_dir();
    build_dir.mkdir(parents=True, exist_ok=True);
    configs_dir = build_dir / 'configs';
    configs_dir.mkdir(exist_ok=True);
    vite_config_data = self.config_loader.get_vite_config();
    config_path = configs_dir / 'vite.config.js';
    # TypeScript is always enabled by default
    try {
        # Entry file path relative to client build dir (not project root)
        entry_relative = entry_file.relative_to(build_dir).as_posix();
    } except ValueError {
        # Fallback: use absolute path
        entry_relative = entry_file.as_posix();
    }
    try {
        # Output dir path relative to client build dir (not project root)
        output_relative = self.output_dir.relative_to(build_dir).as_posix();
    } except ValueError {
        # Fallback: use absolute path
        output_relative = self.output_dir.as_posix();
    }
    # Calculate compiled directory path for aliases (relative to client build dir)
    if entry_relative.endswith('/build/main.js') {
        compiled_utils_relative = entry_relative[:-13] + '/compiled/client_runtime.js';
        compiled_assets_relative = entry_relative[:-13] + '/compiled/assets';
    } elif entry_relative.endswith('build/main.js') {
        compiled_utils_relative = 'compiled/client_runtime.js';
        compiled_assets_relative = 'compiled/assets';
    } else {
        compiled_utils_relative = 'compiled/client_runtime.js';
        compiled_assets_relative = 'compiled/assets';
    }
    plugins = [];
    plugin_imports = [];
    # TypeScript support is always enabled, so always include React plugin
    plugin_imports.append('import react from "@vitejs/plugin-react";');
    plugins.append('    react()');
    lib_imports = vite_config_data.get('lib_imports', []);
    for lib_import in lib_imports {
        if (isinstance(lib_import, str) and lib_import.strip()) {
            plugin_imports.append(lib_import);
        }
    }
    custom_plugins = vite_config_data.get('plugins', []);
    for plugin in custom_plugins {
        if isinstance(plugin, str) {
            plugins.append(f"    {plugin}");
        }
    }
    plugins_str = ',\n'.join(plugins) if plugins else '';
    imports_str = '\n'.join(plugin_imports) if plugin_imports else '';
    # TypeScript extensions are always included
    extensions = ['.mjs', '.js', '.mts', '.ts', '.jsx', '.tsx', '.json'];
    extensions_str = ', '.join(f'"{ext}"' for ext in extensions);
    build_config = vite_config_data.get('build', {});
    build_overrides_str = self._format_config_object(build_config, indent=4)
    if (isinstance(build_config, <>dict) and build_config)
    else '';
    server_config = vite_config_data.get('server', {});
    server_config_str = self._format_config_object(server_config, indent=2)
    if (isinstance(server_config, <>dict) and server_config)
    else '';
    resolve_config = vite_config_data.get('resolve', {});
    resolve_overrides_str = self._format_config_object(resolve_config, indent=6)
    if (isinstance(resolve_config, <>dict) and resolve_config)
    else '';
    imports_section = f"{imports_str}\n" if imports_str else '';
    newline = '\n';
    server_section = f"  server: {{{newline}{server_config_str}{newline}  }},{newline}"
    if server_config_str
    else '';
    config_content = f'''import {{ defineConfig }} from "vite";
import path from "path";
import {{ fileURLToPath }} from "url";
{imports_section}const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Config is in configs/ inside .jac/client/, so go up one level to .jac/client/, then up two more to project root
const buildDir = path.resolve(__dirname, "..");
const projectRoot = path.resolve(__dirname, "../../..");

/**
 * Vite configuration generated from config.json (in project root)
 * To customize, edit config.json instead of this file.
 */

export default defineConfig({{
  plugins: [{(newline + plugins_str + newline + '  ') if plugins_str else ''}],
  root: buildDir, // base folder (.jac/client/) so vite can find node_modules
    build: {{
    rollupOptions: {{
      input: path.resolve(buildDir, "{entry_relative}"), // your compiled entry file
      output: {{
        entryFileNames: "client.[hash].js", // name of the final js file
        assetFileNames: (assetInfo) => assetInfo.name?.endsWith('.css') ? 'styles.css' : '[name].[ext]',
      }},
    }},
    outDir: path.resolve(buildDir, "{output_relative}"), // final bundled output
    emptyOutDir: true,
{build_overrides_str}
  }},
  publicDir: false,
{server_section}  resolve: {{
      alias: {{
        "@jac-client/utils": path.resolve(buildDir, "{compiled_utils_relative}"),
        "@jac-client/assets": path.resolve(buildDir, "{compiled_assets_relative}"),
      }},
      extensions: [{extensions_str}],
{resolve_overrides_str}
  }},
}});
''';
    config_path.write_text(config_content, encoding='utf-8');
    return config_path;
}

"""Check if the project has TypeScript support. TypeScript is now enabled by default."""
impl ViteBundler._has_typescript_support(self: ViteBundler) -> bool {
    # TypeScript is always enabled by default
    return True;
}

"""Read the bundled code and compute its hash."""
impl ViteBundler.read_bundle(self: ViteBundler) -> tuple[str, str] {
    bundle_file = self.find_bundle();
    if not bundle_file {
        raise ClientBundleError('Vite build completed but no bundle file found') ;
    }
    bundle_code = bundle_file.read_text(encoding='utf-8');
    bundle_hash = hashlib.sha256(bundle_code.encode('utf-8')).hexdigest();
    return (bundle_code, bundle_hash);
}

"""Find the generated Vite CSS file."""
impl ViteBundler.find_css(self: ViteBundler) -> Optional[Path] {
    css_file = self.output_dir / 'styles.css';
    return css_file if css_file.exists() else None;
}

"""Find the generated Vite bundle file."""
impl ViteBundler.find_bundle(self: ViteBundler) -> Optional[Path] {
    for file in self.output_dir.glob('client.*.js') {
        return file;
    }
    return None;
}

"""Run Vite build with generated config in .jac/client/configs/."""
impl ViteBundler.build(self: ViteBundler, entry_file: Optional[Path] = None) -> None {
    import sys;
    import time;
    self.output_dir.mkdir(parents=True, exist_ok=True);
    generated_package_json = self._get_client_dir() / 'configs' / 'package.json';
    if not generated_package_json.exists() {
        self.create_package_json();
    } else {
        # Ensure tsconfig.json exists even if package.json already exists
        self.create_tsconfig();
    }
    try {
        build_dir = self._get_client_dir();
        node_modules = build_dir / 'node_modules';
        if not node_modules.exists() {
            # Temporarily copy package.json to client build dir for npm install
            build_package_json = build_dir / 'package.json';
            configs_package_json = build_dir / 'configs' / 'package.json';
            if configs_package_json.exists() and not build_package_json.exists() {
                import shutil;
                shutil.copy2(configs_package_json, build_package_json);
            }
            try {
                # Install to .jac/client/node_modules with progress feedback
                print(
                    "  ⏳ Installing npm dependencies (this may take a minute)...",
                    flush=True
                );
                start_time = time.time();
                result = subprocess.run(
                    ['npm', 'install', '--progress'],
                    cwd=build_dir,
                    check=False,
                    capture_output=True,
                    text=True
                );
                elapsed = time.time() - start_time;
                if result.returncode != 0 {
                    print(
                        f"\n  ✖ npm install failed after {elapsed:.1f}s",
                        file=sys.stderr
                    );
                    raise ClientBundleError(
                        f"Failed to install npm dependencies: {result.stderr
                        or result.stdout}"
                    ) ;
                }
                print(f"  ✔ Dependencies installed ({elapsed:.1f}s)", flush=True);
            } except FileNotFoundError {
                raise None from ClientBundleError(
                    'npm command not found. Ensure Node.js and npm are installed.'
                ) ;
            }
        }
        if self.config_path {
            # Make config path relative to build_dir (where vite runs from)
            try {
                config_rel = self.config_path.relative_to(build_dir);
                command = ['npx', 'vite', 'build', '--config', str(config_rel)];
            } except ValueError {
                # Config is outside client build dir, use absolute path
                command = ['npx', 'vite', 'build', '--config', str(self.config_path)];
            }
        } elif entry_file {
            generated_config = self.create_vite_config(entry_file);
            # Config is in configs/, make it relative to build_dir
            config_rel = generated_config.relative_to(build_dir);
            command = ['npx', 'vite', 'build', '--config', str(config_rel)];
        } else {
            command = ['npm', 'run', 'build'];
        }
        # Run vite from client build directory so it can find node_modules
        print("  ⏳ Building client bundle...", flush=True);
        start_time = time.time();
        result = subprocess.run(
            command, cwd=build_dir, check=False, capture_output=True, text=True
        );
        elapsed = time.time() - start_time;
        if result.returncode != 0 {
            print(f"\n  ✖ Vite build failed after {elapsed:.1f}s", file=sys.stderr);
            error_msg = result.stderr or result.stdout or 'Unknown error';
            raise ClientBundleError(
                f"Vite build failed:\n{error_msg}\nCommand: {' '.join(command)}"
            ) from None ;
        }
        print(f"  ✔ Client bundle built ({elapsed:.1f}s)", flush=True);
    } finally {
        # Clean up temporary package.json in client build dir
        build_package_json = build_dir / 'package.json';
        if build_package_json.exists() {
            build_package_json.unlink();
        }
        # Move package-lock.json to configs/ if it exists
        build_package_lock = build_dir / 'package-lock.json';
        if build_package_lock.exists() {
            configs_package_lock = build_dir / 'configs' / 'package-lock.json';
            if configs_package_lock.exists() {
                configs_package_lock.unlink();
            }
            build_package_lock.rename(configs_package_lock);
        }
    }
}

"""Initialize the Vite bundler."""
impl ViteBundler.init(
    self: ViteBundler,
    project_dir: Path,
    output_dir: Optional[Path] = None,
    minify: bool = False,
    config_path: Optional[Path] = None
) {
    self.project_dir = project_dir;
    self.minify = minify;
    self.config_path = config_path;
    self.config_loader = JacClientConfig(project_dir);
    # Set output_dir after config_loader is initialized so _get_client_dir works
    self.output_dir = output_dir or (self._get_client_dir() / 'dist');
}

"""Create a dev-mode vite config with API proxy for HMR."""
impl ViteBundler.create_dev_vite_config(
    self: ViteBundler, entry_file: Path, api_port: int = 8000
) -> Path {
    build_dir = self._get_client_dir();
    build_dir.mkdir(parents=True, exist_ok=True);
    configs_dir = build_dir / 'configs';
    configs_dir.mkdir(exist_ok=True);
    config_path = configs_dir / 'vite.dev.config.js';
    # Get entry file relative path
    try {
        entry_relative = entry_file.relative_to(build_dir).as_posix();
    } except ValueError {
        entry_relative = entry_file.as_posix();
    }
    # Calculate paths for aliases
    if entry_relative.endswith('/build/main.js') {
        compiled_utils_relative = entry_relative[:-13] + '/compiled/client_runtime.js';
        compiled_assets_relative = entry_relative[:-13] + '/compiled/assets';
    } elif entry_relative.endswith('build/main.js') {
        compiled_utils_relative = 'compiled/client_runtime.js';
        compiled_assets_relative = 'compiled/assets';
    } else {
        compiled_utils_relative = 'compiled/client_runtime.js';
        compiled_assets_relative = 'compiled/assets';
    }
    # Extensions for TypeScript
    extensions = ['.mjs', '.js', '.mts', '.ts', '.jsx', '.tsx', '.json'];
    extensions_str = ', '.join(f'"{ext}"' for ext in extensions);
    # Generate dev config with proxy for API routes
    config_content = f'''import {{ defineConfig }} from "vite";
import path from "path";
import {{ fileURLToPath }} from "url";
import react from "@vitejs/plugin-react";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const buildDir = path.resolve(__dirname, "..");
const projectRoot = path.resolve(__dirname, "../../..");

/**
 * Vite DEV configuration for HMR mode
 * Proxies API routes to Python server at localhost:{api_port}
 */
export default defineConfig({{
  plugins: [react()],
  root: buildDir,
  publicDir: false,
  server: {{
    watch: {{
      usePolling: true,
      interval: 100,
    }},
    proxy: {{
      "/walker": {{
        target: "http://localhost:{api_port}",
        changeOrigin: true,
      }},
      "/function": {{
        target: "http://localhost:{api_port}",
        changeOrigin: true,
      }},
      "/user": {{
        target: "http://localhost:{api_port}",
        changeOrigin: true,
      }},
      "/introspect": {{
        target: "http://localhost:{api_port}",
        changeOrigin: true,
      }},
    }},
  }},
  resolve: {{
    alias: {{
      "@jac-client/utils": path.resolve(buildDir, "{compiled_utils_relative}"),
      "@jac-client/assets": path.resolve(buildDir, "{compiled_assets_relative}"),
    }},
    extensions: [{extensions_str}],
  }},
}});
''';
    config_path.write_text(config_content, encoding='utf-8');
    return config_path;
}

"""Create config files from jac.toml [plugins.client.configs].

Generates JavaScript config files (e.g., postcss.config.js, tailwind.config.js)
from TOML configuration. Each key in [plugins.client.configs] becomes a config file.

Example jac.toml:
    [plugins.client.configs.postcss]
    plugins = ["tailwindcss", "autoprefixer"]

    [plugins.client.configs.tailwind]
    content = ["./src/**/*.{js,jsx}"]

This generates:
    - .jac/client/configs/postcss.config.js
    - .jac/client/configs/tailwind.config.js
"""
impl ViteBundler.create_config_files(self: ViteBundler) -> list[Path] {
    configs = self.config_loader.get_configs();
    if not configs {
        return [];
    }
    build_dir = self._get_client_dir();
    configs_dir = build_dir / 'configs';
    configs_dir.mkdir(parents=True, exist_ok=True);
    created_files: list[Path] = [];
    for (config_name, config_data) in configs.items() {
        config_path = configs_dir / f'{config_name}.config.js';

        # Convert the TOML config to JavaScript module.exports
        js_content = _toml_config_to_js(config_name, config_data);
        config_path.write_text(js_content, encoding='utf-8');
        created_files.append(config_path);
    }
    return created_files;
}

"""Convert TOML config data to JavaScript config file content.

Generates a generic module.exports with the config data as JSON.
"""
def _toml_config_to_js(config_name: str, config_data: dict) -> str {
    return f"module.exports = {json.dumps(config_data, indent=2)};\n";
}

"""Start Vite dev server as a subprocess."""
impl ViteBundler.start_dev_server(self: ViteBundler, port: int = 3000) -> Any {
    import sys;
    import time;
    build_dir = self._get_client_dir();
    node_modules = build_dir / 'node_modules';
    # Create/update index.html for dev server (load from compiled/ for HMR)
    index_html = build_dir / 'index.html';
    index_content = '''<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Jac App (Dev)</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/compiled/_entry.js"></script>
  </body>
</html>
''';
    index_html.write_text(index_content, encoding='utf-8');
    # Ensure dependencies are installed
    if not node_modules.exists() {
        generated_package_json = build_dir / 'configs' / 'package.json';
        if not generated_package_json.exists() {
            self.create_package_json();
        }
        # Temporarily copy package.json for npm install
        build_package_json = build_dir / 'package.json';
        if not build_package_json.exists() {
            shutil.copy2(generated_package_json, build_package_json);
        }
        try {
            print(
                "  ⏳ Installing npm dependencies (this may take a minute)...",
                flush=True
            );
            start_time = time.time();
            result = subprocess.run(
                ['npm', 'install', '--progress'],
                cwd=build_dir,
                check=False,
                capture_output=True,
                text=True
            );
            elapsed = time.time() - start_time;
            if result.returncode != 0 {
                print(
                    f"\n  ✖ npm install failed after {elapsed:.1f}s", file=sys.stderr
                );
                print(f"  Error: {result.stderr or result.stdout}", file=sys.stderr);
                raise ClientBundleError(
                    f"Failed to install npm dependencies: {result.stderr
                    or result.stdout}"
                ) ;
            }
            print(f"  ✔ Dependencies installed ({elapsed:.1f}s)", flush=True);
        } finally {
            # Clean up temp package.json
            if build_package_json.exists() {
                build_package_json.unlink();
            }
        }
    }
    # Find the dev config
    dev_config = build_dir / 'configs' / 'vite.dev.config.js';
    if not dev_config.exists() {
        raise ClientBundleError(
            "Dev config not found. Call create_dev_vite_config first."
        ) ;
    }
    config_rel = dev_config.relative_to(build_dir);
    logger.debug(f"Starting Vite dev server on port {port}");
    # Start Vite in dev mode (let output go to terminal for HMR visibility)
    process = subprocess.Popen(
        ['npx', 'vite', '--config', str(config_rel), '--port', str(port)],
        cwd=build_dir
    );
    return process;
}
