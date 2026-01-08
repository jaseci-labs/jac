"""Implementation details for HMR development server."""

import sys;
import shutil;
import from watchdog.events { FileSystemEvent }

# Template strings for generated files
glob RUNTIME_STUB: str = '''
import React from 'react';

export function __jacJsx(component, props, children) {
  const validChildren = Array.isArray(children) ? children.flat() : (children ? [children] : []);
  return typeof component === 'string'
    ? React.createElement(component, props, ...validChildren)
    : React.createElement(component, { ...props, children: validChildren });
}

export function __jacSpawn(walker, target) {
  console.warn('__jacSpawn not implemented in dev mode');
  return null;
}

export default { __jacJsx, __jacSpawn };
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

"""Write content to file, creating parent dirs if needed."""
def write_file(path: Path, content: str) -> None {
    path.parent.mkdir(parents=True, exist_ok=True);
    path.write_text(content, encoding='utf-8');
}

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

"""Start file watcher for .jac files."""
impl ViteDevServer.start_file_watcher{
    watcher = JacFileWatcher(
        project_dir=self.project_dir,
        compiled_modules=self.compiled_modules,
        verbose=self.verbose
    );
    self.watcher_thread = threading.Thread(target=watcher.start, daemon=True);
    self.watcher_thread.start();
    if self.verbose {
        print("Watching .jac files for changes...");
    }
}

"""Create vite.config.js for dev server."""
impl ViteDevServer.create_vite_config{
    client_dir = get_client_dir(self.project_dir);
    client_dir.mkdir(parents=True, exist_ok=True);
    # Write vite.config.js
    config_content = f'''import {{ defineConfig }} from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({{
  plugins: [react()],
  server: {{ host: '{self.host}', port: {self.port}, strictPort: true }},
  resolve: {{
    alias: {{
      '@jac-client/utils': '{client_dir}/client_runtime.js',
      '@jac-client/assets': '{self.project_dir}/assets'
    }}
  }}
}});
''';
    write_file(client_dir / 'vite.config.js', config_content);
    write_file(client_dir / 'main.js', MAIN_JS);
    write_file(client_dir / 'index.html', INDEX_HTML);
    # Compile client_runtime from plugin source
    runtime_path = client_dir / 'client_runtime.js';
    import from jaclang.pycore.program { JacProgram }
    import from pathlib { Path as PathLib }
    plugin_dir = PathLib(__file__).parent.parent.parent;
    runtime_source = plugin_dir / 'client_runtime.cl.jac';
    if runtime_source.exists() {
        prog = JacProgram();
        ir = prog.compile(file_path=str(runtime_source));
        if not prog.errors_had and ir.gen.js {
            runtime_js = ir.gen.js;
            if 'import React' not in runtime_js {
                runtime_js = "import React from 'react';\n" + runtime_js;
            }
            write_file(runtime_path, runtime_js);
            if self.verbose {
                print(f"Compiled client_runtime.js from {runtime_source}");
            }
        } else {
            if self.verbose {
                print("Warning: Failed to compile client_runtime, using stub");
            }
            self._create_runtime_stub(runtime_path);
        }
    } else {
        if self.verbose {
            print(f"Warning: {runtime_source} not found, using stub");
        }
        self._create_runtime_stub(runtime_path);
    }
    if self.verbose {
        print(f"Created Vite config at {client_dir / 'vite.config.js'}");
    }
}

"""Start the Vite dev server."""
impl ViteDevServer.start{
    if not self.is_vite_available() {
        print(
            "Error: npx/npm not found. Please install Node.js and npm.",
            file=sys.stderr
        );
        sys.exit(1);
    }
    print("Compiling .jac files...");
    self.compile_all_jac_files();
    print("Generating Vite configuration...");
    self.create_vite_config();
    self.start_file_watcher();
    client_dir = get_client_dir(self.project_dir);
    print(f"\nStarting Vite dev server at http://{self.host}:{self.port}");
    print("   Press Ctrl+C to stop\n");
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
                    print(line, end='');
                }
            }
        }
        self.vite_process.wait();
    } except KeyboardInterrupt {
        print("\n\nShutting down dev server...");
        self.stop();
    } except Exception as e {
        print(f"Error starting Vite dev server: {e}", file=sys.stderr);
        self.stop();
        sys.exit(1);
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
    print("Dev server stopped.");
}

"""Start watching .jac files for changes."""
impl JacFileWatcher.start{
    import from watchdog.events { FileSystemEventHandler }
    watcher_ref = self;
    class JacChangeHandler(FileSystemEventHandler) {
        def on_modified(self: JacChangeHandler, event: FileSystemEvent) -> None {
            event_path = Path(event.src_path);
            try {
                if event_path.is_relative_to(watcher_ref.project_dir / '.jac') {
                    return;
                }
            } except (ValueError, AttributeError) {
                pass;
            }

            ext = '.' + event.src_path.rsplit('.', 1)[-1]
            if '.' in event.src_path
            else '';
            if not event.is_directory and (ext == '.jac' or ext in JS_EXTENSIONS) {
                watcher_ref.on_file_changed(event_path);
            }
        }

        def on_deleted(self: JacChangeHandler, event: FileSystemEvent) -> None {
            if event.is_directory {
                return;
            }
            event_path = Path(event.src_path);
            ext = event_path.suffix;
            if ext == '.jac' or ext in JS_EXTENSIONS {
                client_dir = get_client_dir(watcher_ref.project_dir);
                src_dir = watcher_ref.project_dir / 'src';
                source_root = src_dir
                if event_path.is_relative_to(src_dir)
                else event_path.parent;
                output_path = calc_output_path(
                    event_path.with_suffix('.js') if ext == '.jac' else event_path,
                    source_root,
                    client_dir
                );
                if output_path.exists() {
                    output_path.unlink();
                    if watcher_ref.verbose {
                        print(f"[HMR] Deleted: {output_path.name}");
                    }
                }
                watcher_ref.compiled_modules.discard(event_path.resolve());
            }
        }
    }
    self.observer = Observer();
    self.observer.schedule(JacChangeHandler(), str(self.project_dir), recursive=True);
    self.observer.start();
    try {
        while True {
            time.sleep(1);
        }
    } except KeyboardInterrupt {
        self.stop();
    }
}

"""Stop watching .jac files."""
impl JacFileWatcher.stop{
    if self.observer {
        self.observer.stop();
        self.observer.join();
    }
}

"""Handle file changes and recompile or copy."""
impl JacFileWatcher.on_file_changed(file_path: Path) -> None {
    if self.verbose {
        print(f"[HMR] Detected change in: {file_path}");
    }
    client_dir = get_client_dir(self.project_dir);
    file_resolved: Path = file_path.resolve();
    is_in_graph = file_resolved in self.compiled_modules;
    src_dir = self.project_dir / 'src';
    source_root: Path;
    try {
        source_root = src_dir
        if file_path.is_relative_to(src_dir)
        else file_path.parent;
    } except ValueError {
        source_root = file_path.parent;
    }
    compiler = HMRCompiler(project_dir=self.project_dir, verbose=self.verbose);
    if file_path.suffix == '.jac' {
        (js_output, _) = compiler._compile_to_js(file_path);
        output_path = calc_output_path(file_path, source_root, client_dir, '.js');
        write_file(output_path, js_output);
        has_error = 'ErrorOverlay' in js_output;
        if self.verbose {
            if has_error {
                print(f"[HMR] ❌ Error in {file_path.name} (see browser)");
            } else {
                status = "✅ Recompiled"
                if is_in_graph
                else "⚠️  Compiled (not in import graph)";
                print(f"[HMR] {status}: {file_path.name}");
            }
        }
        if not is_in_graph {
            self.compiled_modules.add(file_resolved);
            if self.verbose and not has_error {
                print(
                    f"[HMR] ℹ️  To see changes, import {file_path.name} in your module graph"
                );
            }
        }
    } elif file_path.suffix in JS_EXTENSIONS {
        try {
            output_path = calc_output_path(file_path, source_root, client_dir);
            output_path.parent.mkdir(parents=True, exist_ok=True);
            shutil.copy2(file_path, output_path);
            if self.verbose {
                status = "✅ Copied"
                if is_in_graph
                else "⚠️  Copied (not in import graph)";
                print(f"[HMR] {status}: {file_path.name}");
            }
            if not is_in_graph {
                self.compiled_modules.add(file_resolved);
            }
        } except Exception as e {
            print(f"[HMR] ❌ Error copying {file_path.name}: {e}", file=sys.stderr);
        }
    }
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
