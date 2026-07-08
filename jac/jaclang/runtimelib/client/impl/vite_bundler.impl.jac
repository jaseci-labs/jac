import from jaclang.cli.console { console }
import from jaclang.runtimelib.client { get_bun }
import from jaclang.runtimelib.client.bun_installer { bun_unavailable_message }
import from jaclang.runtimelib.client_bundle { ClientBundleError, MissingBunError }


def _require_bun -> str {
    bun = get_bun();
    if not bun {
        raise MissingBunError(bun_unavailable_message()) from None;
    }
    return bun;
}

impl ViteBundler._get_client_dir(self: ViteBundler) -> Path {
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
        if config is not None {
            config_root = config.project_root;
            if config_root is not None
            and config_root.resolve() == self.project_dir.resolve() {
                return config.get_client_dir();
            }
        }
    } except ImportError { }

    return self.project_dir / '.jac' / 'client';
}

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
        'build': 'vite build --config .jac/client/configs/vite.config.js',
        'dev': 'vite dev --config .jac/client/configs/vite.config.js',
        'preview': 'vite preview --config .jac/client/configs/vite.config.js'
    };
    user_scripts = package_config.get('scripts', {});
    scripts.update(user_scripts);
    package_data = {
        'name': name,
        'version': package_config.get('version', '1.0.0'),
        'description': package_config.get('description', f"Jac application: {name}"),
        'type': 'module',
        'main': 'index.js',
        'scripts': scripts,
        'dependencies': dependencies,
        'devDependencies': dev_dependencies
    };
    for (key, value) in package_config.items() {
        if (
            key not in {
                'name',
                'version',
                'description',
                'dependencies',
                'devDependencies'
            }
        ) {
            package_data[key] = value;
        }
    }
    with package_json_path.open('w', encoding='utf-8') as f {
        json.dump(package_data, f, indent=2);
    }

    self.create_tsconfig();

    self.create_config_files();

    self.create_npmrc();
    return package_json_path;
}

impl ViteBundler.create_tsconfig(self: ViteBundler) -> Path {
    build_dir = self._get_client_dir();
    build_dir.mkdir(parents=True, exist_ok=True);
    configs_dir = build_dir / 'configs';
    configs_dir.mkdir(exist_ok=True);
    tsconfig_path = configs_dir / 'tsconfig.json';

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

    user_ts_config = self.config_loader.get_ts_config();
    user_compiler_options = user_ts_config.get('compilerOptions', {});
    user_include = user_ts_config.get('include', []);
    user_exclude = user_ts_config.get('exclude', []);

    merged_compiler_options = {** default_compiler_options, ** user_compiler_options};

    paths_config = self.config_loader.get_paths_config();
    if paths_config {
        ts_paths: dict[str, list[str]] = {};
        for (alias_pattern, target_path) in paths_config.items() {
            ts_target = target_path.lstrip('./');
            ts_paths[alias_pattern] = [ts_target];
        }
        merged_compiler_options['baseUrl'] = '.';
        merged_compiler_options['paths'] = ts_paths;
    }

    merged_include = user_include or default_include;
    merged_exclude = user_exclude or default_exclude;
    tsconfig_data = {
        'compilerOptions': merged_compiler_options,
        'include': merged_include,
        'exclude': merged_exclude
    };

    tsconfig_path.write_text(json.dumps(tsconfig_data, indent=2), encoding='utf-8');
    return tsconfig_path;
}

impl ViteBundler.install_packages(
    self: ViteBundler,
    install_dir: Optional[Path] = None,
    force: bool = False,
    capture_output: bool = False,
    clean_stale: bool = False
) -> None {
    import time;
    import shutil;
    import subprocess;
    bun = _require_bun();
    build_dir = install_dir if install_dir is not None else self._get_client_dir();
    node_modules = build_dir / 'node_modules';

    if not force {
        if clean_stale {
            vite_bin = node_modules / '.bin' / 'vite';
            if node_modules.exists() and not vite_bin.exists() {
                shutil.rmtree(node_modules);
            }
        }
        if node_modules.exists() {
            return;
        }
    }

    configs_package_json = build_dir / 'configs' / 'package.json';
    if not configs_package_json.exists() {
        self.create_package_json();
    }
    build_package_json = build_dir / 'package.json';
    if configs_package_json.exists() and not build_package_json.exists() {
        shutil.copy2(configs_package_json, build_package_json);
    }
    configs_npmrc = build_dir / 'configs' / '.npmrc';
    build_npmrc = build_dir / '.npmrc';
    if configs_npmrc.exists() and not build_npmrc.exists() {
        shutil.copy2(configs_npmrc, build_npmrc);
    }

    try {
        console.print("\n  ⏳ Installing dependencies...\n");
        start_time = time.time();
        result = subprocess.run(
            [bun, 'install'],
            cwd=build_dir,
            check=False,
            text=True,
            capture_output=capture_output
        );
        elapsed = time.time() - start_time;
        if result.returncode != 0 {
            if capture_output {
                error_output = result.stderr or result.stdout;
                raise ClientBundleError(
                    f"Dependency installation failed after {elapsed:.1f}s\n\n{error_output}\nCommand: bun install"
                ) from None;
            }
            console.error(f"\n  ✖ bun install failed after {elapsed:.1f}s");
            raise ClientBundleError("Failed to install dependencies") from None;
        }
        console.print(f"\n  ✔ Dependencies installed ({elapsed:.1f}s)");
    } finally {
        if build_package_json.exists() {
            build_package_json.unlink();
        }
        if build_npmrc.exists() {
            build_npmrc.unlink();
        }

        build_bun_lockb = build_dir / 'bun.lockb';
        if build_bun_lockb.exists() {
            configs_bun_lockb = build_dir / 'configs' / 'bun.lockb';
            if configs_bun_lockb.exists() {
                configs_bun_lockb.unlink();
            }
            shutil.move(str(build_bun_lockb), str(configs_bun_lockb));
        }
    }
}

