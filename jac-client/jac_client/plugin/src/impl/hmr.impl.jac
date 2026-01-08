"""Implementation details for HMR development server."""

import sys;
import shutil;
import from watchdog.events { FileSystemEvent }

"""Check if Vite is available in the project."""
impl ViteDevServer.is_vite_available {
    try {
        # Check if npx is available
        subprocess.run(
            ['npx', '--version'],
            capture_output=True,
            check=True,
            cwd=self.project_dir
        );
        return True;
    } except (subprocess.CalledProcessError, FileNotFoundError) {
        return False;
    }
}

"""Create minimal runtime stub as fallback."""
impl ViteDevServer._create_runtime_stub(runtime_path: Path) -> None {
    runtime_stub = '''// Minimal Jac client runtime (fallback)
import React from 'react';

export function __jacJsx(component, props, children) {
  const validChildren = Array.isArray(children) ? children.flat() : (children ? [children] : []);
  if (typeof component === 'string') {
    return React.createElement(component, props, ...validChildren);
  } else {
    return React.createElement(component, { ...props, children: validChildren });
  }
}

export function __jacSpawn(walker, target) {
  console.warn('__jacSpawn not implemented in dev mode');
  return null;
}

export default { __jacJsx, __jacSpawn };
''';
    with open(runtime_path, 'w') as f {
        f.write(runtime_stub);
    }
}

"""Compile .jac files recursively following imports, copy .js/.tsx files."""
impl ViteDevServer.compile_all_jac_files {
    import from jaclang.project.config { get_config }
    
    config = get_config();
    client_dir = config.get_client_dir() if config else (self.project_dir / '.jac' / 'client');
    
    compiler = HMRCompiler(project_dir=self.project_dir, verbose=self.verbose);
    
    # Compile starting from main module, following imports recursively
    if self.module_path.exists() {
        self.compiled_modules = compiler.compile_recursively(self.module_path, client_dir);
    }
}

"""Start file watcher for .jac files."""
impl ViteDevServer.start_file_watcher {
    watcher = JacFileWatcher(
        project_dir=self.project_dir,
        compiled_modules=self.compiled_modules,
        verbose=self.verbose
    );
    
    def run_watcher() -> None {
        watcher.start();
    }
    
    self.watcher_thread = threading.Thread(target=run_watcher, daemon=True);
    self.watcher_thread.start();
    
    if self.verbose {
        print("Watching .jac files for changes...");
    }
}

"""Create vite.config.js for dev server."""
impl ViteDevServer.create_vite_config {
    import from jaclang.project.config { get_config }
    
    config = get_config();
    client_dir = config.get_client_dir() if config else (self.project_dir / '.jac' / 'client');
    client_dir.mkdir(parents=True, exist_ok=True);
    
    # Create simple vite.config.js
    config_content = f'''import {{ defineConfig }} from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({{
  plugins: [react()],
  server: {{
    host: '{self.host}',
    port: {self.port},
    strictPort: true
  }},
  resolve: {{
    alias: {{
      '@jac-client/utils': '{client_dir}/client_runtime.js',
      '@jac-client/assets': '{self.project_dir}/assets'
    }}
  }}
}});
''';
    
    config_path = client_dir / 'vite.config.js';
    with open(config_path, 'w') as f {
        f.write(config_content);
    }
    
    # Create main.js entry point
    main_js = '''import React from 'react';
import ReactDOM from 'react-dom/client';
import { app } from './app.js';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(React.createElement(app));
''';
    
    main_path = client_dir / 'main.js';
    with open(main_path, 'w') as f {
        f.write(main_js);
    }
    
