"""Development Server implementation with FE/BE separation and proxy support."""
import from jaclang.runtimelib.server { JacAPIServer }
import from jaclang { JacRuntime as Jac }

import time;
import fnmatch;

"""Register a handler for backend file changes."""
impl FileChangeDispatcher.register_backend_handler(handler: FileChangeCallback) -> None {
    if handler not in self._backend_handlers {
        self._backend_handlers.append(handler);
    }
}

"""Register a handler for frontend file changes."""
impl FileChangeDispatcher.register_frontend_handler(handler: FileChangeCallback) -> None {
    if handler not in self._frontend_handlers {
        self._frontend_handlers.append(handler);
    }
}

"""Register a generic handler for all file changes."""
impl FileChangeDispatcher.register_handler(handler: FileChangeCallback) -> None {
    if handler not in self._generic_handlers {
        self._generic_handlers.append(handler);
    }
}

"""Dispatch a backend file change to all registered handlers."""
impl FileChangeDispatcher.dispatch_backend_change(file_path: Path, change_type: str) -> None {
    for handler in self._backend_handlers {
        try {
            handler(file_path, change_type);
        } except Exception as e {
            print(f"[Watcher] Error in backend handler: {e}");
        }
    }
    self.dispatch_change(file_path, change_type, is_frontend=False);
}

"""Dispatch a frontend file change to all registered handlers."""
impl FileChangeDispatcher.dispatch_frontend_change(file_path: Path, change_type: str) -> None {
    for handler in self._frontend_handlers {
        try {
            handler(file_path, change_type);
        } except Exception as e {
            print(f"[Watcher] Error in frontend handler: {e}");
        }
    }
    self.dispatch_change(file_path, change_type, is_frontend=True);
}

"""Dispatch to generic handlers."""
impl FileChangeDispatcher.dispatch_change(file_path: Path, change_type: str, is_frontend: bool) -> None {
    for handler in self._generic_handlers {
        try {
            handler(file_path, change_type);
        } except Exception as e {
            print(f"[Watcher] Error in generic handler: {e}");
        }
    }
}

"""Clear all registered handlers."""
impl FileChangeDispatcher.clear_handlers -> None {
    self._backend_handlers.clear();
    self._frontend_handlers.clear();
    self._generic_handlers.clear();
}

"""Start watching for file changes."""
impl JacFileWatcher.start -> None {
    import from watchdog.observers { Observer }
    import from watchdog.events { FileSystemEventHandler, FileSystemEvent }

    if self._running {
        return;
    }

    watcher_ref = self;

    class JacEventHandler(FileSystemEventHandler) {
        """Handle file system events."""
        def on_modified(self: JacEventHandler, event: FileSystemEvent) -> None {
            if not event.is_directory {
                watcher_ref._handle_event(Path(event.src_path), CHANGE_MODIFIED);
            }
        }

        def on_created(self: JacEventHandler, event: FileSystemEvent) -> None {
            if not event.is_directory {
                watcher_ref._handle_event(Path(event.src_path), CHANGE_CREATED);
            }
        }

        def on_deleted(self: JacEventHandler, event: FileSystemEvent) -> None {
            if not event.is_directory {
                watcher_ref._handle_event(Path(event.src_path), CHANGE_DELETED);
            }
        }
    }

    self._observer = Observer();
    handler = JacEventHandler();

    for watch_path in self.config.watch_paths {
        if watch_path.exists() {
            self._observer.schedule(handler, str(watch_path), recursive=True);
            if self.verbose {
                print(f"[Watcher] Watching: {watch_path}");
            }
        }
    }

    self._observer.start();
    self._running = True;

    if self.verbose {
        print("[Watcher] File watcher started");
    }
}

"""Stop watching for file changes."""
impl JacFileWatcher.stop -> None {
    if not self._running {
        return;
    }

    if self._observer {
        self._observer.stop();
        self._observer.join(timeout=5);
        self._observer = None;
    }

    self._running = False;

    if self.verbose {
        print("[Watcher] File watcher stopped");
    }
}