impl ViteBundler.add_packages(
    self: ViteBundler,
    packages: list[str],
    install_dir: Optional[Path] = None,
    dev: bool = False
) -> None {
    import json;
    import subprocess;
    import from jaclang.runtimelib.client { get_bun }
    target_dir = install_dir if install_dir is not None else self.project_dir;
    pkg_json = target_dir / 'package.json';
    if not pkg_json.exists() {
        pkg_data = {
            'name': 'jac-mobile-app',
            'version': '1.0.0',
            'private': True,
            'type': 'module'
        };
        pkg_json.write_text(json.dumps(pkg_data, indent=2), encoding='utf-8');
        console.print("  ✔ Created package.json");
    }

    bun = get_bun();
    if bun is None {
        raise RuntimeError("bun unavailable: cannot install client dependencies");
    }
    cmd = [bun, 'add'];
    if dev {
        cmd.append('--dev');
    }
    cmd.extend(packages);
    console.print(f"  Installing: {' '.join(packages)}");
    subprocess.run(cmd, cwd=target_dir, check=True, capture_output=False);
}

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
        } elif isinstance(value, list) {
            list_str = ', '.join(repr(v) for v in value);
            items.append(f"{indent_str}  {key}: [{list_str}],");
        } elif isinstance(value, dict) {
            nested = self._format_config_object(value, (indent + 2));
            items.append(f"{indent_str}  {key}: {{{nested}{indent_str}  }},");
        } else {
            items.append(f"{indent_str}  {key}: {repr(value)},");
        }
    }
    return '\n'.join(items);
}

impl ViteBundler._resolve_api_base_url(
    self: ViteBundler, api_base_url_override: str = ""
) -> str {
    api_config_data = self.config_loader.get_api_config();
    toml_base_url = api_config_data.get('base_url', '');
    env_override = os.environ.get(API_BASE_URL_ENV_VAR, '');
    return toml_base_url or api_base_url_override or env_override;
}


def _to_js_expr(value: any) -> str {
    if value is None {
        return "null";
    }

    if isinstance(value, bool) {
        return "true" if value else "false";
    }

    if isinstance(value, (int, float)) {
        return json.dumps(value);
    }

    if value?.isoformat {
        return json.dumps(json.dumps(value.isoformat()));
    }

    if isinstance(value, str) {
        return json.dumps(json.dumps(value));
    }

    try {
        return json.dumps(value);
    } except (TypeError, ValueError) {
        return json.dumps(json.dumps(str(value)));
    }
}

impl ViteBundler._format_define_entries(
    self: ViteBundler, api_base_url: str, custom_defines: dict
) -> str {
    entries = [];

    if api_base_url {
        entries.append(f"    '{JAC_API_BASE_URL_KEY}': {_to_js_expr(api_base_url)}");
    }
    for (key, value) in custom_defines.items() {
        entries.append(f"    '{key}': {_to_js_expr(value)}");
    }
    return ',\n'.join(entries);
}

