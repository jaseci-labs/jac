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
    Protocol,
    TypeAlias,
    TypeVar
}
import from uuid { UUID }
import from jaclang.jac0core.archetype {
    GenericEdge,
    ObjectAnchor,
    ObjectSpatialDestination,
    ObjectSpatialFunction,
    ObjectSpatialPath,
    Root
}
import from jaclang.jac0core.constant { EdgeDir, colors }
import from jaclang.jac0core.constructs {
    AccessLevel,
    access_level_cast,
    Anchor,
    Archetype,
    EdgeAnchor,
    EdgeArchetype,
    JsxElement,
    NodeAnchor,
    NodeArchetype,
    PermissionDenied,
    WalkerAnchor,
    WalkerArchetype
}
import from jaclang.jac0core.modresolver {
    infer_language,
    find_jac_project_root,
    push_import_base,
    pop_import_base
}
import from jaclang.jac0core.mtp { MTIR, Info, MTRuntime }
import from jaclang.jac0core { plugin }
import type from http.server { BaseHTTPRequestHandler }
import type from jaclang.cli.console { JacConsole as ConsoleImpl }
import type from jaclang.jac0core.compiler { JacCompiler }
import type from jaclang.jac0core.program { JacProgram }
import type from jaclang.runtimelib.client_bundle { ClientBundle, ClientBundleBuilder }
import type from jaclang.runtimelib.context { ExecutionContext }
import type from jaclang.runtimelib.server { JacAPIServer as JacServer }
import type from jaclang.runtimelib.server { ModuleIntrospector, UserManager }

glob plugin_manager = plugin.PluginManager('jac'),
     hookspec = plugin.HookspecMarker('jac'),
     hookimpl = plugin.HookimplMarker('jac'),
     hookable = plugin.HookableMarker(),
     logger = getLogger(__name__),
     T = TypeVar('T'),
     P = ParamSpec('P'),
     JsonValue: TypeAlias = None | str | int | float | bool | `list['JsonValue'] | `dict[
         (str, 'JsonValue')
     ],
     StatusCode: TypeAlias = Literal[(200, 201, 400, 401, 404, 500, 503)],
     _request_context: ContextVar[ExecutionContext | None] = ContextVar(
         'request_context', default=None
     ),
     _default_base_path_dir: list = [os.getcwd()],
     _default_full_target_path: list = [None],
     _shared_root_resolver: list = [None, None];

def _prefetch_edges(origin: list[NodeArchetype]) -> None {
    ctx = JacRuntimeInterface.get_context();
    if not hasattr(ctx.mem, 'batch_get') {
        return;
    }
    edge_ids: list = [];
    for nd in origin {
        nanch = nd.__jac__;
        for edge_stub in nanch.edges {
            if not edge_stub.is_populated() {
                edge_ids.append(edge_stub.id);
            }
        }
    }
    if edge_ids {
        ctx.mem.batch_get(edge_ids);
    }
    node_ids: list = [];
    for nd in origin {
        nanch = nd.__jac__;
        for anchor in nanch.edges {
            loaded = ctx.mem.get(anchor.id);
            if loaded {
                if loaded?.source
                and loaded.source is not None
                and not loaded.source.is_populated() {
                    node_ids.append(loaded.source.id);
                }
                if loaded?.target
                and loaded.target is not None
                and not loaded.target.is_populated() {
                    node_ids.append(loaded.target.id);
                }
            }
        }
    }
    if node_ids {
        ctx.mem.batch_get(node_ids);
    }
}