"""Check if watcher is running."""
impl JacFileWatcher.is_running -> bool {
    return self._running;
}

"""Check if a file path should be ignored."""
impl JacFileWatcher._should_ignore(file_path: Path) -> bool {
    path_str = str(file_path);

    for pattern in self.config.ignore_patterns {
        if pattern in path_str {
            return True;
        }
        if fnmatch.fnmatch(file_path.name, pattern) {
            return True;
        }
    }

    return False;
}

"""Check if file is a frontend file."""
impl JacFileWatcher._is_frontend_file(file_path: Path) -> bool {
    suffix = file_path.suffix.lower();

    if suffix in ('.js', '.jsx', '.ts', '.tsx', '.css', '.html') {
        return True;
    }

    path_str = str(file_path).lower();
    frontend_indicators = ('/src/components/', '/src/pages/', '/client/', '/frontend/');

    for indicator in frontend_indicators {
        if indicator in path_str {
            return True;
        }
    }

    return False;
}

"""Check if file is a backend file."""
impl JacFileWatcher._is_backend_file(file_path: Path) -> bool {
    suffix = file_path.suffix.lower();
    return suffix in self.config.backend_extensions;
}

"""Handle a file system event with debouncing."""
impl JacFileWatcher._handle_event(file_path: Path, change_type: str) -> None {
    # Check if should ignore
    if self._should_ignore(file_path) {
        return;
    }

    # Debounce: skip if same file changed too recently
    path_key = str(file_path);
    current_time = time.time() * 1000;  # ms

    with self._lock {
        last_time = self._last_change.get(path_key, 0);
        if current_time - last_time < self.config.debounce_ms {
            return;
        }
        self._last_change[path_key] = current_time;
    }

    # Determine file type and dispatch
    is_frontend = self._is_frontend_file(file_path);
    is_backend = self._is_backend_file(file_path);

    if self.verbose {
        file_type = "frontend" if is_frontend else ("backend" if is_backend else "unknown");
        print(f"[Watcher] {change_type}: {file_path.name} ({file_type})");
    }

    # .jac files can be both frontend and backend - dispatch to both
    # Let handlers decide based on content (cl blocks, etc.)
    if file_path.suffix == '.jac' {
        self.dispatcher.dispatch_backend_change(file_path, change_type);
        self.dispatcher.dispatch_frontend_change(file_path, change_type);
    } elif is_frontend {
        self.dispatcher.dispatch_frontend_change(file_path, change_type);
    } elif is_backend {
        self.dispatcher.dispatch_backend_change(file_path, change_type);
    }
}

"""Create a file watcher with default configuration."""
impl create_watcher(
    project_root: Path,
    watch_paths: (list[Path] | None) = None,
    verbose: bool = False
) -> JacFileWatcher {
    # Default to watching src/ and the project root
    if watch_paths is None {
        watch_paths = [];
        src_dir = project_root / 'src';
        if src_dir.exists() {
            watch_paths.append(src_dir);
        } else {
            watch_paths.append(project_root);
        }
    }

    config = WatchConfig(watch_paths=watch_paths);
    dispatcher = FileChangeDispatcher();

    return JacFileWatcher(
        project_root=project_root,
        config=config,
        dispatcher=dispatcher,
        verbose=verbose
    );
}

glob PROXY_PREFIXES: tuple = (
    '/user/',
    '/function/',
    '/walker/',
    '/functions',
    '/walkers',
    '/protected'
);

"""Check if path should be proxied to backend."""
def should_proxy_path(path: str) -> bool {
    for prefix in PROXY_PREFIXES {
        if path.startswith(prefix) or path == prefix.rstrip('/') {
            return True;
        }
    }
    return False;
}

"""Start the backend API server in a separate thread."""
impl JacDevServer._start_backend -> None {
    import from jaclang.runtimelib.server { JacAPIServer }

    self._be_server = JacAPIServer(
        module_name=self.module_name,
        session_path=self.session_path,
        port=self.be_port,
        base_path=self.base_path
    );