impl ViteBundler._generate_vite_config_content(
    self: ViteBundler,
    is_dev: bool,
    entry_file: Path,
    api_base_url: str,
    base_path: str,
    api_port: int = 8000,
    for_mobile_dev: bool = False,
    mobile_hmr_host: str = "",
    mobile_hmr_port: int = 0,
    for_desktop_dev: bool = False,
    desktop_broker_port: int = 0
) -> str {
    build_dir = self._get_client_dir();
    vite_config_data = self.config_loader.get_vite_config();

    try {
        entry_relative = entry_file.relative_to(build_dir).as_posix();
    } except ValueError {
        entry_relative = entry_file.as_posix();
    }

    if entry_relative.endswith('/build/main.js') {
        compiled_base = entry_relative[:-13] + '/compiled';
    } else {
        compiled_base = 'compiled';
    }
    compiled_utils_relative = f"{compiled_base}/client_runtime.js";
    compiled_pwa_relative = f"{compiled_base}/pwa_runtime.js";
    compiled_desktop_relative = f"{compiled_base}/desktop_api.js";
    compiled_wasm_host_relative = f"{compiled_base}/wasm_host.js";
    compiled_ui_relative = f"{compiled_base}/client_mobui.js";
    compiled_assets_relative = f"{compiled_base}/assets";

    ui_alias_str = (
        f'\n      "@jac/mobui": path.resolve(buildDir, "{compiled_ui_relative}"),'
    );

    pkg_deps = self.config_loader.get_package_config().get('dependencies', {});
    if 'react-native-web' in pkg_deps {
        ui_alias_str += '\n      "react-native": "react-native-web",';
    }

    pwa_alias_str = '';
    if self.config_loader.is_pwa_enabled() {
        pwa_alias_str = f'\n      "@jac/pwa": path.resolve(buildDir, "{compiled_pwa_relative}"),';
    }

    framework_alias_str = '';
    framework_plugin_import = 'import react from "@vitejs/plugin-react";';
    framework_plugin_call = 'react()';
    try {
        import from jaclang.compiler.passes.ecmascript.backends.registry {
            resolve_active_backend
        }
        active_backend = resolve_active_backend();
        for (k, v) in active_backend.vite_aliases().items() {
            framework_alias_str += f'\n      "{k}": "{v}",';
        }
        plugin_lines = active_backend.vite_plugin_lines();
        if plugin_lines is not None {
            (framework_plugin_import, framework_plugin_call) = plugin_lines;
        }
    } except Exception as e {
        console.error(f"[jac warning] Failed to resolve framework backend config: {e}");
    }

    desktop_alias_str = '';
    if os.path.isfile(
        os.path.join(str(self._get_client_dir()), compiled_desktop_relative)
    ) {
        desktop_alias_str = f'\n      "@jac/desktop": path.resolve(buildDir, "{compiled_desktop_relative}"),';
    }

    wasm_host_alias_str = '';
    if os.path.isfile(
        os.path.join(str(self._get_client_dir()), compiled_wasm_host_relative)
    ) {
        wasm_host_alias_str = f'\n      "@jac/wasm_host": path.resolve(buildDir, "{compiled_wasm_host_relative}"),';
    }
    plugins = [];
    plugin_imports = [];
    plugin_imports.append(framework_plugin_import);
    plugins.append(f'    {framework_plugin_call}');
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

    extensions = ['.mjs', '.js', '.mts', '.ts', '.jsx', '.tsx', '.json'];
    extensions_str = ', '.join(f'"{ext}"' for ext in extensions);
    build_config = vite_config_data.get('build', {});
    resolve_config = vite_config_data.get('resolve', {});
    resolve_overrides_str = self._format_config_object(resolve_config, indent=6)
        if (isinstance(resolve_config, dict) and resolve_config)
        else '';

    paths_config = self.config_loader.get_paths_config();
    user_aliases_lines: list[str] = [];
    q = '"';
    for (alias_pattern, target_path) in paths_config.items() {
        alias_key = alias_pattern.rstrip('/*');

        target_clean = target_path.lstrip('./').rstrip('/*');
        user_aliases_lines.append(
            f'        {q}{alias_key}{q}: path.resolve(projectRoot, {q}{target_clean}{q}),'
        );
    }
    user_aliases_str = '\n' + '\n'.join(user_aliases_lines)
        if user_aliases_lines
        else '';
    define_config = vite_config_data.get('define', {});
    define_str = self._format_define_entries(api_base_url, define_config);
    imports_section = f"{imports_str}\n" if imports_str else '';
    newline = '\n';
    if is_dev {
        build_overrides_str = self._format_config_object(build_config, indent=2)
            if (isinstance(build_config, dict) and build_config)
            else '';
        server_config = vite_config_data.get('server', {});
        server_config_str = self._format_config_object(server_config, indent=2)
            if (isinstance(server_config, dict) and server_config)
            else '';

        reload_enabled: bool = for_mobile_dev or for_desktop_dev;
        if for_mobile_dev and mobile_hmr_host {
            hmr_host = mobile_hmr_host;
            hmr_port = mobile_hmr_port or 5173;
            mobile_hmr_str = (
                f'\n    hmr: {{ protocol: "ws", host: "{hmr_host}", port: {hmr_port}, clientPort: {hmr_port}, overlay: false }},'
            );
        } elif reload_enabled {
            mobile_hmr_str = "\n    hmr: { overlay: false },";
        } else {
            mobile_hmr_str = "";
        }
        compiled_reload_plug_in: str = "\n    jacCompiledReload(),"
            if reload_enabled
            else "";
        if for_mobile_dev and mobile_hmr_host {
            host_value = f'"{mobile_hmr_host}"';
        } elif for_desktop_dev {
            host_value = '"127.0.0.1"';
        } else {
            host_value = 'true';
        }
        desktop_server_extras: str = "";
        desktop_proxy_str: str = "";
        if for_desktop_dev {
            desktop_server_extras = "\n    strictPort: true,";
            broker_port: int = desktop_broker_port or 8000;
            desktop_proxy_str = (
                f'\n      "/__jac": {{'
                f'\n        target: "http://127.0.0.1:{broker_port}",'
                '\n        changeOrigin: true,'
                '\n      },'
            );
        }

        mobile_compiled_block: str = (
            r'''

// When Jac recompiles, push full-reload to the WebView (Capacitor does not watch project files)
function sendFullReload(server) {
  let sent = false;
  // Broadcast over the websocket first (works for both Vite 5 and Vite 6 clients).
  try {
    if (server.ws && typeof server.ws.send === "function") {
      server.ws.send({ type: "full-reload", path: "*" });
      sent = true;
    }
  } catch (e) {}
  // Vite 6 environment fallback for runners that expose environment hot channels.
  try {
    const envs = server.environments;
    if (envs && typeof envs === "object") {
      for (const k of Object.keys(envs)) {
        const env = envs[k];
        if (env && env.hot && typeof env.hot.send === "function") {
          env.hot.send({ type: "full-reload", path: "*" });
          sent = true;
        }
      }
    }
  } catch (e) {}
  return sent;
}

function jacCompiledReload() {
  return {
    name: "jac-compiled-reload",
    configureServer(server) {
      const compiled = path.resolve(buildDir, "compiled");
      try { server.watcher.add(compiled); } catch (e) {}
      let timer = null;
      const fire = (file) => {
        if (typeof file !== "string") return;
        const norm = file.split(path.sep).join("/");
        if (!norm.includes("/compiled/") || !norm.endsWith(".js")) return;
        if (timer) clearTimeout(timer);
        timer = setTimeout(() => {
          sendFullReload(server);
        }, 300);
      };
      server.watcher.on("change", fire);
      server.watcher.on("add", fire);
    },
    // Intercept hot updates for compiled files and force full-reload instead of module HMR
    handleHotUpdate(ctx) {
      const norm = ctx.file.split(path.sep).join("/");
      if (norm.includes("/compiled/") && norm.endsWith(".js")) {
        sendFullReload(ctx.server);
        return [];
      }
    },
  };
}
'''
                if reload_enabled
                else ""
        );
        config_content = f'''import {{ defineConfig }} from "vite";
import path from "path";
import fs from "fs";
import {{ fileURLToPath }} from "url";
{imports_section}const __dirname = path.dirname(fileURLToPath(import.meta.url));
const buildDir = path.resolve(__dirname, "..");
const projectRoot = path.resolve(__dirname, "../../..");
import jacFastRefresh from "./jac-fast-refresh.js";

// Vite plugin: forward client-side runtime errors to the terminal and browser overlay
function jacErrorReporter() {{
  const seen = new Map();
  return {{
    name: "jac-error-reporter",
    configureServer(server) {{
      server.ws.on("jac:client-error", (data) => {{
        const key = data.type + ":" + data.message;
        const now = Date.now();
        if (seen.get(key) > now - 2000) return;
        seen.set(key, now);
        let loc = "";
        if (data.source) {{
          try {{
            var p = new URL(data.source).pathname.slice(1)
              .replace("compiled/", "").replace(".vite/deps/", "");
            if (p.endsWith(".js")) p = p.slice(0, -3) + ".jac";
            loc = " (" + p;
            if (data.line) loc += ":" + data.line;
            if (data.column) loc += ":" + data.column;
            loc += ")";
          }} catch(e) {{}}
        }}
        console.error("Client error: " + data.type + ": " + data.message + loc);
        if (data.phase === "load") {{
          server.ws.send({{
            type: "error",
            err: {{
              message: data.message,
              stack: data.stack || "",
              id: data.source || "compiled/_entry.js",
              frame: "",
              plugin: "jac-error-reporter",
            }},
          }});
        }}
      }});
    }},
  }};
}}

// Vite plugin: write the bound dev-server port for the jac CLI to read
function jacPortReporter() {{
  return {{
    name: "jac-port-reporter",
    configureServer(server) {{
      server.httpServer?.once("listening", () => {{
        const addr = server.httpServer.address();
        if (addr && typeof addr === "object") {{
          fs.writeFileSync(path.resolve(buildDir, ".dev-port"), String(addr.port));
        }}
      }});
    }},
  }};
}}

// Vite plugin: surface Jac build errors via Vite's native error overlay.
// The jac dev server mirrors build health to .jac-build-error.json; the file
// existing means broken (show overlay), removed means recovered (reload).
function jacBuildErrorOverlay() {{
  const statusFile = path.resolve(buildDir, ".jac-build-error.json");
  let lastRaw = null;
  const read = () => {{
    try {{ return fs.readFileSync(statusFile, "utf-8"); }} catch (e) {{ return ""; }}
  }};
  return {{
    name: "jac-build-error-overlay",
    configureServer(server) {{
      const push = (raw) => {{
        if (raw === lastRaw) return;
        // lastRaw is the last KNOWN state, not the last sent one: record it
        // before any skip, or a recovery that happens with zero clients would
        // leave the old error latched here and dedup-suppress an identical
        // error recurring later.
        lastRaw = raw;
        // No live clients: skip the broadcast (Vite would buffer it and replay
        // stale state to the first client; the connection handler replays the
        // CURRENT state instead).
        if (server.ws.clients && server.ws.clients.size === 0) return;
        if (!raw) {{
          server.ws.send({{ type: "full-reload", path: "*" }});
          return;
        }}
        let file = "", message = raw;
        try {{
          const data = JSON.parse(raw);
          file = data.file || "";
          message = data.message || "Jac build error";
        }} catch (e) {{}}
        server.ws.send({{
          type: "error",
          err: {{ message: message, stack: "", id: file, plugin: "jac" }},
        }});
      }};
      try {{ server.watcher.add(statusFile); }} catch (e) {{}}
      const onWrite = (f) => {{ if (path.resolve(f) === statusFile) push(read()); }};
      server.watcher.on("add", onWrite);
      server.watcher.on("change", onWrite);
      server.watcher.on("unlink", (f) => {{
        const abs = path.resolve(f);
        if (abs === statusFile) {{
          push("");
          return;
        }}
        // A served module was deleted (e.g. its Jac source was removed while
        // still imported). Importers keep a cached transform pointing at the
        // dead file, which 404s into a blank page with no overlay. Invalidate
        // them and reload so the fresh transform surfaces Vite's own
        // "Failed to resolve import" error overlay.
        try {{
          const mods = server.moduleGraph.getModulesByFile(abs);
          if (mods && mods.size) {{
            let hadImporters = false;
            for (const mod of mods) {{
              for (const importer of mod.importers) {{
                hadImporters = true;
                server.moduleGraph.invalidateModule(importer);
              }}
              server.moduleGraph.invalidateModule(mod);
            }}
            if (hadImporters) {{
              server.ws.send({{ type: "full-reload", path: "*" }});
            }}
          }}
        }} catch (e) {{}}
      }});
      // A browser opened (or reloaded) while broken gets the overlay immediately
      server.ws.on("connection", () => {{
        const raw = read();
        if (raw) {{ lastRaw = null; push(raw); }}
      }});
    }},
  }};
}}
{mobile_compiled_block}
/**
 * Vite DEV configuration for HMR mode
 * Proxies API routes to Python server at localhost:{api_port}
 */
export default defineConfig({{
  base: "{base_path}",
  define: {{
{define_str}
  }},
  plugins: [
    jacErrorReporter(),
    jacPortReporter(),
    jacBuildErrorOverlay(),
    jacFastRefresh(),{compiled_reload_plug_in}{(
            newline + plugins_str + newline + '  '
        )
            if plugins_str
            else ''}],
  root: buildDir,
  envDir: projectRoot, // Load .env files from project root
  publicDir: false,
  appType: 'spa',
  build: {{
    sourcemap: true, // Enable source maps for better error messages{build_overrides_str}
  }},
  server: {{
    host: {host_value},
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
      "/static": {{
        target: "http://localhost:{api_port}",
        changeOrigin: true,
      }},
      "/docs": {{
        target: "http://localhost:{api_port}",
        changeOrigin: true,
      }},
      "/openapi.json": {{
        target: "http://localhost:{api_port}",
        changeOrigin: true,
      }},
      "/admin": {{
        target: "http://localhost:{api_port}",
        changeOrigin: true,
      }},
      "/graph": {{
        target: "http://localhost:{api_port}",
        changeOrigin: true,
      }},
      "/redoc": {{
        target: "http://localhost:{api_port}",
        changeOrigin: true,
      }},
      // Backend serves project assets/ dir in dev; Vite owns /assets/* only at build time.
      "/assets": {{
        target: "http://localhost:{api_port}",
        changeOrigin: true,
      }},{desktop_proxy_str}
    }},
{server_config_str}{mobile_hmr_str}{desktop_server_extras}
  }},
  resolve: {{
    alias: {{
      "@jac/runtime": path.resolve(buildDir, "{compiled_utils_relative}"),{pwa_alias_str}{desktop_alias_str}{wasm_host_alias_str}{framework_alias_str}{ui_alias_str}
      "@jac-client/assets": path.resolve(buildDir, "{compiled_assets_relative}"),{user_aliases_str}
    }},
    extensions: [{extensions_str}],
{resolve_overrides_str}
  }},
}});
''';
    } else {
        build_overrides_str = self._format_config_object(build_config, indent=2)
            if (isinstance(build_config, dict) and build_config)
            else '';
        server_config = vite_config_data.get('server', {});
        server_config_str = self._format_config_object(server_config, indent=2)
            if (isinstance(server_config, dict) and server_config)
            else '';
        server_section = f"  server: {{{newline}{server_config_str}{newline}  }},{newline}"
            if server_config_str
            else '';
        try {
            output_relative = self.output_dir.relative_to(build_dir).as_posix();
        } except ValueError {
            output_relative = self.output_dir.as_posix();
        }
        config_content = f'''import {{ defineConfig }} from "vite";
import path from "path";
import fs from "fs";
import {{ fileURLToPath }} from "url";
{imports_section}const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Config is in configs/ inside .jac/client/, so go up one level to .jac/client/, then up two more to project root
const buildDir = path.resolve(__dirname, "..");
const projectRoot = path.resolve(__dirname, "../../..");

// Jac source mapper plugin - maps errors back to original .jac files
function jacSourceMapper() {{
  const sourceMap = new Map(); // compiled path -> original jac path

  return {{
    name: 'jac-source-mapper',
    enforce: 'pre',

    // Extract source mapping and chain per-file source maps
    transform(code, id) {{
      if (id.includes('/compiled/') && id.endsWith('.js')) {{
        const match = code.match(/^\\/\\* Source: (.+?) \\*\\//);
        if (match) {{
          sourceMap.set(id, match[1]);
        }}
        // Load per-file .map if it exists and return it so Vite chains it
        const mapPath = id + '.map';
        try {{
          if (fs.existsSync(mapPath)) {{
            const rawMap = JSON.parse(fs.readFileSync(mapPath, 'utf-8'));
            return {{ code, map: rawMap }};
          }}
        }} catch (e) {{}}
      }}
      return null;
    }},

    // Enhance error messages with original source info
    buildEnd() {{
      // Store source map for error reporting
      this._jacSourceMap = sourceMap;
    }},

    // Handle resolve errors to show original source
    resolveId(source, importer) {{
      if (importer && sourceMap.has(importer)) {{
        const originalSource = sourceMap.get(importer);
        // Check for common issues like double slashes
        if (source.includes('//') && !source.startsWith('http')) {{
          this.error({{
            message: `Cannot resolve "${{source}}" - path contains invalid double slash. Check your import in the original Jac file.`,
            id: originalSource,
            loc: {{ line: 1, column: 0 }}
          }});
        }}
      }}
      return null;
    }}
  }};
}}

/**
 * Vite configuration generated from config.json (in project root)
 * To customize, edit config.json instead of this file.
 */

export default defineConfig({{
  base: "{base_path}",
  define: {{
{define_str}
  }},
  plugins: [
    jacSourceMapper(),{(newline + plugins_str + newline + '  ')
            if plugins_str
            else ''}],
  root: buildDir, // base folder (.jac/client/) so vite can find node_modules
  envDir: projectRoot, // Load .env files from project root
    build: {{
    sourcemap: true, // Enable source maps for better error messages
{build_overrides_str}
    rollupOptions: {{
      input: path.resolve(buildDir, "{entry_relative}"), // your compiled entry file
      output: {{
        entryFileNames: "client.[hash].js", // name of the final js file
        assetFileNames: (assetInfo) => assetInfo.name?.endsWith('.css') ? 'styles.css' : '[name].[ext]',
        sourcemapPathTransform: (relativeSourcePath) => {{
          // Transform source map paths to point to original location
          return relativeSourcePath;
        }},
      }},
    }},
    outDir: path.resolve(buildDir, "{output_relative}"), // final bundled output
    emptyOutDir: true,
  }},
  publicDir: false,
{server_section}  resolve: {{
      alias: {{
        "@jac/runtime": path.resolve(buildDir, "{compiled_utils_relative}"),{pwa_alias_str}{desktop_alias_str}{wasm_host_alias_str}{framework_alias_str}{ui_alias_str}
        "@jac-client/assets": path.resolve(buildDir, "{compiled_assets_relative}"),{user_aliases_str}
      }},
      extensions: [{extensions_str}],
{resolve_overrides_str}
  }},
}});
''';
    }
    return config_content;
}