def resolve_ref(
    stub: (Anchor | None), referrer: (Anchor | None) = None
) -> (Anchor | None) {
    if stub is None {
        return None;
    }
    if stub.is_populated() {
        return stub;
    }
    stub.populate();
    if stub.is_populated() {
        return stub;
    }
    ctx = JacRuntimeInterface.get_context();

    if ctx.mem.is_recoverable_quarantine(stub.id) {
        return None;
    }

    if os.environ.get("JAC_SV_SIBLING") == "1" {
        logger.debug(
            f"unresolvable ref {type(stub).__name__} [{stub.id}] in sibling "
            "service; skipping without heal (peer-owned or owner will heal)"
        );
        return None;
    }
    ref_repr = referrer.id if referrer is not None else '?';
    logger.error(
        f"dangling reference: {type(stub).__name__} [{stub.id}] cited by "
        f"{ref_repr} does not resolve; quarantining and pruning"
    );
    try {
        ctx.mem.quarantine_ref(referrer, stub);
    } except Exception as e {
        logger.debug(f"heal of dangling ref {stub.id} failed: {e}");
    }
    return None;
}

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

obj LLMModel(Protocol) {
    has call_params: dict[(str, object)];

    def __call__(**kwargs: object) -> LLMModel;
}

class JacContext {
    static def get_context -> ExecutionContext;
    static def reset_graph(root_node: (Root | None) = None) -> int;
    @hookable
    static def create_j_context(
        user_root: (str | None),
        base_path_dir: (str | None) = None,
        full_target_path: (str | None) = None
    ) -> ExecutionContext;

    static def attach_program(jac_program: JacProgram) -> None;
    static def attach_compiler(jac_compiler: JacCompiler) -> None;
    static def thread_run(func: Callable, *args: object) -> Future;
    static def thread_wait(future: any) -> None;
}

class JacPersistence {
    static def commit(anchor: Anchor | Archetype | None = None) -> None;
    static async def acommit(anchor: Anchor | Archetype | None = None) -> None;
    static def on_commit(callback: Callable) -> None;
    static def get_object(id: str) -> (Archetype | None);
    static async def aget_object(id: str) -> (Archetype | None);
    static def object_ref(`obj: Archetype) -> str;
    static def save(`obj: (Archetype | Anchor)) -> None;
    static def destroy(objs: Archetype | Anchor | list[(Archetype | Anchor)]) -> None;
    @hookable
    static def get_user_manager(base_path: str) -> UserManager;

    @hookable
    static def store(base_path: str = './storage', create_dirs: bool = True) -> any;

    static def get_persistent_memory(config: dict) -> any;
}

class JacAccessValidation {
    static def _resolve_anchor(
        archetype: Archetype
    ) -> tuple[Anchor, ExecutionContext];

    static def _check_access(
        `to: Anchor, min_level: AccessLevel, operation: str
    ) -> bool;

    static def allow_root(
        archetype: Archetype,
        root_id: UUID,
        level: (AccessLevel | int | str | None) = None
    ) -> None;

    static def disallow_root(
        archetype: Archetype,
        root_id: UUID,
        level: (AccessLevel | int | str | None) = None
    ) -> None;

    static def perm_grant(
        archetype: Archetype, level: (AccessLevel | int | str | None) = None
    ) -> None;

    static def perm_revoke(archetype: Archetype) -> None;
    static def check_read_access(`to: Anchor) -> bool;
    static def check_connect_access(`to: Anchor, op_hint: str = "connect") -> bool;
    static def check_write_access(`to: Anchor, op_hint: str = "write") -> bool;
    static def check_access_level(`to: Anchor, no_custom: bool = False) -> AccessLevel;
}

class JacGraph {
    static def get_edges(
        origin: list[NodeArchetype], destination: ObjectSpatialDestination
    ) -> list[EdgeArchetype];

    static def get_edges_with_node(
        origin: list[NodeArchetype],
        destination: ObjectSpatialDestination,
        from_visit: bool = False
    ) -> list[(EdgeArchetype | NodeArchetype)];

    static def edges_to_nodes(
        origin: list[NodeArchetype], destination: ObjectSpatialDestination
    ) -> list[NodeArchetype];

    static def refs(
        path: ObjectSpatialPath | NodeArchetype | list[NodeArchetype],
        post_filter: (Callable[([Archetype], bool)] | None) = None,
        slc: (slice | None) = None
    ) -> list[NodeArchetype] | list[EdgeArchetype] | list[
        (NodeArchetype | EdgeArchetype)
    ];

    static async def arefs(
        path: ObjectSpatialPath | NodeArchetype | list[NodeArchetype]
    ) -> None;

    static def filter_on(
        items: list[Archetype], func: Callable[([Archetype], bool)]
    ) -> list[Archetype];

    static def connect(
        left: (NodeArchetype | list[NodeArchetype]),
        right: (NodeArchetype | list[NodeArchetype]),
        `edge: type[EdgeArchetype] | EdgeArchetype | None = None,
        undir: bool = False,
        conn_assign: (tuple[(tuple, tuple)] | None) = None,
        edges_only: bool = False
    ) -> (NodeArchetype | list[NodeArchetype] | list[EdgeArchetype]);