    def run_backend() -> None {
        self._be_server.introspector.load();
        handler_class = self._be_server.create_handler();
        self._be_httpd = HTTPServer(('0.0.0.0', self.be_port), handler_class);
        print(f"  Backend API server running on http://localhost:{self.be_port}");
        self._be_httpd.serve_forever();
    }

    self._be_thread = threading.Thread(target=run_backend, daemon=True);
    self._be_thread.start();
}

"""Restart the backend server after file changes."""
impl JacDevServer._restart_backend -> None {
    with self._restart_lock {
        if self._restart_pending {
            return;
        }
        self._restart_pending = True;
    }

    print("\n[Dev] Restarting backend server...");

    # Stop current backend
    if self._be_httpd {
        self._be_httpd.shutdown();
        self._be_httpd = None;
    }

    # Wait for thread to finish
    if self._be_thread and self._be_thread.is_alive() {
        self._be_thread.join(timeout=2);
    }

    # Reload the module
    try {
        self._be_server.introspector.load(force_reload=True);
        print("[Dev] Module reloaded successfully");
    } except Exception as e {
        print(f"[Dev] Error reloading module: {e}");
    }

    # Start new backend
    self._start_backend();

    with self._restart_lock {
        self._restart_pending = False;
    }

    print("[Dev] Backend server restarted\n");
}

"""Handle backend file changes."""
impl JacDevServer._on_backend_change(file_path: Path, change_type: str) -> None {
    if change_type in (CHANGE_MODIFIED, CHANGE_CREATED) {
        # Only restart for .jac files (backend logic)
        if file_path.suffix == '.jac' {
            # Use a small delay to batch rapid changes
            import time;

            def delayed_restart() -> None {
                time.sleep(0.5);  # Wait for file writes to complete
                self._restart_backend();
            }

            restart_thread = threading.Thread(target=delayed_restart, daemon=True);
            restart_thread.start();
        }
    }
}

"""Handle frontend file changes - delegates to plugin hooks."""
impl JacDevServer._on_frontend_change(file_path: Path, change_type: str) -> None {
    # Call the plugin hook for frontend file changes
    if self.verbose {
        print(f"[Dev] Frontend file changed: {file_path.name}");
    }
    Jac.on_frontend_file_change(file_path, change_type);
}

"""Setup file watcher for development mode."""
impl JacDevServer._setup_file_watcher -> None {
    project_root = Path(self.base_path);

    # Create watcher
    self._file_watcher = create_watcher(
        project_root=project_root,
        verbose=self.verbose
    );

    # Register backend change handler
    self._file_watcher.dispatcher.register_backend_handler(self._on_backend_change);

    # Register frontend change handler (delegates to plugin hooks)
    self._file_watcher.dispatcher.register_frontend_handler(self._on_frontend_change);

    # Start watching
    watcher_thread = threading.Thread(target=self._file_watcher.start, daemon=True);
    watcher_thread.start();

    if self.verbose {
        print("[Dev] File watcher started");
    }

    # Call plugin hook to allow plugins to setup their dev servers
    # Returns True if plugin handles FE (e.g., jac-client with Vite)
    # pluggy returns a list of results from all plugins, check if any is True
    hook_results = Jac.on_dev_server_start(self);
    if isinstance(hook_results, list) {
        self._plugin_handles_fe = any(r for r in hook_results if r);
    } else {
        self._plugin_handles_fe = bool(hook_results);
    }
}

"""Get the file watcher instance for plugin extensions."""
impl JacDevServer.get_file_watcher -> (JacFileWatcher | None) {
    return self._file_watcher;
}

"""Create the frontend HTTP handler with proxy support."""
impl JacDevServer._create_fe_handler -> type[BaseHTTPRequestHandler] {
    dev_server = self;
    be_port = self.be_port;
    base_path = Path(self.base_path);