impl ViteBundler.create_vite_config(
    self: ViteBundler,
    entry_file: Path,
    api_base_url_override: str = "",
    is_dev: bool = False,
    api_port: int = 8000,
    for_mobile_dev: bool = False,
    mobile_hmr_host: str = "",
    mobile_hmr_port: int = 0,
    for_desktop_dev: bool = False,
    desktop_broker_port: int = 0
) -> Path {
    build_dir = self._get_client_dir();
    build_dir.mkdir(parents=True, exist_ok=True);
    configs_dir = build_dir / 'configs';
    configs_dir.mkdir(exist_ok=True);
    api_base_url = self._resolve_api_base_url(api_base_url_override);
    config_filename = 'vite.dev.config.js' if is_dev else 'vite.config.js';
    config_path = configs_dir / config_filename;
    base_path = self.config_loader.get_base_path();
    config_content = self._generate_vite_config_content(
        is_dev=is_dev,
        entry_file=entry_file,
        api_base_url=api_base_url,
        base_path=base_path,
        api_port=api_port,
        for_mobile_dev=for_mobile_dev,
        mobile_hmr_host=mobile_hmr_host,
        mobile_hmr_port=mobile_hmr_port,
        for_desktop_dev=for_desktop_dev,
        desktop_broker_port=desktop_broker_port
    );
    config_path.write_text(config_content, encoding='utf-8');
    if is_dev {
        self._write_fast_refresh_plugin(configs_dir);
    }
    return config_path;
}

