"""Jac Language Features."""
import fnmatch;
import html;
import inspect;
import json;
import os;
import sys;
import types;
import from collections { OrderedDict }
import from collections.abc { Callable, Coroutine, Iterator, Mapping, Sequence }
import from concurrent.futures { Future, ThreadPoolExecutor }
import from contextlib { contextmanager, suppress }
import from contextvars { ContextVar }
import dataclasses;
import from dataclasses { dataclass, field }
import from functools { wraps }
import from http.server { HTTPServer }
import from inspect { getfile }
import from logging { getLogger }
import from pathlib { Path }
import from typing {
    TYPE_CHECKING,
    Any,
    Literal,
    ParamSpec,
    TypeAlias,
    TypeVar,
    cast,
    get_type_hints
}
import from uuid { UUID }
import from jaclang.jac0core.archetype {
    GenericEdge,
    ObjectSpatialDestination,
    ObjectSpatialFunction,
    ObjectSpatialPath,
    Root
}
import from jaclang.jac0core.constant { EdgeDir, colors }
import from jaclang.jac0core.constructs {
    AccessLevel,
    Anchor,
    Archetype,
    EdgeAnchor,
    EdgeArchetype,
    JsxElement,
    NodeAnchor,
    NodeArchetype,
    WalkerAnchor,
    WalkerArchetype
}
import from jaclang.jac0core.modresolver { infer_language }
import from jaclang.jac0core.mtp { MTIR, Info, MTRuntime }
import from jaclang.jac0core { plugin }

with entry {
    if TYPE_CHECKING {
        import from http.server { BaseHTTPRequestHandler }
        import from jaclang.cli.console { JacConsole as ConsoleImpl }
        import from jaclang.jac0core.compiler { JacCompiler }
        import from jaclang.jac0core.program { JacProgram }
        import from jaclang.runtimelib.client_bundle {
            ClientBundle,
            ClientBundleBuilder
        }
        import from jaclang.runtimelib.context { ExecutionContext }
        import from jaclang.runtimelib.server { JacAPIServer as JacServer }
        import from jaclang.runtimelib.server { ModuleIntrospector, UserManager }
    }
}

glob plugin_manager = plugin.PluginManager('jac'),
     hookspec = plugin.HookspecMarker('jac'),
     hookimpl = plugin.HookimplMarker('jac'),
     logger = getLogger(__name__),
     T = TypeVar('T'),
     P = ParamSpec('P'),
     JsonValue: TypeAlias = None | str | int | float | bool | `list['JsonValue'] | `dict[
         (str, 'JsonValue')
     ],
     StatusCode: TypeAlias = Literal[(200, 201, 400, 401, 404, 500, 503)],
     _request_context: ContextVar[ExecutionContext | None] = ContextVar(
         'request_context', default=None
     );

"""Jac Access Validation Specs."""
class JacAccessValidation {
    """Resolve the live anchor for an archetype from runtime memory."""
    static def _resolve_anchor(
        archetype: Archetype
    ) -> tuple[Anchor, ExecutionContext];

    """Check if current root has at least min_level access to target anchor."""
    static def _check_access(
        `to: Anchor, min_level: AccessLevel, operation: str
    ) -> bool;

    """Allow all access from target root graph to current Archetype."""
    static def allow_root(
        archetype: Archetype,
        root_id: UUID,
        level: (AccessLevel | int | str | None) = None
    ) -> None;

    """Disallow all access from target root graph to current Archetype."""
    static def disallow_root(
        archetype: Archetype,
        root_id: UUID,
        level: (AccessLevel | int | str | None) = None
    ) -> None;

    """Allow everyone to access current Archetype."""
    static def perm_grant(
        archetype: Archetype, level: (AccessLevel | int | str | None) = None
    ) -> None;

    """Disallow others to access current Archetype."""
    static def perm_revoke(archetype: Archetype) -> None;

    """Read Access Validation."""
    static def check_read_access(`to: Anchor) -> bool;