    """Frontend request handler with proxy to backend.""";
    class FERequestHandler(BaseHTTPRequestHandler) {
        """Proxy request to backend server."""
        def _proxy_to_backend(self: FERequestHandler, method: str) -> None {
            try {
                # Read request body if present
                content_length = int(self.headers.get('Content-Length', 0));
                body = self.rfile.read(content_length) if content_length > 0 else None;

                # Create connection to backend
                conn = HTTPConnection('localhost', be_port);

                # Forward headers (excluding hop-by-hop headers)
                headers = {};
                for (key, value) in self.headers.items() {
                    if key.lower() not in ('host', 'connection', 'keep-alive', 'transfer-encoding') {
                        headers[key] = value;
                    }
                }

                # Make request to backend
                conn.request(method, self.path, body=body, headers=headers);
                response = conn.getresponse();

                # Send response back to client
                self.send_response(response.status);

                # Forward response headers
                for (key, value) in response.getheaders() {
                    if key.lower() not in ('transfer-encoding', 'connection') {
                        self.send_header(key, value);
                    }
                }

                # Add CORS headers
                self.send_header('Access-Control-Allow-Origin', '*');
                self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
                self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
                self.end_headers();

                # Send response body
                self.wfile.write(response.read());
                conn.close();
            } except Exception as e {
                self.send_response(502);
                self.send_header('Content-Type', 'application/json');
                self.end_headers();
                self.wfile.write(json.dumps({'error': f'Backend proxy error: {str(e)}'}).encode());
            }
        }

        """Handle OPTIONS requests (CORS preflight)."""
        def do_OPTIONS(self: FERequestHandler) -> None {
            self.send_response(200);
            self.send_header('Access-Control-Allow-Origin', '*');
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
            self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
            self.send_header('Access-Control-Max-Age', '86400');
            self.end_headers();
        }

        """Handle GET requests."""
        def do_GET(self: FERequestHandler) -> None {
            parsed_path = urlparse(self.path);
            path = parsed_path.path;

            # Proxy API requests to backend
            if should_proxy_path(path) {
                self._proxy_to_backend('GET');
                return;
            }

            # Serve static files from .jac/client/dist or assets
            self._serve_static(path);
        }

        """Handle POST requests."""
        def do_POST(self: FERequestHandler) -> None {
            parsed_path = urlparse(self.path);
            path = parsed_path.path;

            # All POST requests go to backend
            if should_proxy_path(path) {
                self._proxy_to_backend('POST');
                return;
            }

            # Unknown POST endpoint
            self.send_response(404);
            self.send_header('Content-Type', 'application/json');
            self.end_headers();
            self.wfile.write(json.dumps({'error': 'Not found'}).encode());
        }

        """Serve static files or index.html."""
        def _serve_static(self: FERequestHandler, path: str) -> None {
            import from jaclang.project.config { find_project_root }

            # Find project root
            project_root_result = find_project_root(base_path);
            if project_root_result {
                (project_root, _) = project_root_result;
            } else {
                project_root = base_path;
            }

            # Determine file to serve
            if path == '/' or path == '' {
                # Serve index.html from .jac/client/dist
                file_path = project_root / '.jac' / 'client' / 'dist' / 'index.html';
            } else {
                # Try to serve file from dist or assets
                relative_path = path.lstrip('/');
                dist_path = project_root / '.jac' / 'client' / 'dist' / relative_path;
                assets_path = project_root / 'assets' / relative_path;

                if dist_path.exists() {
                    file_path = dist_path;
                } elif assets_path.exists() {
                    file_path = assets_path;
                } else {
                    # Fallback to index.html for SPA routing
                    file_path = project_root / '.jac' / 'client' / 'dist' / 'index.html';
                }
            }

            if file_path.exists() and file_path.is_file() {
                self._send_file(file_path);
            } else {
                self.send_response(404);
                self.send_header('Content-Type', 'application/json');
                self.end_headers();
                self.wfile.write(json.dumps({'error': 'File not found'}).encode());
            }
        }