impl ViteBundler.read_bundle(self: ViteBundler) -> tuple[str, str] {
    bundle_file = self.find_bundle();
    if not bundle_file {
        raise ClientBundleError('Vite build completed but no bundle file found');
    }
    bundle_code = bundle_file.read_text(encoding='utf-8');
    bundle_hash = hashlib.sha256(bundle_code.encode('utf-8')).hexdigest();
    return (bundle_code, bundle_hash);
}

impl ViteBundler.find_css(self: ViteBundler) -> Optional[Path] {
    css_file = self.output_dir / 'styles.css';
    return css_file if css_file.exists() else None;
}

impl ViteBundler.find_bundle(self: ViteBundler) -> Optional[Path] {
    for file in self.output_dir.glob('client.*.js') {
        return file;
    }
    return None;
}

impl ViteBundler.build(self: ViteBundler, entry_file: Optional[Path] = None) -> None {
    import time;
    import from jaclang.runtimelib.client { ensure_client_deps }

    bun = _require_bun();

    if not ensure_client_deps(self.config_loader) {
        raise ClientBundleError(
            'Client dependencies not configured. Add [dependencies.npm] to jac.toml '
            'or create a project with: jac create --kind web-app'
        ) from None;
    }
    self.output_dir.mkdir(parents=True, exist_ok=True);