    static def disconnect(
        left: (NodeArchetype | list[NodeArchetype]),
        right: (NodeArchetype | list[NodeArchetype]),
        dir: EdgeDir = EdgeDir.OUT,
        filter: (Callable[([EdgeArchetype], bool)] | None) = None
    ) -> bool;

    static def assign_all(
        target: list[T], attr_val: tuple[(tuple[str], tuple[any])]
    ) -> list[T];

    static def root -> Root;
    static def get_all_root -> list[Root];
    static def build_edge(
        is_undirected: bool,
        conn_type: type[EdgeArchetype] | EdgeArchetype | None,
        conn_assign: (tuple[(tuple, tuple)] | None)
    ) -> Callable[([NodeAnchor, NodeAnchor], EdgeArchetype)];
}

class JacWalker {
    static def `visit(
        `walker: WalkerArchetype,
        expr:
            (
                list[(NodeArchetype | EdgeArchetype)] | list[NodeArchetype] | list[
                    EdgeArchetype
                ] | NodeArchetype | EdgeArchetype | ObjectSpatialPath
            ),
        insert_loc: int = -1
    ) -> bool;

    static def spawn_call(
        `walker: WalkerAnchor, nd: (NodeAnchor | EdgeAnchor)
    ) -> WalkerArchetype;

    static async def async_spawn_call(
        `walker: WalkerAnchor, nd: (NodeAnchor | EdgeAnchor)
    ) -> WalkerArchetype;

    static def `spawn(
        op1: (Archetype | list[Archetype]), op2: (Archetype | list[Archetype])
    ) -> (WalkerArchetype | Coroutine);

    static def `disengage(`walker: WalkerArchetype) -> bool;
}

class JacArchetype {
    static def make_archetype(cls: type[Archetype]) -> type[Archetype];
    static def field(
        factory: (Callable[([], T)] | None) = None, `init: bool = True
    ) -> T;

    static def on_entry(func: Callable) -> Callable;
    static def on_exit(func: Callable) -> Callable;
    static def set_trigger(
        trigger_thunk: Callable
    ) -> Callable[([Callable], Callable)];
}

class JacModule {
    static def impl_patch_filename(
        file_loc: str
    ) -> Callable[([Callable[(P, T)]], Callable[(P, T)])];

    static def jac_import(
        target: str,
        base_path: str,
        absorb: bool = False,
        override_name: (str | None) = None,
        items: (dict[(str, str | str | None)] | None) = None,
        reload_module: (bool | None) = False,
        lng: (str | None) = None
    ) -> tuple[(types.ModuleType, ...)];

    static def load_module(
        module_name: str, module: types.ModuleType, force: bool = False
    ) -> None;

    static def create_archetype_from_source(
        source_code: str,
        module_name: (str | None) = None,
        base_path: (str | None) = None,
        cachable: bool = False,
        keep_temporary_files: bool = False
    ) -> (types.ModuleType | None);

    static def update_walker(
        module_name: str, items: (dict[(str, str | str | None)] | None)
    ) -> tuple[(types.ModuleType, ...)];
}

class JacIntrospection {
    static def list_modules -> list[str];
    static def list_walkers(module_name: str) -> list[str];
    static def list_nodes(module_name: str) -> list[str];
    static def list_edges(module_name: str) -> list[str];
    static def spawn_node(
        node_name: str, attributes: (dict | None) = None, module_name: str = '__main__'
    ) -> NodeArchetype;

