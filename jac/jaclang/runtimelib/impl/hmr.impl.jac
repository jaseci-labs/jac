"""Hot Module Replacement implementation.

Handles file change events and coordinates module reloading.
"""

import logging;
import os;
import sys;
import time;
import from pathlib { Path }
import from typing { Any }
import from jaclang.pycore.constant { CodeContext }

glob logger = logging.getLogger(__name__);

"""Start the hot reloader and begin watching for changes."""
impl HotReloader.start -> None {
    if self._running {
        return;
    }
    # Register our callback with the watcher
    self.watcher.add_callback(self.on_file_change);
    # Start watching
    self.watcher.start();
    self._running = True;
    logger.debug(f"Hot reloader started for module: {self.module_name}");
}

"""Stop the hot reloader and file watcher."""
impl HotReloader.stop -> None {
    if not self._running {
        return;
    }
    self._running = False;
    # Stop the watcher
    self.watcher.stop();
    logger.debug("Hot reloader stopped");
}

"""Callback for file change events from the watcher."""
impl HotReloader.on_file_change(event: Any) -> None {
    if not self._running {
        return;
    }
    print(f"[HMR] File changed: {event.path} ({event.change_type})", flush=True);
    # Process the change
    self._process_change(event.path);
}

"""Process a file change by classifying declarations and taking action."""
impl HotReloader._process_change(file_path: str) -> None {
    # Check if file has client and/or server declarations
    (has_client, has_server) = self._classify_declarations(file_path);
    # Handle server declarations - reload in sys.modules
    if has_server {
        self._reload_server_module(file_path);
    }
    # Handle client declarations - recompile to JS (Phase 2)
    if has_client {
        self._recompile_client_code(file_path);
    }
}

"""Reload server-side module in sys.modules."""
impl HotReloader._reload_server_module(file_path: str) -> None {
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    # Get module name from file path
    module_name = self._path_to_module(file_path);
    # Remove from sys.modules to force reimport
    modules_to_remove = [
        name
        for name in sys.modules.keys()
        if name == module_name or name.startswith(f"{module_name}.")
    ];
    for mod_name in modules_to_remove {
        del sys.modules[mod_name];
    }
    # Also remove from the program's module hub
    try {
        if file_path in Jac.program.mod.hub {
            del Jac.program.mod.hub[file_path];
        }
        # Also try with resolved path
        resolved_path = str(Path(file_path).resolve());
        if resolved_path in Jac.program.mod.hub {
            del Jac.program.mod.hub[resolved_path];
        }
    } except Exception as e {
        print(f"[HMR] Warning: Could not clear module hub: {e}", flush=True);
    }
    # Re-import with force reload
    try {
        Jac.jac_import(
            target=module_name, base_path=self.base_path, reload_module=True
        );
        print(f"[HMR] Reloaded: {file_path}", flush=True);
    } except SyntaxError as e {
        # Syntax error during reload
        line_info = f" (line {e.lineno})" if e?.lineno and e.lineno else "";
        print(
            f"[HMR] Syntax error reloading {file_path}{line_info}: {e?.msg or str(e)}",
            flush=True
        );
        print(f"[HMR] Fix the error and save to retry", flush=True);
    } except ImportError as e {
        # Import error (missing dependency, etc.)
        print(f"[HMR] Import error reloading {file_path}: {e}", flush=True);
        self._emit_client_error_overlay(file_path, str(e));
    } except Exception as e {
        # Other errors
        error_type = type(e).__name__;
        print(f"[HMR] {error_type} reloading {file_path}: {e}", flush=True);
        self._emit_client_error_overlay(file_path, str(e));
    }
}