    self.create_package_json();
    build_dir = self._get_client_dir();

    self.install_packages(install_dir=build_dir, capture_output=True, clean_stale=True);
    if self.config_path {
        try {
            config_rel = self.config_path.relative_to(build_dir);
            command = [bun, 'x', 'vite', 'build', '--config', str(config_rel)];
        } except ValueError {
            command = [bun, 'x', 'vite', 'build', '--config', str(self.config_path)];
        }
    } elif entry_file {
        generated_config = self.create_vite_config(entry_file);
        config_rel = generated_config.relative_to(build_dir);
        command = [bun, 'x', 'vite', 'build', '--config', str(config_rel)];
    } else {
        command = [bun, 'run', 'build'];
    }

    console.print("\n  ⏳ Building client bundle...\n");
    start_time = time.time();
    result = subprocess.run(
        command, cwd=build_dir, check=False, text=True, capture_output=True
    );
    elapsed = time.time() - start_time;
    if result.returncode != 0 {
        error_output = result.stderr or result.stdout;
        error_msg = f"Vite build failed after {elapsed:.1f}s\n\n{error_output}\nCommand: {' '.join(
            command
        )}";
        raise ClientBundleError(error_msg) from None;
    }
    console.print(f"\n  ✔ Client bundle built ({elapsed:.1f}s)");
}

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

    self.output_dir = output_dir or (self._get_client_dir() / 'dist');

    self.dev_server_port = 0;
}

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
        if not isinstance(config_data, dict) {
            continue;
        }
        extension = config_data.get('extension', '.js');
        config_path = configs_dir / f'{config_name}.config{extension}';

        if 'raw' in config_data {
            file_content = _toml_config_from_raw(config_data);
        } else {
            file_content = _toml_config_to_js(config_data);
        }
        config_path.write_text(file_content, encoding='utf-8');
        created_files.append(config_path);
    }
    return created_files;
}