    """Connect Access Validation."""
    static def check_connect_access(`to: Anchor) -> bool;

    """Write Access Validation."""
    static def check_write_access(`to: Anchor) -> bool;

    """Access validation."""
    static def check_access_level(`to: Anchor, no_custom: bool = False) -> AccessLevel;
}

"""Jac Node Operations."""
class JacNode {
    """Get edges connected to this node."""
    static def get_edges(
        origin: list[NodeArchetype], destination: ObjectSpatialDestination
    ) -> list[EdgeArchetype];

    """Get edges connected to this node and the node."""
    static def get_edges_with_node(
        origin: list[NodeArchetype],
        destination: ObjectSpatialDestination,
        from_visit: bool = False
    ) -> list[(EdgeArchetype | NodeArchetype)];

    """Get set of nodes connected to this node."""
    static def edges_to_nodes(
        origin: list[NodeArchetype], destination: ObjectSpatialDestination
    ) -> list[NodeArchetype];

    """Remove reference without checking sync status."""
    static def remove_edge(nd: NodeAnchor, `edge: EdgeAnchor) -> None;
}

"""Jac Edge Operations."""
class JacEdge {
    """Detach edge from nodes."""
    static def detach(`edge: EdgeAnchor) -> None;
}

"""Jac Edge Operations."""
class JacWalker {
    """Jac's visit stmt feature."""
    static def `visit(
        `walker: WalkerArchetype,
        expr:
            (
                list[
                    (NodeArchetype | EdgeArchetype)
                ] | list[NodeArchetype] | list[EdgeArchetype] | NodeArchetype | EdgeArchetype | ObjectSpatialPath
            ),
        insert_loc: int = -1
    ) -> bool;

    """Execute all entry abilities for current location.

        Returns True if walker should continue, False if disengaged.
        """
    static def _execute_entries(
        warch: WalkerArchetype,
        `walker: WalkerAnchor,
        current_loc: (NodeArchetype | EdgeArchetype)
    ) -> bool;

    """Execute all exit abilities for current location.

        Returns True if walker should continue, False if disengaged.
        """
    static def _execute_exits(
        warch: WalkerArchetype,
        `walker: WalkerAnchor,
        current_loc: (NodeArchetype | EdgeArchetype)
    ) -> bool;

    """Recursively visit a node with DFS semantics.

        1. Execute entries for this node
        2. Recursively visit all children added during entry
        3. Execute exits for this node (post-order)

        Returns True if walker should continue, False if disengaged.
        """
    static def _visit_node_recursive(
        warch: WalkerArchetype,
        `walker: WalkerAnchor,
        anchor: (NodeAnchor | EdgeAnchor)
    ) -> bool;

    """Jac's spawn operator feature with recursive DFS semantics.

        Entry abilities execute when entering a node, exit abilities execute
        after all descendants are visited (post-order/LIFO).
        """
    static def spawn_call(
        `walker: WalkerAnchor, nd: (NodeAnchor | EdgeAnchor)
    ) -> WalkerArchetype;

    """Async version: Execute all entry abilities for current location.

        Returns True if walker should continue, False if disengaged.
        """
    static async def _async_execute_entries(
        warch: WalkerArchetype,
        `walker: WalkerAnchor,
        current_loc: (NodeArchetype | EdgeArchetype)
    ) -> bool;

    """Async version: Execute all exit abilities for current location.

        Returns True if walker should continue, False if disengaged.
        """
    static async def _async_execute_exits(
        warch: WalkerArchetype,
        `walker: WalkerAnchor,
        current_loc: (NodeArchetype | EdgeArchetype)
    ) -> bool;

    """Async version: Recursively visit a node with DFS semantics.

        1. Execute entries for this node
        2. Recursively visit all children added during entry
        3. Execute exits for this node (post-order)

        Returns True if walker should continue, False if disengaged.
        """
    static async def _async_visit_node_recursive(
        warch: WalkerArchetype,
        `walker: WalkerAnchor,
        anchor: (NodeAnchor | EdgeAnchor)
    ) -> bool;

    """Jac's async spawn operator feature with recursive DFS semantics.

        Entry abilities execute when entering a node, exit abilities execute
        after all descendants are visited (post-order/LIFO).
        """
    static async def async_spawn_call(
        `walker: WalkerAnchor, nd: (NodeAnchor | EdgeAnchor)
    ) -> WalkerArchetype;

    """Jac's spawn operator feature."""
    static def `spawn(
        op1: (Archetype | list[Archetype]), op2: (Archetype | list[Archetype])
    ) -> (WalkerArchetype | Coroutine);

    """Jac's disengage stmt feature."""
    static def `disengage(`walker: WalkerArchetype) -> bool;
}

"""Default Classes References - direct class attributes (no lazy loading)."""
class JacClassReferences {
    with entry {
        TYPE_CHECKING: bool = TYPE_CHECKING;
        DSFunc = ObjectSpatialFunction;
        OPath = ObjectSpatialPath;
        Root = Root;
        GenericEdge = GenericEdge;
        Obj = Archetype;
        Node = NodeArchetype;
        Edge = EdgeArchetype;
        Walker = WalkerArchetype;
        JsxElement = JsxElement;
    }
}

"""Jac Builtins."""
class JacBuiltin {
    """Generate graph for visualizing nodes and edges."""
    static def printgraph(
        nd: NodeArchetype,
        depth: int,
        traverse: bool,
        edge_type: (list[str] | None),
        bfs: bool,
        edge_limit: int,
        node_limit: int,
        file: (str | None),
        format: str
    ) -> str;
}

"""Jac CLI command."""
class JacCmd {
    """Create Jac CLI cmds."""
    static def create_cmd -> None;
}

"""Jac Feature."""
class JacBasics {
    """Set Class References."""
    static def setup -> None;

