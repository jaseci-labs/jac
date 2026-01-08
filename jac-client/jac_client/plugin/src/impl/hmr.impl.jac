"""Implementation details for HMR development server."""

import sys;
import shutil;

glob RUNTIME_STUB: str = '''
import React from 'react';

console.warn('Using minimal runtime stub. Full runtime failed to compile.');

export function __jacJsx(component, props, children) {
  const validChildren = Array.isArray(children) ? children.flat() : (children ? [children] : []);
  return typeof component === 'string'
    ? React.createElement(component, props, ...validChildren)
    : React.createElement(component, { ...props, children: validChildren });
}

export function __jacSpawn(walker, target, fields = {}) {
  console.error('Runtime not properly loaded. Walker spawn unavailable.');
  return Promise.reject(new Error('Runtime stub: __jacSpawn not available'));
}

export function jacSpawn(walker, target, fields = {}) {
  return __jacSpawn(walker, target, fields);
}

export default { __jacJsx, __jacSpawn, jacSpawn };
''',
     MAIN_JS: str = '''import React from 'react';
import ReactDOM from 'react-dom/client';
import { app } from './app.js';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(React.createElement(app));
''',
     ERROR_OVERLAY: str = '''
export default function ErrorOverlay({ error }) {
  return (
    <div style={{
      position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
      background: 'rgba(0, 0, 0, 0.9)', color: '#ff6b6b', padding: '2rem',
      fontFamily: 'monospace', fontSize: '14px', overflow: 'auto', zIndex: 9999
    }}>
      <div style={{ maxWidth: '800px', margin: '0 auto' }}>
        <h1 style={{ color: '#ff6b6b', fontSize: '24px', marginBottom: '1rem' }}>Compilation Error</h1>
        <div style={{ background: '#1a1a1a', padding: '1rem', borderRadius: '4px', whiteSpace: 'pre-wrap' }}>
          {error}
        </div>
        <p style={{ marginTop: '1rem', color: '#888' }}>Fix the error and save to continue.</p>
      </div>
    </div>
  );
}
''',
     INDEX_HTML: str = '''<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Jac Dev Server</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/main.js"></script>
  </body>
</html>
''';

"""Generate error display JS module."""
def generate_error_js(file_path: Path, error_msg: str) -> str {
    escaped = error_msg.replace('\\', '\\\\').replace("'", "\\'").replace('\n', '\\n');
    return f'''import React from 'react';
{ERROR_OVERLAY}
export const {file_path.stem} = () => ErrorOverlay({{ error: '{escaped}' }});
''';
}

"""Check if Vite is available in the project."""
impl ViteDevServer.is_vite_available{
    try {
        subprocess.run(
            ['npx', '--version'], capture_output=True, check=True, cwd=self.project_dir
        );
        return True;
    } except (subprocess.CalledProcessError, FileNotFoundError) {
        return False;
    }
}

"""Create minimal runtime stub as fallback."""
impl ViteDevServer._create_runtime_stub(runtime_path: Path) -> None {
    write_file(runtime_path, RUNTIME_STUB);
}

"""Compile .jac files recursively following imports, copy .js/.tsx files."""
impl ViteDevServer.compile_all_jac_files{
    client_dir = get_client_dir(self.project_dir);
    compiler = HMRCompiler(project_dir=self.project_dir, verbose=self.verbose);
    if self.module_path.exists() {
        self.compiled_modules = compiler.compile_recursively(
            self.module_path, client_dir
        );
    }
}

"""Create vite.config.js for dev server."""
impl ViteDevServer.create_vite_config{
    client_dir = get_client_dir(self.project_dir);
    client_dir.mkdir(parents=True, exist_ok=True);
    config_content = f'''import {{ defineConfig }} from 'vite';
import react from '@vitejs/plugin-react';
import {{ fileURLToPath }} from 'url';
import {{ dirname, resolve }} from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export default defineConfig({{
  plugins: [react()],
  server: {{
    host: '{self.host}',
    port: {self.port},
    strictPort: true,
    watch: {{
      usePolling: true,
      interval: 100
    }},
    proxy: {{
      '/user': {{
        target: 'http://localhost:{self.be_port}',
        changeOrigin: true
      }},
      '/function': {{
        target: 'http://localhost:{self.be_port}',
        changeOrigin: true
      }},
      '/walker': {{
        target: 'http://localhost:{self.be_port}',
        changeOrigin: true
      }},
      '/functions': {{
        target: 'http://localhost:{self.be_port}',
        changeOrigin: true
      }},
      '/walkers': {{
        target: 'http://localhost:{self.be_port}',
        changeOrigin: true
      }},
      '/assets': {{
        target: 'http://localhost:{self.be_port}',
        changeOrigin: true
      }}
    }}
  }},
  resolve: {{
    alias: {{
      '@jac-client/utils': resolve(__dirname, 'client_runtime.js'),
      '@jac-client/assets': resolve('{self.project_dir}', 'assets')
    }}
  }}
}});
''';
    write_file(client_dir / 'vite.config.js', config_content);
    module_name = self.module_path.stem;
    main_js_content = f'''import React from 'react';
import ReactDOM from 'react-dom/client';
import {{ {module_name} }} from './{module_name}.js';

let root = ReactDOM.createRoot(document.getElementById('root'));

function render() {{
  root.render(React.createElement({module_name}));
}}

render();

if (import.meta.hot) {{
  import.meta.hot.on('vite:beforeFullReload', () => {{
    console.log('[HMR] Full reload triggered');
  }});
}}
''';
    write_file(client_dir / 'main.js', main_js_content);
    write_file(client_dir / 'index.html', INDEX_HTML);
    runtime_path = client_dir / 'client_runtime.js';
    import from jaclang.pycore.program { JacProgram }
    import from pathlib { Path as PathLib }
    plugin_dir = PathLib(__file__).parent.parent;
    runtime_source = plugin_dir / 'client_runtime.cl.jac';
    if runtime_source.exists() {
        prog = JacProgram();
        ir = prog.compile(file_path=str(runtime_source));
        if not prog.errors_had and ir.gen.js {
            runtime_js = ir.gen.js;
            write_file(runtime_path, runtime_js);
            if self.verbose {
                print(
                    f"[jac-client] ✅ Compiled client_runtime.js from {runtime_source.name}"
                );
            }
        } else {
            if self.verbose {
                print(
                    f"[jac-client] ⚠️  Failed to compile {runtime_source.name}, using minimal stub"
                );
                if prog.errors_had {
                    for error in prog.errors_had {
                        print(f"  Error: {error}");
                    }
                }
            }
            self._create_runtime_stub(runtime_path);
        }
    } else {
        if self.verbose {
            print(f"[jac-client] ⚠️  {runtime_source} not found, using minimal stub");
        }
        self._create_runtime_stub(runtime_path);
    }
    if self.verbose {
        print(f"Created Vite config at {client_dir / 'vite.config.js'}");
    }
}