impl ViteBundler.create_npmrc(self: ViteBundler) -> Optional[Path] {
    npm_config = self.config_loader.get_npm_config();
    if not npm_config {
        return None;
    }
    build_dir = self._get_client_dir();
    configs_dir = build_dir / 'configs';
    configs_dir.mkdir(parents=True, exist_ok=True);
    npmrc_path = configs_dir / '.npmrc';
    lines: list[str] = [];

    known_keys = {'scoped_registries', 'auth', 'settings'};
    settings = npm_config.get('settings', {});
    for (key, value) in settings.items() {
        if isinstance(value, bool) {
            lines.append(f"{key}={str(value).lower()}");
        } else {
            lines.append(f"{key}={value}");
        }
    }

    scoped_registries = npm_config.get('scoped_registries', {});
    for (scope, registry_url) in scoped_registries.items() {
        lines.append(f"{scope}:registry={registry_url}");
    }

    auth = npm_config.get('auth', {});
    for (registry_path, auth_data) in auth.items() {
        if isinstance(auth_data, dict) {
            for (key, value) in auth_data.items() {
                lines.append(f"{registry_path}:{key}={value}");
            }
        } elif isinstance(auth_data, str) {
            lines.append(f"{registry_path}={auth_data}");
        }
    }
    if not lines {
        return None;
    }
    npmrc_path.write_text('\n'.join(lines) + '\n', encoding='utf-8');
    return npmrc_path;
}

def _toml_config_to_js(config_data: dict) -> str {
    return f"module.exports = {json.dumps(
        {
            k: v
            for (k, v) in config_data.items()
            if k not in CONFIG_META_KEYS
        },
        indent=2
    )};\n";
}

def _toml_config_from_raw(config_data: dict) -> str {
    content = str(config_data.get('raw', '')).strip();
    return content + '\n' if content else '';
}

def _build_vite_dev_command(config_rel: Path, port: int, host: str = "") -> list[str] {
    bun = _require_bun();
    cmd = [bun, 'x', 'vite', '--config', str(config_rel), '--port', str(port)];
    if host {
        cmd.append('--host');
        cmd.append(host);
    } else {
        cmd.append('--host');
    }
    return cmd;
}

def _is_vite_ready_line(line: str) -> bool {
    line_lower = line.lower();
    for pattern in VITE_READY_PATTERNS {
        if pattern in line_lower {
            return True;
        }
    }
    return False;
}

def _is_vite_url_line(line: str) -> bool {
    for pattern in VITE_URL_PATTERNS {
        if pattern in line {
            return True;
        }
    }
    return False;
}

def _forward_vite_output(
    proc: any, ready_event: "threading.Event", sys_module: any, output_buffer: list[str]
) {
    try {
        for line in iter(proc.stdout.readline, '') {
            if not line {
                break;
            }

            if _is_vite_ready_line(line) {
                ready_event.set();
            }
            if ready_event.is_set() {
                if '[HMR]' in line or not _is_vite_url_line(line) {
                    sys_module.stdout.write(line);
                    sys_module.stdout.flush();
                }
            } else {
                output_buffer.append(line);
            }
        }
    } except Exception {
        ;
    }
}

impl ViteBundler.start_dev_server(
    self: ViteBundler,
    port: int = 3000,
    suppress_initial_output: bool = False,
    host: str = ""
) -> any {
    import sys;
    import time;
    import threading;
    import from jaclang.runtimelib.client { get_bun }

    if get_bun() is None {
        raise ClientBundleError(
            'Bun is required for dev server. Install manually: https://bun.sh'
        ) from None;
    }
    build_dir = self._get_client_dir();
    self._ensure_dev_index_html(build_dir);
    self._ensure_dev_dependencies(build_dir);

    dev_config = build_dir / 'configs' / 'vite.dev.config.js';
    if not dev_config.exists() {
        raise ClientBundleError(
            "Dev config not found. Call create_vite_config(is_dev=True) first."
        );
    }
    try {
        config_rel = dev_config.relative_to(build_dir);
    } except ValueError {
        config_rel = dev_config;
    }
    command = _build_vite_dev_command(config_rel, port, host=host);

    self.dev_server_port = port;
    (build_dir / '.dev-port').unlink(missing_ok=True);
    if suppress_initial_output {
        process = self._start_vite_with_output_capture(command, build_dir, sys);
    } else {
        process = subprocess.Popen(command, cwd=build_dir);
    }
    return process;
}