    """Get current execution context (request-scoped if available, else global)."""
    static def get_context -> ExecutionContext;

    """Commit all data from memory to datasource."""
    static def commit(anchor: Anchor | Archetype | None = None) -> None;

    """Purge current or target graph."""
    static def reset_graph(root: (Root | None) = None) -> int;

    """Get object given id."""
    static def get_object(id: str) -> (Archetype | None);

    """Get object reference id."""
    static def object_ref(`obj: Archetype) -> str;

    """Create a obj archetype."""
    static def make_archetype(cls: type[Archetype]) -> type[Archetype];

    """Update impl file location."""
    static def impl_patch_filename(
        file_loc: str
    ) -> Callable[([Callable[(P, T)]], Callable[(P, T)])];

    """Import a Jac or Python module using Python's standard import machinery.

        This function bridges Jac's import semantics with Python's import
system,
        leveraging importlib.import_module() which automatically invokes our
        JacMetaImporter (registered in sys.meta_path).

        Args:
            target: Module name to import (e.g., "foo.bar" or ".relative")
            base_path: Base directory for resolving the module
            absorb: If True with items, return module instead of items
            override_name: Special handling for "__main__" execution context
            items: Specific items to import from module (like "from X import Y")
            reload_module: Force reload even if already in sys.modules
            lng: Language hint ("jac", "py", etc.) - auto-detected if None

        Returns:
            Tuple of imported module(s) or item(s)

        Examples:
            # Import entire module
            (mod,) = jac_import("mymod", "/path/to/base")

            # Import specific items
            (func, cls) = jac_import("mymod", "/path", items={"myfunc": None,
"MyClass": None})

            # Run as __main__
            jac_import("mymod", "/path", override_name="__main__")
        """
    static def jac_import(
        target: str,
        base_path: str,
        absorb: bool = False,
        override_name: (str | None) = None,
        items: (dict[(str, str | str | None)] | None) = None,
        reload_module: (bool | None) = False,
        lng: (str | None) = None
    ) -> tuple[(types.ModuleType, ...)];

    """Create a test."""
    static def jac_test(description: str = "") -> Callable;

    """JSX interface for creating elements.

        Args:
            tag: Element tag (string for HTML elements, callable for components)
            attributes: Element attributes/props
            children: Child elements

        Returns:
            JSX element representation.
        """
    static def jsx(
        tag: object,
        attributes: (Mapping[(str, object)] | None) = None,
        children: (Sequence[object] | None) = None
    ) -> JsxElement;

    """Run the test suite in the specified .jac file."""
    static def run_test(
        filepath: str,
        func_name: (str | None) = None,
        filter: (str | None) = None,
        xit: bool = False,
        maxfail: (int | None) = None,
        directory: (str | None) = None,
        verbose: bool = False
    ) -> int;

    """Jac's field handler."""
    static def field(
        factory: (Callable[([], T)] | None) = None, `init: bool = True
    ) -> T;

