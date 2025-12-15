"""Vite bundling module."""
import hashlib;
import json;
import shutil;
import subprocess;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from .config_loader { JacClientConfig }
"""Handles Vite bundling operations."""
class ViteBundler {
    """Initialize the Vite bundler."""
    def __init__(
        self: ViteBundler,
        project_dir: Path,
        output_dir: Optional[Path] = None,
        minify: bool = False,
        config_path: Optional[Path] = None
    ) {
        self.project_dir = project_dir;
        self.output_dir = output_dir or (project_dir / 'compiled' / 'dist' / 'assets');
        self.minify = minify;
        self.config_path = config_path;
        self.config_loader = JacClientConfig(project_dir);
    }

    """Run Vite build with generated config in .jac-client.configs/."""
    def build(self: ViteBundler, entry_file: Optional[Path] = None) -> None {
        self.output_dir.mkdir(parents=True, exist_ok=True);
        generated_package_json = self.project_dir / '.jac-client.configs' / 'package.json';
        if not generated_package_json.exists() {
            self.create_package_json();
        }
        self._ensure_root_package_json();
        try {
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
                    raise e from ClientBundleError(
                        f"Failed to install npm dependencies: {e.stderr}"
                    ) ;
                } except FileNotFoundError {
                    raise None from ClientBundleError(
                        'npm command not found. Ensure Node.js and npm are installed.'
                    ) ;
                }
            }
            if self.config_path {
                command = ['npx', 'vite', 'build', '--config', str(self.config_path)];
            } elif entry_file {
                generated_config = self.create_vite_config(entry_file);
                command = ['npx', 'vite', 'build', '--config', str(generated_config)];
            } else {
                command = ['npm', 'run', 'build'];
            }
            subprocess.run(
                command,
                cwd=self.project_dir,
                check=True,
                capture_output=True,
                text=True
            );
        } finally {
            self._cleanup_root_package_files();
        }
    }

    """Find the generated Vite bundle file."""
    def find_bundle(self: ViteBundler) -> Optional[Path] {
        for file in self.output_dir.glob('client.*.js') {
            return file;
        }
        return None;
    }

    """Find the generated Vite CSS file."""
    def find_css(self: ViteBundler) -> Optional[Path] {
        css_file = self.output_dir / 'main.css';
        if css_file.exists() {
            return css_file;
        }
        for file in self.output_dir.glob('*.css') {
            return file;
        }
        return None;
    }

    """Read the bundled code and compute its hash."""
    def read_bundle(self: ViteBundler) -> tuple[str, str] {
        bundle_file = self.find_bundle();
        if not bundle_file {
            raise ClientBundleError('Vite build completed but no bundle file found') ;
        }
        bundle_code = bundle_file.read_text(encoding='utf-8');
        bundle_hash = hashlib.sha256(bundle_code.encode('utf-8')).hexdigest();
        return (bundle_code, bundle_hash);
    }

    """Check if the project has TypeScript support."""
    def _has_typescript_support(self: ViteBundler) -> bool {
        tsconfig_path = self.project_dir / 'tsconfig.json';
        if tsconfig_path.exists() {
            return True;
        }
        generated_package_json = self.project_dir / '.jac-client.configs' / 'package.json';
        if generated_package_json.exists() {
            try {
                with generated_package_json.open() as f {
                    package_data = json.load(f);
                    dev_deps = package_data.get('devDependencies', {});
                    if ('@vitejs/plugin-react' in dev_deps) {
                        return True;
                    }
                }
            } except (json.JSONDecodeError, KeyError) {
                ;
            }
        }
        package_json_path = self.project_dir / 'package.json';
        if package_json_path.exists() {
            try {
                with package_json_path.open() as f {
                    package_data = json.load(f);
                    dev_deps = package_data.get('devDependencies', {});
                    if ('@vitejs/plugin-react' in dev_deps) {
                        return True;
                    }
                }
            } except (json.JSONDecodeError, KeyError) {
                ;
            }
        }
        return False;
    }

    """Create vite.config.js from config.json during bundling."""
    def create_vite_config(self: ViteBundler, entry_file: Path) -> Path {
        configs_dir = self.project_dir / '.jac-client.configs';
        configs_dir.mkdir(exist_ok=True);
        vite_config_data = self.config_loader.get_vite_config();
        config_path = configs_dir / 'vite.config.js';
        has_ts = self._has_typescript_support();
        try {
            entry_relative = entry_file.relative_to(self.project_dir).as_posix();
        } except ValueError {
            entry_relative = entry_file.as_posix();
        }
        try {
            output_relative = self.output_dir.relative_to(self.project_dir).as_posix();
        } except ValueError {
            output_relative = self.output_dir.as_posix();
        }
        plugins = [];
        plugin_imports = [];
        if has_ts {
            plugin_imports.append('import react from "@vitejs/plugin-react";');
            plugins.append('    react()');
        }
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
        extensions = ['.mjs', '.js'];
        if has_ts {
            extensions.extend(['.mts', '.ts', '.jsx', '.tsx']);
        }
        extensions.append('.json');
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
        imports_section = f"{imports_str}" if imports_str else '';
        newline = '\n';
        server_section = f"  server: {{{newline}{server_config_str}{newline}  }},{newline}"
        if server_config_str
        else '';
        config_content = f'''import {{ defineConfig }} from "vite";
import path from "path";
import {{ fileURLToPath }} from "url";
{imports_section}const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Config is in .jac-client.configs/, so go up one level to project root
const projectRoot = path.resolve(__dirname, "..");

/**
 * Vite configuration generated from config.json (in project root)
 * To customize, edit config.json instead of this file.
 */

export default defineConfig({{
  plugins: [{(newline + plugins_str + newline + '  ') if plugins_str else ''}],
  root: projectRoot, // base folder (project root)
  build: {{
    rollupOptions: {{
      input: path.resolve(projectRoot, "{entry_relative}"), // your compiled entry file
      output: {{
        entryFileNames: "client.[hash].js", // name of the final js file
        assetFileNames: "[name].[ext]",
      }},
    }},
    outDir: path.resolve(projectRoot, "{output_relative}"), // final bundled output
    emptyOutDir: true,
{build_overrides_str}
  }},
  publicDir: false,
{server_section}  resolve: {{
      alias: {{
        "@jac-client/utils": path.resolve(projectRoot, "compiled/client_runtime.js"),
        "@jac-client/assets": path.resolve(projectRoot, "compiled/assets"),
      }},
      extensions: [{extensions_str}],
{resolve_overrides_str}
  }},
}});
''';
        config_path.write_text(config_content, encoding='utf-8');
        return config_path;
    }

    """Get a valid JavaScript variable name from plugin module name."""
    def _get_plugin_var_name(self: ViteBundler, plugin_name: str) -> str {
        name = plugin_name.split('/')[-1];
        name = name.replace('-', '_').replace('.', '_');
        name = name.lstrip('@');
        return name;
    }

    """Format plugin options as JavaScript object string."""
    def _format_plugin_options(self: ViteBundler, options: dict) -> str {
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

    """Format config object as JavaScript object string."""
    def _format_config_object(self: ViteBundler, config: dict, indent: int = 0) -> str {
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

    """Ensure root package.json exists temporarily for npm commands.\n\n        Create root package.json temporarily if it doesn't exist.\n        """
    def _ensure_root_package_json(self: ViteBundler) -> None {
        generated_package_json = self.project_dir / '.jac-client.configs' / 'package.json';
        root_package_json = self.project_dir / 'package.json';
        if not generated_package_json.exists() {
            self.create_package_json();
        }
        if not root_package_json.exists() {
            shutil.copy2(generated_package_json, root_package_json);
        }
    }

    """Clean up root package.json and move package-lock.json to .jac-client.configs/.\n\n        Remove root package.json and move package-lock.json to .jac-client.configs/.\n        """
    def _cleanup_root_package_files(self: ViteBundler) -> None {
        root_package_json = self.project_dir / 'package.json';
        root_package_lock = self.project_dir / 'package-lock.json';
        configs_dir = self.project_dir / '.jac-client.configs';
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

    """Create package.json from config.json during bundling."""
    def create_package_json(
        self: ViteBundler, project_name: Optional[str] = None
    ) -> Path {
        configs_dir = self.project_dir / '.jac-client.configs';
        configs_dir.mkdir(exist_ok=True);
        package_config = self.config_loader.get_package_config();
        package_json_path = configs_dir / 'package.json';
        has_ts = self._has_typescript_support();
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
        dev_dependencies = {
            'vite': '^6.4.1',
            '@babel/cli': '^7.28.3',
            '@babel/core': '^7.28.5',
            '@babel/preset-env': '^7.28.5',
            '@babel/preset-react': '^7.28.5'
        };
        if has_ts {
            dev_dependencies.update(
                {
                    '@vitejs/plugin-react': '^4.2.1',
                    'typescript': '^5.3.3',
                    '@types/react': '^18.2.45',
                    '@types/react-dom': '^18.2.18'
                }
            );
        }
        user_dev_deps = package_config.get('devDependencies', {});
        dev_dependencies.update(user_dev_deps);
        dependencies = {
            'react': '^19.2.0',
            'react-dom': '^19.2.0',
            'react-router-dom': '^6.30.1'
        };
        user_deps = package_config.get('dependencies', {});
        dependencies.update(user_deps);
        scripts = {
            'build': 'npm run compile && vite build --config .jac-client.configs/vite.config.js',
            'dev': 'vite dev --config .jac-client.configs/vite.config.js',
            'preview': 'vite preview --config .jac-client.configs/vite.config.js',
            'compile': 'babel compiled --out-dir build --extensions ".jsx,.js" --out-file-extension .js'
        };
        user_scripts = package_config.get('scripts', {});
        scripts.update(user_scripts);
        babel_config = {
            'presets': [
                ['@babel/preset-env', {'modules': False}],
                '@babel/preset-react'
            ]
        };
        package_data = {
            'name': name,
            'version': package_config.get('version', '1.0.0'),
            'description': package_config.get(
                'description', f"Jac application: {name}"
            ),
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
        return package_json_path;
    }
}