"""Recompile client declarations to JavaScript."""
impl HotReloader._recompile_client_code(file_path: str) -> None {
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    try {
        source_path = Path(file_path).resolve();
        source_key = str(source_path);

        # Clear existing module from hub to force recompilation
        if source_key in Jac.program.mod.hub {
            del Jac.program.mod.hub[source_key];
        }

        # Compile the file (this generates JS as part of the compilation)
        mod = Jac.program.compile(source_key);

        # Check for compilation errors
        if Jac.program.errors_had {
            errors = '\n'.join(str(err) for err in Jac.program.errors_had);
            print(f"[HMR] Client compile errors in {file_path}:\n{errors}", flush=True);
            self._emit_client_error_overlay(file_path, errors);
            Jac.program.errors_had.clear();
            return;
        }

        # If there were previous errors, we need to update the entry point
        if self._overlay_entry {
            output_base = Path(self.base_path) / self._client_output_dir;
            output_dir = output_base;
            output_dir.mkdir(parents=True, exist_ok=True);
            js_filename = "_entry.js";
            output_path = output_dir / js_filename;
            entry_content = f'import React from "react";\nimport {{ createRoot }} from "react-dom/client";\nimport {{ app as App }} from "./{self.module_name}.js";\nimport {{ JacClientErrorBoundary, ErrorFallback }} from "@jac-client/utils";\n\nconst root = createRoot(document.getElementById("root"));\nroot.render(\n\tReact.createElement(\n\t\tJacClientErrorBoundary,{{ FallbackComponent: ErrorFallback }},\n\t\tReact.createElement(App, null)\n\t)\n);\n';
            output_path.write_text(entry_content, encoding='utf-8');
            print(f"[HMR] Update entry: {output_path}", flush=True);
            self._overlay_entry = False;
        }

        # Get the generated JS code
        js_code = mod.gen.js or '';

        if not js_code {
            print(f"[HMR] No client JS generated for {file_path}", flush=True);
            return;
        }

        # Ensure __jacJsx import is present (required for client-side rendering)
        jac_runtime_import = 'import {__jacJsx, __jacSpawn} from "@jac-client/utils";';
        if '__jacJsx' in js_code and jac_runtime_import not in js_code {
            # Add import at the beginning of the file
            js_code = jac_runtime_import + '\n' + js_code;
        }

        # Preserve directory structure: components/AuthForm.cl.jac -> components/AuthForm.js
        base_dir = Path(self.base_path).resolve();
        source_dir = source_path.parent;
        try {
            # Get the relative path from base_path to source file's directory
            rel_dir = source_dir.relative_to(base_dir);
        } except ValueError {
            # File is not under base_path, put in root
            rel_dir = Path('.');
        }

        # Build output path preserving directory structure
        output_base = Path(self.base_path) / self._client_output_dir;
        output_dir = output_base / rel_dir;
        output_dir.mkdir(parents=True, exist_ok=True);

        # Generate output filename (foo.jac -> foo.js, foo.cl.jac -> foo.js)
        js_filename = self._get_js_filename(file_path);
        output_path = output_dir / js_filename;

        # Write the JS code
        output_path.write_text(js_code, encoding='utf-8');

        print(f"[HMR] Recompiled client: {file_path} -> {output_path}", flush=True);
    } except Exception as e {
        print(f"[HMR] Error recompiling client code {file_path}: {e}", flush=True);
    }
}

"""Convert a .jac file path to a .js filename."""
impl HotReloader._get_js_filename(file_path: str) -> str {
    path = Path(file_path);
    name = path.name;
    # Handle different Jac file extensions
    if name.endswith(".cl.jac") {
        return name[:-7] + ".js";
    } elif name.endswith(".impl.jac") {
        return name[:-9] + ".js";
    } elif name.endswith(".jac") {
        return name[:-4] + ".js";
    } else {
        return name + ".js";
    }
}

"""Get client and server declarations from a file.

Returns (has_client_decls, has_server_decls).
"""
impl HotReloader._classify_declarations(file_path: str) -> tuple[bool, bool] {
    import from jaclang.pycore.program { JacProgram }
    has_client = False;
    has_server = False;
    try {
        # Parse the file to get AST
        prog = JacProgram();
        mod = prog.compile(file_path, no_cgen=True);

        # Check top-level declarations in module body for code_context
        for node in mod.body {
            if node?.code_context {
                if node.code_context == CodeContext.CLIENT {
                    has_client = True;
                } else {
                    has_server = True;
                }
            }
        }

        # If no explicit client declarations found, assume server code
        if not has_client and not has_server {
            has_server = True;
        }
    } except SyntaxError as e {
        # Syntax error - provide detailed location info
        line_info = f" at line {e.lineno}" if e?.lineno and e.lineno else "";
        print(
            f"[HMR] Syntax error in {file_path}{line_info}: {e?.msg or str(e)}",
            flush=True
        );
        # Still try to reload - the error will be shown again during actual reload
        has_server = True;
    } except Exception as e {
        # Other parse errors - still try to reload
        error_type = type(e).__name__;
        print(f"[HMR] {error_type} in {file_path}: {e}", flush=True);
        has_server = True;
    }
    return (has_client, has_server);
}

"""Convert file path to module name."""
impl HotReloader._path_to_module(file_path: str) -> str {
    # Get relative path from base_path
    path = Path(file_path);
    base = Path(self.base_path);
    try {
        rel_path = path.relative_to(base);
    } except ValueError {
        # File not under base_path, use filename
        rel_path = path;
    }
    # Remove .jac extension and convert path separators to dots
    module_parts = [];
    for part in rel_path.parts {
        if part.endswith(".jac") {
            module_parts.append(part[:-4]);
        } elif part.endswith(".impl.jac") {
            module_parts.append(part[:-9]);
        } elif part.endswith(".cl.jac") {
            module_parts.append(part[:-7]);
        } else {
            module_parts.append(part);
        }
    }
    return ".".join(module_parts);
}

"""Emit a client-side error overlay for compilation errors."""
impl HotReloader._emit_client_error_overlay(file_path: str, errors: str) -> None {
    output_base = Path(self.base_path) / self._client_output_dir;
    output_dir = output_base;
    output_dir.mkdir(parents=True, exist_ok=True);
    js_filename = "_entry.js";
    output_path = output_dir / js_filename;
    entry_content = f'import React from "react";\nimport {{ createRoot }} from "react-dom/client";\nimport {{ errorOverlay }} from "@jac-client/utils";\n\nconst root = createRoot(document.getElementById("root"));\nroot.render(errorOverlay("{file_path} ", ` {errors}`), null);\n';
    # Update the entry point to show the error overlay
    output_path.write_text(entry_content, encoding='utf-8');
    # Mark that have an overlay entry
    self._overlay_entry = True;
    print(f"[HMR] Error emitting overlay for {file_path}", flush=True);
    return;
}