    """Jac's report stmt feature."""
    static def log_report(expr: Any, custom: bool = False) -> None;

    """Jac's apply_dir stmt feature."""
    static def refs(
        path: ObjectSpatialPath | NodeArchetype | list[NodeArchetype],
        post_filter: (Callable[([Archetype], bool)] | None) = None
    ) -> list[NodeArchetype] | list[EdgeArchetype] | list[
        (NodeArchetype | EdgeArchetype)
    ];

    """Jac's apply_dir stmt feature."""
    static async def arefs(
        path: ObjectSpatialPath | NodeArchetype | list[NodeArchetype]
    ) -> None;

    """Jac's filter archetype list."""
    static def filter_on(
        items: list[Archetype], func: Callable[([Archetype], bool)]
    ) -> list[Archetype];

    """Jac's connect operator feature."""
    static def connect(
        left: (NodeArchetype | list[NodeArchetype]),
        right: (NodeArchetype | list[NodeArchetype]),
        `edge: type[EdgeArchetype] | EdgeArchetype | None = None,
        undir: bool = False,
        conn_assign: (tuple[(tuple, tuple)] | None) = None,
        edges_only: bool = False
    ) -> (list[NodeArchetype] | list[EdgeArchetype]);

    """Jac's disconnect operator feature."""
    static def disconnect(
        left: (NodeArchetype | list[NodeArchetype]),
        right: (NodeArchetype | list[NodeArchetype]),
        dir: EdgeDir = EdgeDir.OUT,
        filter: (Callable[([EdgeArchetype], bool)] | None) = None
    ) -> bool;

    """Jac's assign comprehension feature."""
    static def assign_all(
        target: list[T], attr_val: tuple[(tuple[str], tuple[Any])]
    ) -> list[T];

    """Jac's safe subscript feature."""
    static def safe_subscript(`obj: Any, key: Any) -> Any;

    """Jac's root getter."""
    static def root -> Root;

    """Get all the roots."""
    static def get_all_root -> list[Root];

    """Jac's root getter."""
    static def build_edge(
        is_undirected: bool,
        conn_type: type[EdgeArchetype] | EdgeArchetype | None,
        conn_assign: (tuple[(tuple, tuple)] | None)
    ) -> Callable[([NodeAnchor, NodeAnchor], EdgeArchetype)];