"""Start the Vite dev server. Core handles file watching via on_frontend_file_change hook."""
impl ViteDevServer.start{
    if not self.is_vite_available() {
        print(
            "[jac-client] Error: npx/npm not found. Please install Node.js and npm.",
            file=sys.stderr
        );
        return;
    }
    print("[jac-client] Compiling .jac files...");
    self.compile_all_jac_files();
    print("[jac-client] Generating Vite configuration...");
    self.create_vite_config();
    client_dir = get_client_dir(self.project_dir);
    print(f"[jac-client] Starting Vite dev server at http://{self.host}:{self.port}");
    try {
        self.vite_process = subprocess.Popen(
            ['npx', 'vite', '--host', self.host, '--port', str(self.port)],
            cwd=client_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        );
        if self.vite_process.stdout {
            for line in iter(self.vite_process.stdout.readline, '') {
                if line {
                    print(f"[Vite] {line}", end='');
                }
            }
        }
        self.vite_process.wait();
    } except KeyboardInterrupt {
        print("\n[jac-client] Shutting down Vite server...");
        self.stop();
    } except Exception as e {
        print(f"[jac-client] Error starting Vite dev server: {e}", file=sys.stderr);
        self.stop();
    }
}

"""Stop the Vite dev server."""
impl ViteDevServer.stop{
    if self.vite_process {
        try {
            self.vite_process.terminate();
            self.vite_process.wait(timeout=5);
        } except subprocess.TimeoutExpired {
            self.vite_process.kill();
        }
        self.vite_process = None;
    }
    print("[jac-client] Dev server stopped.");
}

"""Recursively compile .jac files following imports, copy .js/.tsx files."""
impl HMRCompiler.compile_recursively(
    module_path: Path,
    client_dir: Path,
    visited: (set[Path] | None) = None,
    source_root: (Path | None) = None
) -> set[Path] {
    visited = visited or set();
    module_path = module_path.resolve();
    if module_path in visited {
        return visited;
    }
    visited.add(module_path);
    source_root = source_root or module_path.parent.resolve();
    if module_path.suffix == '.jac' {
        (js_output, manifest) = self._compile_to_js(module_path);
        output_path = calc_output_path(module_path, source_root, client_dir, '.js');
        write_file(output_path, js_output);
        if self.verbose {
            print(f"Compiled: {module_path} -> {output_path}");
        }
        # Recursively process imports
        if manifest and manifest.imports {
            for (_, import_path) in manifest.imports.items() {
                path_obj = Path(import_path).resolve();
                if path_obj not in visited and path_obj.exists() {
                    self.compile_recursively(
                        path_obj, client_dir, visited, source_root
                    );
                }
            }
        }
    } elif module_path.suffix in JS_EXTENSIONS {
        output_path = calc_output_path(module_path, source_root, client_dir);
        output_path.parent.mkdir(parents=True, exist_ok=True);
        shutil.copy2(module_path, output_path);
        if self.verbose {
            print(f"Copied: {module_path} -> {output_path}");
        }
    }
    return visited;
}

"""Compile a .jac module to JavaScript and return output with manifest."""
impl HMRCompiler._compile_to_js(module_path: Path) -> tuple[str, Any] {
    import from jaclang.pycore.program { JacProgram }
    prog = JacProgram();
    ir = prog.compile(file_path=str(module_path));
    if prog.errors_had {
        error_msg = '\n'.join(str(e) for e in prog.errors_had);
        return (generate_error_js(module_path, error_msg), None);
    }
    js_output = ir.gen.js or '';
    if not js_output.strip() {
        return (generate_error_js(module_path, 'No output generated.'), None);
    }
    manifest = ir.gen.client_manifest;
    if manifest {
        js_output = f'import {{__jacJsx, __jacSpawn}} from "@jac-client/utils";\n{js_output}';
    }
    return (js_output, manifest);
}

"""Compile a .jac module to JavaScript file (legacy interface)."""
impl HMRCompiler.compile_module(module_path: Path, output_path: Path) -> None {
    (js_output, _) = self._compile_to_js(module_path);
    write_file(output_path, js_output);
    if self.verbose {
        print(f"Compiled {module_path} -> {output_path}");
    }
}