        """Send a file with appropriate content type."""
        def _send_file(self: FERequestHandler, file_path: Path) -> None {
            # Determine content type
            suffix = file_path.suffix.lower();
            content_types = {
                '.html': 'text/html; charset=utf-8',
                '.css': 'text/css; charset=utf-8',
                '.js': 'application/javascript; charset=utf-8',
                '.json': 'application/json; charset=utf-8',
                '.png': 'image/png',
                '.jpg': 'image/jpeg',
                '.jpeg': 'image/jpeg',
                '.gif': 'image/gif',
                '.svg': 'image/svg+xml',
                '.ico': 'image/x-icon',
                '.woff': 'font/woff',
                '.woff2': 'font/woff2',
                '.ttf': 'font/ttf'
            };
            content_type = content_types.get(suffix, 'application/octet-stream');

            try {
                if suffix in ('.html', '.css', '.js', '.json', '.svg') {
                    content = file_path.read_text(encoding='utf-8');
                    encoded = content.encode('utf-8');
                } else {
                    encoded = file_path.read_bytes();
                }

                self.send_response(200);
                self.send_header('Content-Type', content_type);
                self.send_header('Content-Length', str(len(encoded)));
                self.send_header('Access-Control-Allow-Origin', '*');
                self.end_headers();
                self.wfile.write(encoded);
            } except Exception as e {
                self.send_response(500);
                self.send_header('Content-Type', 'application/json');
                self.end_headers();
                self.wfile.write(json.dumps({'error': str(e)}).encode());
            }
        }

        """Log requests."""
        def log_message(self: FERequestHandler, format: str, *args: object) -> None {
            print(f"[FE] {self.address_string()} - {(format % args)}");
        }
    }

    return FERequestHandler;
}

"""Start both frontend and backend servers."""
impl JacDevServer.start -> None {
    print('\n' + '=' * 60);
    print('JAC DEVELOPMENT SERVER');
    print('=' * 60);
    print(f'\nModule: {self.module_name}');
    print(f'Session: {self.session_path}');
    print('\nStarting servers...');

    # Start backend in a thread
    self._start_backend();

    # Give backend a moment to start
    import time;
    time.sleep(0.5);

    # Setup file watcher for hot reload (this also calls plugin hooks)
    self._setup_file_watcher();
    print('  File watcher active (watching for changes)');

    # Only start core FE server if no plugin is handling it
    if not self._plugin_handles_fe {
        handler_class = self._create_fe_handler();
        self._fe_server = HTTPServer(('0.0.0.0', self.fe_port), handler_class);
        print(f'  Frontend dev server running on http://localhost:{self.fe_port}');
    } else {
        print(f'  Frontend handled by plugin (port {self.fe_port})');
    }

    print('\n' + '-' * 60);
    print('ENDPOINTS:');
    print('-' * 60);
    print(f'  Frontend (dev):  http://localhost:{self.fe_port}');
    print(f'  Backend (API):   http://localhost:{self.be_port}');
    print('\nProxy routes (FE → BE):');
    print('  /user/*      → Backend authentication');
    print('  /function/*  → Backend function calls');
    print('  /walker/*    → Backend walker spawns');
    print('  /functions   → List functions');
    print('  /walkers     → List walkers');
    print('\nHot Reload:');
    print('  Backend .jac files → Auto restart');
    print('  Frontend files     → Handled by plugins (jac-client)');
    print('\nPress Ctrl+C to stop both servers');
    print('=' * 60 + '\n');

    try {
        # If plugin handles FE, we just keep the main thread alive
        if self._plugin_handles_fe {
            # Keep main thread alive while BE runs in background
            while True {
                time.sleep(1);
            }
        } else {
            # Core handles FE - run the FE server
            self._fe_server.serve_forever();
        }
    } except KeyboardInterrupt {
        self.stop();
    }
}

"""Stop both servers."""
impl JacDevServer.stop -> None {
    print('\n\nShutting down development servers...');

    # Stop file watcher
    if self._file_watcher {
        self._file_watcher.stop();
    }

    # Stop backend
    if self._be_httpd {
        self._be_httpd.shutdown();
    }

    # Stop frontend
    if self._fe_server {
        self._fe_server.shutdown();
    }

    print('Servers stopped.');
}