    """Destroy object."""
    static def save(`obj: (Archetype | Anchor)) -> None;

    """Destroy multiple objects passed in a tuple or list."""
    static def destroy(objs: Archetype | Anchor | list[(Archetype | Anchor)]) -> None;

    """Mark a method as jac entry with this decorator."""
    static def on_entry(func: Callable) -> Callable;

    """Mark a method as jac exit with this decorator."""
    static def on_exit(func: Callable) -> Callable;
}

"""Jac Client Bundle Operations - Generic interface for client bundling."""
class JacClientBundle {
    """Get the client bundle builder instance."""
    static def get_client_bundle_builder -> ClientBundleBuilder;

    """Build a client bundle for the supplied module."""
    static def build_client_bundle(
        module: types.ModuleType, force: bool = False
    ) -> ClientBundle;

    """Format a build error for display.

        Plugins can override this hook to provide rich error formatting.
        Default implementation returns the raw error output.
        """
    static def format_build_error(
        error_output: str, project_dir: Path, config: object = None
    ) -> str;
}

"""Jac Console Operations - Generic interface for console output."""
class JacConsole {
    """Get the console instance to use for CLI output.

        Plugins can override this hook to provide their own console
implementation.
        The returned instance should be compatible with the JacConsole
interface.
        """
    static def get_console -> ConsoleImpl;
}

"""Jac API Server Operations - Generic interface for API server."""
class JacAPIServer {
    """Get the JacAPIServer class to use for serve command.

        Plugins can override this hook to provide their own server class.
        The returned class should be compatible with the JacAPIServer interface.
        """
    static def get_api_server_class -> type;

    """Create the API server instance.

    If the specified port is in use, tries subsequent ports up to max_retries times.
    Updates jac_server.port with the actual bound port if different from requested.
    """
    static def create_server(
        jac_server: JacServer, host: str, port: int, max_retries: int = 10
    ) -> HTTPServer;

    """Render HTML page for client function."""
    static def render_page(
        introspector: ModuleIntrospector,
        function_name: str,
        args: dict[(str, Any)],
        username: str
    ) -> dict[(str, Any)];

    """Get the client JavaScript bundle code.

        Plugins can override this hook to provide custom bundle serving logic
        (e.g., serving Vite-built PWA bundles).
    """
    static def get_client_js(introspector: ModuleIntrospector) -> str;
}

"""Jac Response Builder."""
class JacResponseBuilder {
    """Send JSON response."""
    static def send_json(
        handler: BaseHTTPRequestHandler,
        status: StatusCode,
        data: dict[(str, JsonValue)]
    ) -> None;

    """Send HTML response with CORS headers."""
    static def send_html(
        handler: BaseHTTPRequestHandler, status: StatusCode, body: str
    ) -> None;

    """Send JavaScript response."""
    static def send_javascript(handler: BaseHTTPRequestHandler, code: str) -> None;

    """Send CSS response."""
    static def send_css(handler: BaseHTTPRequestHandler, css_code: str) -> None;

    """Send static file response (images, fonts, etc.)."""
    static def send_static_file(
        handler: BaseHTTPRequestHandler,
        file_path: Path,
        content_type: (str | None) = None
    ) -> None;
}

"""Jac byLLM integration."""
class JacByLLM {
    """Get byLLM library."""
    static def get_mtir(
        caller: Callable,
        args: dict[((int | str), object)],
        call_params: dict[(str, object)]
    ) -> MTRuntime;

    """Attach the semstring to the given object."""
    static def `sem(semstr: str, inner_semstr: dict[(str, str)]) -> Callable;

    """Call the LLM model."""
    static def call_llm(model: object, mt_run: MTRuntime) -> Any;

    """Python library mode decorator for Jac's by llm() syntax."""
    static def `by(model: object) -> Callable;

    static def filter_visitable_by(
        connected_nodes: list[NodeArchetype], model: object, descriptions: str = ''
    ) -> list[NodeArchetype];

    """by operator feature for expression composition.

        Currently not implemented - raises NotImplementedError.
        Plugins like byllm can override this via the plugin hook system.
        """
    static def by_operator(lhs: Any, rhs: Any) -> Any;

    """Return the default LLM model for use with 'by llm()' syntax.

        The builtin 'llm' name resolves to this method via the plugin hook
        system. Base implementation returns a minimal stub with call_params={}
        and __call__ returning self, which works with the random-value fallback
        in call_llm. Plugins (e.g. byllm) override this to return a configured
        Model instance based on jac.toml settings.
        """
    static def default_llm -> object;

    """Add MTIR to the node's MTIR map."""
    static def add_mtir_to_map(scope: str, mtir: Info) -> None;

    """Get MTIR from the node's MTIR map."""
    static def get_mtir_from_map(scope: str) -> (Info | None);
}

"""Jac Machine Utilities."""
class JacUtils {
    """Create a new execution context.

        Args:
            user_root: User root ID for permission boundary. Required parameter.
                       Pass None for CLI/system contexts (uses system_root).
                       Pass user's root ID for authenticated server requests.

        Storage backend is configured via plugins/environment, not per-context.
        For file backend: auto-generates path from JacRuntime.base_path_dir.
        For database backends (jac-scale): configured via environment variables.
        """
    static def create_j_context(user_root: (str | None)) -> ExecutionContext;

    """Attach a JacProgram to the machine."""
    static def attach_program(jac_program: JacProgram) -> None;

    """Attach a JacCompiler to the machine."""
    static def attach_compiler(jac_compiler: JacCompiler) -> None;

    """Load a module into the machine."""
    static def load_module(
        module_name: str, module: types.ModuleType, force: bool = False
    ) -> None;

    """List all loaded modules."""
    static def list_modules -> list[str];

    """List all walkers in a specific module."""
    static def list_walkers(module_name: str) -> list[str];

    """List all nodes in a specific module."""
    static def list_nodes(module_name: str) -> list[str];

    """List all edges in a specific module."""
    static def list_edges(module_name: str) -> list[str];

    """Dynamically creates archetypes (nodes, walkers, etc.) from Jac source
code.

        This leverages Python's standard import machinery via jac_import(),
        which will automatically invoke JacMetaImporter.
        """
    static def create_archetype_from_source(
        source_code: str,
        module_name: (str | None) = None,
        base_path: (str | None) = None,
        cachable: bool = False,
        keep_temporary_files: bool = False
    ) -> (types.ModuleType | None);

    """Reimport the module using Python's reload mechanism."""
    static def update_walker(
        module_name: str, items: (dict[(str, str | str | None)] | None)
    ) -> tuple[(types.ModuleType, ...)];

    """Spawn a node instance of the given node_name with attributes."""
    static def spawn_node(
        node_name: str, attributes: (dict | None) = None, module_name: str = '__main__'
    ) -> NodeArchetype;

    """Spawn a walker instance of the given walker_name."""
    static def spawn_walker(
        walker_name: str,
        attributes: (dict | None) = None,
        module_name: str = '__main__'
    ) -> WalkerArchetype;

    """Retrieve an archetype class from a module."""
    static def get_archetype(
        module_name: str, archetype_name: str
    ) -> (Archetype | None);

    """Run a function in a thread."""
    static def thread_run(func: Callable, *args: object) -> Future;

    """Wait for a thread to finish."""
    static def thread_wait(future: Any) -> None;
}

"""Plugin configuration hooks for jac.toml integration.

    Plugins can implement these hooks to register their configuration schemas
    and receive configuration values from jac.toml.
    """
class JacPluginConfig {
    """Return plugin metadata.

        Returns:
            dict with keys:
                - name: Plugin name (used in [plugins.<name>])
                - version: Plugin version
                - description: Brief description
        """
    static def get_plugin_metadata -> (dict[(str, Any)] | None);

    """Return the plugin's configuration schema.

        Returns:
            dict with keys:
                - section: Section name in jac.toml (e.g., 'byllm' for
[plugins.byllm])
                - options: dict mapping option names to their specs:
                    {
                        'option_name': {
                            'type': 'str' | 'int' | 'float' | 'bool' | 'list' |
'dict',
                            'default': <default_value>,
                            'description': 'Description of the option',
                            'env_var': 'OPTIONAL_ENV_VAR_OVERRIDE',
                            'required': False,
                        }
                    }
        """
    static def get_config_schema -> (dict[(str, Any)] | None);

    """Called when plugin configuration is loaded from jac.toml.

        Args:
            config: The plugin's configuration values from [plugins.<name>]
        """
    static def on_config_loaded(config: dict[(str, Any)]) -> None;

    """Validate plugin configuration.

        Args:
            config: The plugin's configuration values

        Returns:
            List of error messages (empty if valid)
        """
    static def validate_config(config: dict[(str, Any)]) -> list[str];

    """Register a custom dependency type.

        Allows plugins to extend [dependencies.*] sections in jac.toml.

        Returns:
            dict with keys:
                - name: Dependency type name (e.g., 'npm' for
[dependencies.npm])
                - dev_name: Dev dependency section (e.g., 'npm.dev')
                - cli_flag: CLI flag for 'jac add' (e.g., '--cl')
                - install_dir: Directory for installed deps (e.g., 'client')
                - install_handler: Callable to install packages
                - remove_handler: Callable to remove packages
        """
    static def register_dependency_type -> (dict[(str, Any)] | None);

    """Register a project template for jac create.

        Allows plugins to provide custom project templates that can be
        selected via `jac create --use <name>`.

        Returns:
            dict with keys:
                - name: Template name (e.g., 'client')
                - description: Human-readable description
                - config: dict for jac.toml content (with {{name}} placeholders)
                - files: dict[path, content] with {{name}} placeholders
                - directories: list of directories to create
                - post_create: optional callable(project_path, project_name)
        """
    static def register_project_template -> (dict[(str, Any)] | None);
}

"""Jac Feature."""
class JacRuntimeInterface(JacClassReferences, JacAccessValidation, JacNode, JacEdge, JacWalker, JacBuiltin, JacCmd, JacBasics, JacClientBundle, JacConsole, JacAPIServer, JacByLLM, JacResponseBuilder, JacUtils, JacPluginConfig) {
    """Get UserManager instance (hookable for plugins).

        Plugins can override this to provide custom UserManager implementations.
        Default returns core UserManager.

        Args:
            base_path: Base path for user data storage

        Returns:
            UserManager instance
        """
    static def get_user_manager(base_path: str) -> UserManager;

    """Get storage backend instance (hookable for plugins).

        Default returns LocalStorage. Plugins (like jac-scale) can override
        to provide cloud storage backends with full config support.

        Args:
            base_path: Base directory for file storage.
            create_dirs: Whether to auto-create directories.

        Returns:
            Storage instance (LocalStorage by default)
        """
    static def store(base_path: str = './storage', create_dirs: bool = True) -> Any;
}

"""Generate three helper classes based on a plugin class.

    - Spec class: contains @hookspec placeholder methods.
    - Impl class: contains original plugin methods decorated with @hookimpl.
    - Proxy class: contains methods that call plugin_manager.hook.<method>.

    Returns:
        Tuple of (SpecClass, ImplClass, ProxyClass).
    """
def generate_plugin_helpers(
    plugin_class: type[Any]
) -> tuple[(type[Any], type[Any], type[Any])] {
    spec_methods = {};
    impl_methods = {};
    proxy_methods = {};
    for (name, method) in inspect.getmembers(
        plugin_class, predicate=inspect.isfunction
    ) {
        if name.startswith('_') {
            continue;
        }
        sig = inspect.signature(method);
        sig_nodef = sig.replace(
            parameters=[
                p.replace(`default=inspect.Parameter.empty)
                for p in sig.parameters.values()
            ]
        );
        doc = method.__doc__ or '';
        """Create a placeholder method for the spec class.""";
        def make_spec(
            name: str, sig_nodef: inspect.Signature, doc: str, method: Callable
        ) -> Callable {
            @wraps(method)
            def placeholder(*args: object, **kwargs: object) -> None {
                ;
            }
            placeholder.__name__ = name;
            placeholder.__doc__ = doc;
            placeholder.__signature__ = sig_nodef;
            return placeholder;
        }
        spec_methods[name] = hookspec(firstresult=True)(
            make_spec(name, sig_nodef, doc, method)
        );
        wrapped_impl = wraps(method)(method);
        wrapped_impl.__signature__ = sig_nodef;
        impl_methods[name] = hookimpl(wrapped_impl);
        class_vars: dict[(str, Any)] = {};
        annotations: dict[(str, Any)] = {};
        for base in reversed(plugin_class.__mro__) {
            if (base is object) {
                continue;
            }
            base_ann = getattr(base, '__annotations__', {});
            annotations.update(base_ann);
            for (key, value) in base.__dict__.items() {
                if key.startswith('__') {
                    continue;
                }
                if (callable(value) and not isinstance(value, `type)) {
                    continue;
                }
                class_vars[key] = value;
            }
        }
        """Create a proxy method for the proxy class.""";
        def make_proxy(name: str, sig: inspect.Signature) -> Callable {
            def proxy(*args: object, **kwargs: object) -> object {
                bound = sig.bind_partial(*args, **kwargs);
                bound.apply_defaults();
                hookcaller = getattr(plugin_manager.hook, name);
                return hookcaller(**bound.arguments);
            }
            proxy.__name__ = name;
            proxy.__signature__ = sig;
            return proxy;
        }
        proxy_methods[name] = make_proxy(name, sig);
    }
    spec_cls = `type(f"{plugin_class.__name__}Spec", (object, ), spec_methods);
    impl_cls = `type(f"{plugin_class.__name__}Impl", (object, ), impl_methods);
    proxy_namespace = {};
    proxy_namespace.update(class_vars);
    if annotations {
        proxy_namespace['__annotations__'] = annotations;
    }
    proxy_namespace.update(proxy_methods);
    original_metaclass: type = cast(`type, `type(plugin_class));
    proxy_cls = original_metaclass(
        f"{plugin_class.__name__}", (object, ), proxy_namespace
    );
    return (spec_cls, impl_cls, proxy_cls);
}

with entry {
    (JacRuntimeSpec, JacRuntimeImpl, JacRuntimeInterface) = generate_plugin_helpers(
        JacRuntimeInterface
    );
    plugin_manager.add_hookspecs(JacRuntimeSpec);
}

"""Jac Machine State."""
class JacRuntime(JacRuntimeInterface) {
    with entry {
        base_path_dir: (str | None) = os.getcwd();
        full_target_path: (str | None) = None;
        compiler: (JacCompiler | None) = None;
        program: (JacProgram | None) = None;
        pool: ThreadPoolExecutor = ThreadPoolExecutor();
        exec_ctx: (ExecutionContext | None) = None;
        loaded_modules: dict[(str, types.ModuleType)] = {};
    }

    """Get or create the JacCompiler singleton.

        The compiler is separate from the program and handles all compilation
        operations. It persists across program resets and can be reused.
        """
    @classmethod
    def get_compiler(cls: Any) -> JacCompiler;

    """Get or create the JacProgram instance."""
    @classmethod
    def get_program(cls: Any) -> JacProgram;

    """Set the base path for the machine.

        When base_path is None, L3 persistence is disabled (faster for tests).
        """
    static def set_base_path(base_path: (str | None)) -> None;

    """Set the context for the machine (global, for backward compatibility)."""
    static def set_context(context: ExecutionContext) -> None;

    """Set request-scoped execution context (for web servers)."""
    static def set_request_context(context: ExecutionContext) -> None;

    """Clear request-scoped context and commit changes."""
    static def clear_request_context -> None;
}

"""Context manager to temporarily disable external plugins.

    Useful for tests that need to run without plugin interference.
    Core JacRuntimeImpl is preserved, only external plugins are disabled.

    Usage:
        from jaclang.jac0core.runtime import without_plugins

        def test_something():
            with without_plugins():
                # Test code runs without external plugins
                pass

        # Or as a pytest fixture:
        @pytest.fixture
        def no_plugins():
            with without_plugins():
                yield
    """
@contextmanager
def without_plugins -> Iterator[None] {
    external_plugins: list[tuple[(str, Any)]] = [];
    for (name, plugin) in `list(plugin_manager.list_name_plugin()) {
        if ((plugin is JacRuntimeImpl) or (name == 'JacRuntimeImpl')) {
            continue;
        }
        external_plugins.append((name, plugin));
        plugin_manager.unregister(plugin=plugin, name=name);
    }
    try {
        yield ;
    } finally {
        for (name, plugin) in external_plugins {
            with suppress(ValueError) {
                plugin_manager.register(plugin, name=name);
            }
        }
    }
}
