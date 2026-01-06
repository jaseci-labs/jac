"""File covering plugin implementation."""
import os;
import pathlib;
import pickle;
import sys;
import from dotenv { load_dotenv }
import from jaclang.cli.cmdreg { CommandPriority, cmd_registry }
import from jaclang.pycore.runtime { hookimpl, plugin_manager }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.pycore.runtime { JacRuntime as Jac }
import from .context { JScaleExecutionContext }
import from .kubernetes.docker_impl { build_and_push_docker }
import from .kubernetes.K8s { deploy_K8s }
import from .kubernetes.utils { cleanup_K8s_resources }
import from .serve { JacAPIServer }
"""Jac CLI."""
class JacCmd {
    """Create Jac CLI cmds."""
    @hookimpl
    static def create_cmd -> None {
        """Jac Scale functionality.""";
        @cmd_registry.register
        def scale(file_path: str, build: bool = False) -> None {
            if not os.path.exists(file_path) {
                raise FileNotFoundError(f"File not found: '{file_path}'") ;
            }
            code_folder = os.path.dirname(file_path) or '.';
            dotenv_path = os.path.join(code_folder, '.env');
            load_dotenv(dotenv_path);
            code_folder = os.path.relpath(code_folder);
            code_folder = pathlib.Path(code_folder).as_posix();
            base_file_path = os.path.basename(file_path);
            if build {
                build_and_push_docker(code_folder);
            }
            deploy_K8s(code_folder, base_file_path, build);
        }
        """Jac Destroys functionality.""";
        @cmd_registry.register
        def destroy(file_path: str) -> None {
            if not os.path.exists(file_path) {
                raise FileNotFoundError(f"File not found: '{file_path}'") ;
            }
            code_folder = os.path.dirname(file_path) or '.';
            dotenv_path = os.path.join(code_folder, '.env');
            load_dotenv(dotenv_path);
            cleanup_K8s_resources();
        }
        """Start a REST API server for the specified .jac file.

            Executes the target module and turns all functions into authenticated REST API
            endpoints. Function signatures are introspected to create the API interface.
            Walkers are converted to REST APIs where their fields become the interface,
            with an additional target_node field for spawning location.

            Each user gets their own persistent root node that persists across runs.
            Users must create an account and authenticate to access the API.

            Args:
                filename: Path to the .jac file to serve
                session: Session identifier for persistent state (default: auto-generated)
                port: Port to run the server on (default: 8000)
                main: Treat the module as __main__ (default: True)
                faux: Perform introspection and print endpoint docs without starting server (default: False)

            Examples:
                jac serve myprogram.jac
                jac serve myprogram.jac --port 8080
                jac serve myprogram.jac --session myapp.session
                jac serve myprogram.jac --faux
            """;
        @cmd_registry.register(priority=CommandPriority.PLUGIN, source='jac-scale')
        def serve(
            filename: str,
            session: str = '',
            port: int = 8000,
            main: bool = True,
            faux: bool = False
        ) -> None {
            import from jaclang.cli.cli { proc_file_sess }
            (base, mod, mach) = proc_file_sess(filename, session);
            lng = filename.split('.')[-1];
            Jac.set_base_path(base);
            if filename.endswith(('.jac', '.py')) {
                try {
                    Jac.jac_import(target=mod, base_path=base, lng=lng);
                } except Exception as e {
                    print(f"Error loading {filename}: {e}", file=sys.stderr);
                    mach.close();
                    <>exit(1);
                }
            } elif filename.endswith('.jir') {
                try {
                    with open(filename, 'rb') as f {
                        Jac.attach_program(pickle.load(f));
                        Jac.jac_import(target=mod, base_path=base, lng=lng);
                    }
                } except Exception as e {
                    print(f"Error loading {filename}: {e}", file=sys.stderr);
                    mach.close();
                    <>exit(1);
                }
            }
            session_path = session or os.path.join(base, f"{mod}.session");
            server = JacAPIServer(
                module_name=mod, session_path=session_path, port=port, base_path=base
            );
            if faux {
                try {
                    server.print_endpoint_docs();
                    mach.close();
                    return;
                } except Exception as e {
                    print(
                        f"Error generating endpoint documentation: {e}",
                        file=sys.stderr
                    );
                    mach.close();
                    <>exit(1);
                }
            }
            try {
                server.start();
            } except KeyboardInterrupt {
                print('\nServer stopped.');
                mach.close();
            } except Exception as e {
                print(f"Server error: {e}", file=sys.stderr);
                mach.close();
                <>exit(1);
            }
        }
    }
}

"""Jac Scale Plugin Implementation."""
class JacScalePlugin {
    @hookimpl
    static def create_j_context(
        session: (str | None) = None, <>root: (str | None) = None
    ) -> ExecutionContext {
        return JScaleExecutionContext(session=session, <>root=<>root);
    }
}

# Pluggy's varnames() puts parameters with defaults into kwargnames, not argnames.
# But _multicall only passes argnames to hook implementations.
# JacRuntimeInterfaceImpl strips defaults via generate_plugin_helpers, so we must too.
import inspect;
glob func = JacScalePlugin.create_j_context,
     sig = inspect.signature(func),
     sig_nodef = sig.replace(
         parameters=[
             p.replace(default=inspect.Parameter.empty)
             for p in sig.parameters.values()
         ]
     );

with entry {
    func.__signature__ = sig_nodef;
    plugin_manager.register(JacScalePlugin());
}