    static def spawn_walker(
        walker_name: str,
        attributes: (dict | None) = None,
        module_name: str = '__main__'
    ) -> WalkerArchetype;

    static def get_archetype(
        module_name: str, archetype_name: str
    ) -> (Archetype | None);
}

class JacLLM {
    @hookable
    static def get_mtir(
        caller: Callable,
        args: dict[((int | str), object)],
        call_params: dict[(str, object)]
    ) -> MTRuntime;

    static def `sem(semstr: str, inner_semstr: dict[(str, str)]) -> Callable;
    @hookable
    static def call_llm(model: LLMModel, mt_run: MTRuntime) -> any;

    @hookable
    static async def acall_llm(model: LLMModel, mt_run: MTRuntime) -> any;

    @hookable
    static def `by(model: LLMModel) -> Callable;

    static def filter_visitable_by(
        connected_nodes: list[NodeArchetype], model: LLMModel, descriptions: str = ''
    ) -> list[NodeArchetype];

    @hookable
    static def by_operator(lhs: any, rhs: any) -> any;

    @hookable
    static def default_llm -> LLMModel;

    static def add_mtir_to_map(scope: str, mtir: Info) -> None;
    static def get_mtir_from_map(scope: str) -> (Info | None);
}

class JacServe {
    static def get_client_bundle_builder -> ClientBundleBuilder;
    static def build_client_bundle(
        module: types.ModuleType, force: bool = False
    ) -> ClientBundle;

    static def format_build_error(
        error_output: str, project_dir: Path, config: object = None
    ) -> str;

    @hookable
    static def get_api_server_class -> type;

    @hookable
    static def ensure_sv_service(module_name: str, base_path: str) -> None;

    @hookable
    static def sv_service_call(module_name: str, func_name: str, args: dict) -> any;

    @hookable
    static def sv_walker_call(
        module_name: str, walker_name: str, args: dict, stub_cls: any
    ) -> any;

    @hookable
    static def get_sv_registry -> dict[str, str];

    @hookable
    static def create_server(
        jac_server: JacServer, host: str, port: int, max_retries: int = 10
    ) -> HTTPServer;

    static def render_page(
        introspector: ModuleIntrospector,
        function_name: str,
        args: dict[(str, Any)],
        username: str
    ) -> dict[(str, Any)];

    static def get_client_js(introspector: ModuleIntrospector) -> str;
    static def send_json(
        handler: BaseHTTPRequestHandler,
        status: StatusCode,
        data: dict[(str, JsonValue)]
    ) -> None;

    static def send_html(
        handler: BaseHTTPRequestHandler, status: StatusCode, body: str
    ) -> None;

    static def send_javascript(handler: BaseHTTPRequestHandler, code: str) -> None;
    static def send_css(handler: BaseHTTPRequestHandler, css_code: str) -> None;
    static def send_static_file(
        handler: BaseHTTPRequestHandler,
        file_path: Path,
        content_type: (str | None) = None
    ) -> None;
}

class JacTest {
    static def jac_test(description: str = "") -> Callable;
    static def run_test(
        filepath: str,
        func_name: (str | None) = None,
        filter: (str | None) = None,
        xit: bool = False,
        maxfail: (int | None) = None,
        directory: (str | None) = None,
        verbose: bool = False
    ) -> int;
}

class JacBuiltin {
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

    static def jsx(
        tag: object,
        attributes: (Mapping[(str, object)] | None) = None,
        children: (Sequence[object] | None) = None
    ) -> JsxElement;