    # Create index.html
    index_html = '''<!DOCTYPE html>
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
    
    index_path = client_dir / 'index.html';
    with open(index_path, 'w') as f {
        f.write(index_html);
    }
    
    # Compile and copy client_runtime from plugin source
    runtime_path = client_dir / 'client_runtime.js';
    import from jaclang.pycore.program { JacProgram }
    import from pathlib { Path as PathLib };
    
    # Find client_runtime.cl.jac in plugin
    plugin_dir = PathLib(__file__).parent.parent.parent;
    runtime_source = plugin_dir / 'client_runtime.cl.jac';
    
    if runtime_source.exists() {
        # Compile client_runtime.cl.jac to JS
        prog = JacProgram();
        ir = prog.compile(file_path=str(runtime_source));
        
        if not prog.errors_had and ir.gen.js {
            runtime_js = ir.gen.js;
            
            # Add React import if needed
            if 'import React' not in runtime_js {
                runtime_js = "import React from 'react';\n" + runtime_js;
            }
            
            with open(runtime_path, 'w') as f {
                f.write(runtime_js);
            }
            
            if self.verbose {
                print(f"Compiled client_runtime.js from {runtime_source}");
            }
        } else {
            # Fallback to minimal stub if compilation fails
            if self.verbose {
                print("Warning: Failed to compile client_runtime, using stub");
            }
            self._create_runtime_stub(runtime_path);
        }
    } else {
        # Fallback if source not found
        if self.verbose {
            print(f"Warning: {runtime_source} not found, using stub");
        }
        self._create_runtime_stub(runtime_path);
    }
    
    if self.verbose {
        print(f"Created Vite config at {config_path}");
    }
}

"""Start the Vite dev server."""
impl ViteDevServer.start {
    # Check if Vite is available
    if not self.is_vite_available() {
        print("Error: npx/npm not found. Please install Node.js and npm.", file=sys.stderr);
        sys.exit(1);
    }
    
    # Compile all .jac files first
    print("Compiling .jac files...");
    self.compile_all_jac_files();
    
    # Create Vite configuration
    print("Generating Vite configuration...");
    self.create_vite_config();
    
    # Start file watcher for .jac changes
    self.start_file_watcher();
    
    import from jaclang.project.config { get_config }
    config = get_config();
    client_dir = config.get_client_dir() if config else (self.project_dir / '.jac' / 'client');
    
    # Start Vite dev server
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
        
        # Stream output
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
impl ViteDevServer.stop {
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
impl JacFileWatcher.start {
    import from watchdog.events { FileSystemEventHandler }
    
    # Store reference for closure
    watcher_ref = self;
    
    class JacChangeHandler(FileSystemEventHandler) {
        def on_modified(self: JacChangeHandler, event: FileSystemEvent) -> None {
            # Skip files in .jac/ output directory to avoid infinite loops
            event_path = Path(event.src_path);
            try {
                if event_path.is_relative_to(watcher_ref.project_dir / '.jac') {
                    return;
                }
            } except (ValueError, AttributeError) {
                pass;
            }
            
            file_ext = str(event.src_path).split('.')[-1] if '.' in str(event.src_path) else '';
            
            if not event.is_directory and file_ext in ['jac', 'js', 'jsx', 'ts', 'tsx'] {
                watcher_ref.on_file_changed(event_path);
            }
        }
    }
    
    handler = JacChangeHandler();
    self.observer = Observer();
    self.observer.schedule(handler, str(self.project_dir), recursive=True);
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
impl JacFileWatcher.stop {
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
    
    import from jaclang.project.config { get_config }
    
    config = get_config();
    client_dir = config.get_client_dir() if config else (self.project_dir / '.jac' / 'client');
    
    # Check if file is in the import graph
    file_path_resolved = file_path.resolve();
    is_in_graph = file_path_resolved in self.compiled_modules;
    
    # Determine source root
    src_dir = self.project_dir / 'src';
    try {
        if file_path.is_relative_to(src_dir) {
            source_root = src_dir;
        } else {
            source_root = file_path.parent;
        }
    } except ValueError {
        source_root = file_path.parent;
    }
    
    compiler = HMRCompiler(project_dir=self.project_dir, verbose=self.verbose);
    
    try {
        if file_path.suffix == '.jac' {
            # Compile .jac file
            (js_output, _manifest) = compiler._compile_to_js(file_path);
            
            try {
                relative_path = file_path.relative_to(source_root);
                output_path = client_dir / relative_path.with_suffix('.js');
            } except ValueError {
                output_path = client_dir / file_path.with_suffix('.js').name;
            }
            
            output_path.parent.mkdir(parents=True, exist_ok=True);
            output_path.write_text(js_output, encoding='utf-8');
            
            if self.verbose {
                status = "✅ Recompiled" if is_in_graph else "⚠️  Compiled (not in import graph)";
                print(f"[HMR] {status}: {file_path.name}");
            }
            
            # Add to compiled modules if it's now part of the graph
            if not is_in_graph {
                self.compiled_modules.add(file_path_resolved);
                if self.verbose {
                    print(f"[HMR] ℹ️  To see changes, import {file_path.name} in your module graph");
                }
            }
            
        } elif file_path.suffix in ['.js', '.jsx', '.ts', '.tsx'] {
            # Copy JS/TS files as-is
            try {
                relative_path = file_path.relative_to(source_root);
                output_path = client_dir / relative_path;
            } except ValueError {
                output_path = client_dir / file_path.name;
            }
            
            output_path.parent.mkdir(parents=True, exist_ok=True);
            shutil.copy2(file_path, output_path);
            
            if self.verbose {
                status = "✅ Copied" if is_in_graph else "⚠️  Copied (not in import graph)";
                print(f"[HMR] {status}: {file_path.name}");
            }
            
            if not is_in_graph {
                self.compiled_modules.add(file_path_resolved);
            }
        }
    } except Exception as e {
        print(f"[HMR] ❌ Error processing {file_path.name}: {e}", file=sys.stderr);
    }
}

"""Recursively compile .jac files following imports, copy .js/.tsx files."""
impl HMRCompiler.compile_recursively(
    module_path: Path,
    client_dir: Path,
    visited: (set[Path] | None) = None,
    source_root: (Path | None) = None
) -> set[Path] {
    if (visited is None) {
        visited = set();
    }
    
    module_path = module_path.resolve();
    if (module_path in visited) {
        return visited;
    }
    visited.add(module_path);
    
    if (source_root is None) {
        source_root = module_path.parent.resolve();
    }
    
    # Compile .jac files
    if module_path.suffix == '.jac' {
        (js_output, manifest) = self._compile_to_js(module_path);
        
        # Determine output path
        try {
            relative_path = module_path.relative_to(source_root);
            output_path = client_dir / relative_path.with_suffix('.js');
        } except ValueError {
            output_path = client_dir / module_path.with_suffix('.js').name;
        }
        
        output_path.parent.mkdir(parents=True, exist_ok=True);
        output_path.write_text(js_output, encoding='utf-8');
        
        if self.verbose {
            print(f"Compiled: {module_path} -> {output_path}");
        }
        
        # Recursively process imports
        if manifest and manifest.imports {
            for (_name, import_path) in manifest.imports.items() {
                path_obj = Path(import_path).resolve();
                if (path_obj not in visited and path_obj.exists()) {
                    self.compile_recursively(path_obj, client_dir, visited, source_root);
                }
            }
        }
    } elif module_path.suffix in ['.js', '.jsx', '.ts', '.tsx'] {
        # Copy JS/TS files as-is
        try {
            relative_path = module_path.relative_to(source_root);
            output_path = client_dir / relative_path;
        } except ValueError {
            output_path = client_dir / module_path.name;
        }
        
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
    
    # Compile .jac file to JS
    prog = JacProgram();
    ir = prog.compile(file_path=str(module_path));
    
    if prog.errors_had {
        error_messages = [str(e) for e in prog.errors_had];
        raise Exception(f"Compilation errors: {', '.join(error_messages)}");
    }
    
    js_output = ir.gen.js or '';
    
    if not js_output.strip() {
        raise Exception('ECMAScript code generation produced no output');
    }
    
    # Add runtime imports if this is a client module
    manifest = ir.gen.client_manifest;
    if manifest {
        jac_jsx_import = 'import {__jacJsx, __jacSpawn} from "@jac-client/utils";';
        js_output = f"{jac_jsx_import}\n{js_output}";
    }
    
    return (js_output, manifest);
}

"""Compile a .jac module to JavaScript file (legacy interface)."""
impl HMRCompiler.compile_module(module_path: Path, output_path: Path) -> None {
    (js_output, _manifest) = self._compile_to_js(module_path);
    
    output_path.parent.mkdir(parents=True, exist_ok=True);
    with open(output_path, 'w', encoding='utf-8') as f {
        f.write(js_output);
    }
    
    if self.verbose {
        print(f"Compiled {module_path} -> {output_path}");
    }
}