impl ViteBundler._ensure_dev_index_html(self: ViteBundler, build_dir: Path) -> None {
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
    <script type="module">
    if (import.meta.hot) {
      function report(d) {
        try { import.meta.hot.send("jac:client-error", d); } catch(e) {}
      }
      window.addEventListener("error", function(e) {
        report({
          type: e.error ? e.error.constructor.name : "Error",
          message: e.error ? e.error.message : e.message,
          stack: e.error ? e.error.stack : null,
          source: e.filename || null,
          line: e.lineno || null,
          column: e.colno || null
        });
      });
      window.addEventListener("unhandledrejection", function(e) {
        var r = e.reason;
        report({
          type: r instanceof Error ? r.constructor.name : "UnhandledPromiseRejection",
          message: r instanceof Error ? r.message : String(r),
          stack: r instanceof Error ? r.stack : null,
          source: null, line: null, column: null
        });
      });
      // react-refresh's global hook must install before React loads
      import("/@react-refresh").then(function(RefreshRuntime) {
        RefreshRuntime.injectIntoGlobalHook(window);
        window.$RefreshReg$ = function() {};
        window.$RefreshSig$ = function() { return function(type) { return type; }; };
        window.__jac_refresh_installed__ = true;
        return import("/compiled/_entry.js");
      }).catch(function(err) {
        report({
          type: err instanceof Error ? err.constructor.name : "Error",
          message: err instanceof Error ? err.message : String(err),
          stack: err instanceof Error ? err.stack : null,
          source: null, line: null, column: null,
          phase: "load"
        });
      });
    } else {
      import("/compiled/_entry.js").catch(function() {});
    }
    </script>
  </body>
</html>
''';
    index_html.write_text(index_content, encoding='utf-8');
}

impl ViteBundler._write_fast_refresh_plugin(
    self: ViteBundler, configs_dir: Path
) -> None {
    plugin_js = r'''// jac-fast-refresh.js (generated) - React Fast Refresh for Jac's compiled modules.
export default function jacFastRefresh() {
  return {
    name: "jac-fast-refresh",
    apply: "serve",
    transform(code, id) {
      const clean = id.split("?")[0];
      if (!clean.includes("/compiled/")) return null;
      if (!clean.endsWith(".js")) return null;
      if (code.indexOf("/*jac-fr*/") !== -1) return null;
      // The compiler stamps modules whose every export is a component; anything
      // unstamped (globs, helpers, router wiring) keeps full-reload semantics.
      if (code.indexOf("/*jac:refresh-boundary*/") === -1) return null;

      const modId = JSON.stringify(clean);
      // same self-accepting boundary @vitejs/plugin-react appends to JSX modules
      const header = '/*jac-fr*/import * as RefreshRuntime from "/@react-refresh";\n';

      const footer =
        "\nif (import.meta.hot) {" +
        "RefreshRuntime.__hmr_import(import.meta.url).then(function (currentExports) {" +
        "RefreshRuntime.registerExportsForReactRefresh(" + modId + ", currentExports);" +
        "import.meta.hot.accept(function (nextExports) {" +
        "if (!nextExports) return;" +
        "const inv = RefreshRuntime.validateRefreshBoundaryAndEnqueueUpdate(" + modId + ", currentExports, nextExports);" +
        "if (inv) import.meta.hot.invalidate(inv);" +
        "});" +
        "});" +
        "}\n";

      // header is exactly one line, so one empty mapping row keeps the sourcemap chain
      let map = null;
      try {
        map = this.getCombinedSourcemap();
        map.mappings = ";" + map.mappings;
      } catch (e) {
        map = null;
      }
      return { code: header + code + footer, map: map };
    }
  };
}
''';
    (configs_dir / 'jac-fast-refresh.js').write_text(plugin_js, encoding='utf-8');
}

impl ViteBundler._ensure_dev_dependencies(self: ViteBundler, build_dir: Path) -> None {
    self.install_packages(install_dir=build_dir);
}

impl ViteBundler._start_vite_with_output_capture(
    self: ViteBundler, command: list[str], build_dir: Path, sys_module: any
) -> any {
    import threading;
    import time;
    process = subprocess.Popen(
        command,
        cwd=build_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    );
    ready_event = threading.Event();
    output_buffer: list[str] = [];
    output_thread = threading.Thread(
        target=_forward_vite_output,
        args=(process, ready_event, sys_module, output_buffer),
        daemon=True
    );
    output_thread.start();

    is_ready = ready_event.wait(timeout=VITE_READY_TIMEOUT_SECONDS);
    if is_ready {
        port_file = build_dir / '.dev-port';
        for _ in range(40) {
            if port_file.exists() {
                break;
            }
            time.sleep(0.05);
        }
        try {
            self.dev_server_port = int(port_file.read_text().strip());
        } except (OSError, ValueError) {
            ;
        }
        console.print("  ✔ Vite dev server ready", style="success");
    } else {
        exit_code = process.poll();
        if exit_code is not None {
            console.error("  ✖ Vite dev server failed to start");
            if output_buffer {
                console.print("\n  Vite output:");
                for line in output_buffer {
                    sys_module.stdout.write(f"    {line}");
                }
                sys_module.stdout.flush();
            }
        } else {
            console.warning(
                f"  ⚠ Vite server may not be ready (timeout after {VITE_READY_TIMEOUT_SECONDS}s)"
            );
        }
    }
    return process;
}