    static def log_report(expr: any, custom: bool = False) -> None;
    static def safe_subscript(`obj: any, key: any) -> any;
    static def get_console -> ConsoleImpl;
}

class JacCmd {
    @hookable
    static def create_cmd -> None;

    static def run_ai_agent(req: object) -> int;
}

class JacConfig {
    @hookable
    static def get_plugin_metadata -> (dict[(str, Any)] | None);

    @hookable
    static def get_config_schema -> (dict[(str, Any)] | None);

    static def on_config_loaded(config: dict[(str, Any)]) -> None;
    static def validate_config(config: dict[(str, Any)]) -> list[str];
    @hookable
    static def register_dependency_type -> (dict[(str, Any)] | None);

    @hookable(firstresult=False)
    static def register_project_template -> (dict[(str, Any)] | None);
}

class JacRuntimeInterface(JacClassReferences, JacContext, JacPersistence, JacAccessValidation, JacGraph, JacWalker, JacArchetype, JacModule, JacIntrospection, JacLLM, JacServe, JacTest, JacBuiltin, JacCmd, JacConfig) {}

def build_plugin_hook_layer(iface: type[any]) -> tuple[(type[any], type[any])] {
    spec_methods = {};
    impl_methods = {};
    proxy_methods = {};
    for (name, method) in inspect.getmembers(iface, predicate=inspect.isfunction) {
        if name.startswith('_') {
            continue;
        }
        raw = inspect.getattr_static(iface, name, None);
        hook_opts = raw?._jac_hookable;
        if hook_opts is None {
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
            def placeholder(*args: object, **kwargs: object) {
                ;
            }
            placeholder.__name__ = name;
            placeholder.__doc__ = doc;
            placeholder.__signature__ = sig_nodef;
            return placeholder;
        }
        spec_methods[name] = hookspec(firstresult=hook_opts.get('firstresult', True))(
            make_spec(name, sig_nodef, doc, method)
        );
        wrapped_impl = wraps(method)(method);
        wrapped_impl.__signature__ = sig_nodef;
        impl_methods[name] = hookimpl(wrapped_impl);
        """Create a proxy method that dispatches through plugin_manager.""";
        def make_proxy(name: str, sig: inspect.Signature, is_coro: bool) -> Callable {
            if is_coro {
                async def async_proxy(*args: object, **kwargs: object) -> object {
                    bound = sig.bind_partial(*args, **kwargs);
                    bound.apply_defaults();
                    hookcaller = getattr(plugin_manager.hook, name);
                    result = hookcaller(**bound.arguments);
                    if inspect.iscoroutine(result) {
                        return await result;
                    }
                    return result;
                }
                async_proxy.__name__ = name;
                async_proxy.__signature__ = sig;
                return async_proxy;
            }
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
        proxy_methods[name] = make_proxy(
            name, sig, inspect.iscoroutinefunction(method)
        );
    }
    spec_cls = `type(f"{iface.__name__}Spec", (object, ), spec_methods);
    impl_cls = `type(f"{iface.__name__}Impl", (object, ), impl_methods);

    for (hname, proxy_fn) in proxy_methods.items() {
        setattr(iface, hname, staticmethod(proxy_fn));
    }
    return (spec_cls, impl_cls);
}

with entry {
    (JacRuntimeSpec, JacRuntimeImpl) = build_plugin_hook_layer(JacRuntimeInterface);
    plugin_manager.add_hookspecs(JacRuntimeSpec);
}

class JacRuntime(JacRuntimeInterface) {
    with entry {
        compiler: (JacCompiler | None) = None;
        program: (JacProgram | None) = None;
        pool: ThreadPoolExecutor = ThreadPoolExecutor();
        exec_ctx: (ExecutionContext | None) = None;
        loaded_modules: dict[(str, types.ModuleType)] = {};

        strict_permissions: bool = os.environ.get(
            "JAC_STRICT_PERMISSIONS", ""
        ).strip().lower() in ("1", "true", "yes", "on");
    }

    @classmethod
    def get_compiler(cls: any) -> JacCompiler;

    @classmethod
    def get_program(cls: any) -> JacProgram;

    static def get_base_path_dir -> (str | None);
    static def get_full_target_path -> (str | None);
    static def set_base_path(base_path: (str | None)) -> None;
    static def set_full_target_path(target_path: (str | None)) -> None;
    static def get_shared_root -> Root;
    static def set_shared_root_resolver(
        resolver: (Callable[([], (str | None))] | None)
    ) -> None;

    static def set_context(context: ExecutionContext) -> None;
    static def push_request_context(context: ExecutionContext) -> any;
    static def reset_request_context(token: any) -> None;
}

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
