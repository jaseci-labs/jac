import from pathlib { Path }
import from jaclang.compiler.passes.compose.compose_model { ComposeModule }
import from jaclang.compiler.passes.ecmascript.intent.model {
    IntentComponent,
    IntentParam
}
import from jaclang.compiler.passes.ecmascript.intent.detection {
    COMPOSE_COMPONENT_TYPES,
    HOME_COMPONENT_NAMES
}
import from jaclang.compiler.passes.compose.rpc_client { RpcClientEmitter }
import from jaclang.compiler.passes.compose.gradle_scaffold {
    build_gradle_scaffold,
    package_to_path,
    emit_jac_design,
    escape_kotlin
}
import from jaclang.compiler.passes.compose.rpc_client { emit_jac_client }
import from jaclang.compiler.passes.compose.compose_native_emit { ComposeNativeEmitter }
import from jaclang.compiler.passes.compose.reactive_compose { ReactiveComposeEmitter }

impl normalize_route_segment(segment: str) -> str {
    if not segment {
        return "";
    }
    words: list[str] = [];
    current = "";
    for ch in segment {
        if ch.isalnum() {
            current += ch;
        } elif current {
            words.append(current);
            current = "";
        }
    }
    if current {
        words.append(current);
    }
    if not words {
        return "Route";
    }
    return "".join([w[0].upper() + w[1:] if w else "" for w in words]);
}

impl route_to_screen_name(path: str) -> str {
    if not path or path == "/" {
        return HOME_SCREEN_NAME;
    }
    parts = [
        p
        for p in path.strip("/").split("/")
        if p
    ];
    if not parts {
        return HOME_SCREEN_NAME;
    }
    return "".join([normalize_route_segment(p) for p in parts]) + "Screen";
}

impl component_screen_name(comp_name: str) -> str {
    if not comp_name {
        return HOME_SCREEN_NAME;
    }
    if comp_name.endswith("Screen") {
        return comp_name;
    }
    return f"{comp_name}Screen";
}

impl screen_name_for(
    path: (str | None), comp_name: (str | None), is_home: bool = False
) -> str {
    if is_home or path == "/" {
        return HOME_SCREEN_NAME;
    }
    if path {
        return route_to_screen_name(path);
    }
    if comp_name {
        return component_screen_name(comp_name);
    }
    return HOME_SCREEN_NAME;
}

obj _RouteEntry {
    has path: str,
        screen_name: str,
        comp: (IntentComponent | None) = None,
        body_override: str = "";
}

def _resolve_route_plan(model: ComposeModule) -> list[_RouteEntry] {
    entries: list[_RouteEntry] = [];
    name_to_path: dict[str, str] = {};
    seen_paths: set[str] = set();

    def add(
        path: str, sname: str, comp: (IntentComponent | None), body_override: str = ""
    ) {
        prior = name_to_path.get(sname);
        if prior is not None and prior != path {
            model.intent.add_diagnostic(
                f"routes '{prior}' and '{path}' both lower to screen '{sname}' "
                "- give one an explicit screen_name or rename it so each emits "
                "a distinct Kotlin function"
            );
        }
        name_to_path[sname] = path;
        entries.append(
            _RouteEntry(
                path=path, screen_name=sname, comp=comp, body_override=body_override
            )
        );
    }

    for route in model.intent.routes {
        if route.path in seen_paths {
            continue;
        }
        seen_paths.add(route.path);
        sname = route.screen_name or route_to_screen_name(route.path);
        comp = None;
        if route.component and route.component in model.intent.components {
            comp = model.intent.components[route.component];
        }
        add(route.path, sname, comp);
    }

    for (cname, comp) in model.intent.components.items() {
        if comp.route_path {
            path = comp.route_path;
            sname = screen_name_for(path, cname);
        } elif comp.is_screen {
            path = "/";
            sname = screen_name_for(path, cname);
        } else {
            continue;
        }
        if path in seen_paths {
            continue;
        }
        seen_paths.add(path);
        add(path, sname, comp);
    }

    if not entries {
        for (cname, comp) in model.intent.components.items() {
            if model.compose_view_for(cname) is None {
                continue;
            }
            sname = screen_name_for(
                None, cname, is_home=(cname in HOME_COMPONENT_NAMES)
            );
            add("/", sname, comp);
            break;
        }
    }

    if not entries {
        add(
            "/",
            HOME_SCREEN_NAME,
            None,
            body_override=(
                "    Column(modifier = Modifier.fillMaxSize()) {\n"
                '        Text(text = "Jac Compose")\n'
                "    }"
            )
        );
    }
    return entries;
}

def _screen_imports -> str {
    return """import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.text.font.*
import androidx.compose.ui.unit.*
import androidx.compose.ui.platform.LocalContext
import androidx.activity.compose.BackHandler
import android.content.Intent
import android.net.Uri
import kotlinx.coroutines.launch
""";
}

def _emit_kotlin_imports(model: ComposeModule) -> str {
    lines = model?.kotlin_imports or [];
    if not lines {
        return "";
    }
    return "".join([f"import {line}\n" for line in lines]);
}

def _emit_jac_math(pkg: str) -> str {
    return (
        f"package {pkg}\n\n"
        "object JacMath {\n"
        "    fun truediv(a: Number, b: Number): Double "
        "= a.toDouble() / b.toDouble()\n"
        "    fun floorDiv(a: Int, b: Int): Int = Math.floorDiv(a, b)\n"
        "    fun floorDiv(a: Long, b: Long): Long = Math.floorDiv(a, b)\n"
        "    fun floorDiv(a: Double, b: Double): Double "
        "= kotlin.math.floor(a / b)\n"
        "    fun floorDiv(a: Number, b: Number): Double "
        "= kotlin.math.floor(a.toDouble() / b.toDouble())\n"
        "    fun mod(a: Int, b: Int): Int = Math.floorMod(a, b)\n"
        "    fun mod(a: Long, b: Long): Long = Math.floorMod(a, b)\n"
        "    fun mod(a: Double, b: Double): Double = ((a % b) + b) % b\n"
        "    fun mod(a: Number, b: Number): Double "
        "= ((a.toDouble() % b.toDouble()) + b.toDouble()) % b.toDouble()\n"
        "}\n"
    );
}

def _section_registry_stub -> str {
    return """
class JacSectionRegistry {
    val positions = mutableMapOf<String, Int>()
}

private data class JacRouteEntry(val path: String, val fragment: String?)

enum class JacNavOperation { Push, Replace }
enum class JacExternalMode { WebView, System }
""";
}

impl ComposeEmit.route_plan -> any {
    if self._plan is None {
        self._plan = _resolve_route_plan(self.model);
    }
    return self._plan;
}

impl ComposeEmit.emit_jac_app -> str {
    plan = self.route_plan();

    when_arms: list[str] = [];
    for entry in plan {
        when_arms.append(
            f'                    "{escape_kotlin(
                entry.path
            )}" -> Box(modifier = Modifier.fillMaxSize().verticalScroll(scrollState)) {{ '
            f"{entry.screen_name}(viewportWidth, scrollState, sectionRegistry, ::navigate, ::goBack, ::openExternal) }}"
        );
    }
    first_screen = plan[0].screen_name if plan else HOME_SCREEN_NAME;
    when_arms.append(
        "                    else -> Box(modifier = Modifier.fillMaxSize().verticalScroll(scrollState)) { "
        f"{first_screen}(viewportWidth, scrollState, sectionRegistry, ::navigate, ::goBack, ::openExternal) }}"
    );
    arms = "\n".join(when_arms);

    if self.dev {
        context_init = (
            "    val context = LocalContext.current\n"
            '    val hmr = context.getSharedPreferences("jac-hmr", android.content.Context.MODE_PRIVATE)\n'
            '    val restoredPath = hmr.getString("path", null)?.takeIf { JacRoutes.paths.contains(it) }\n'
            "    val initialPath = restoredPath ?: (if (JacRoutes.paths.contains(startPath)) startPath else JacRoutes.initialPath)\n"
        );
        persist_effect = (
            "    LaunchedEffect(currentEntry.path) {\n"
            '        hmr.edit().putString("path", currentEntry.path).apply()\n'
            "    }\n"
        );
    } else {
        context_init = (
            "    val context = LocalContext.current\n"
            "    val initialPath = if (JacRoutes.paths.contains(startPath)) startPath else JacRoutes.initialPath\n"
        );
        persist_effect = "";
    }

    return f"""
@Composable
fun JacApp(startPath: String = JacRoutes.initialPath, startFragment: String? = null, navigationRequest: Int = 0) {{
{context_init}    val initialFragment = startFragment?.takeIf {{ JacRoutes.sections[initialPath]?.contains(it) == true }}
    var currentEntry by remember {{ mutableStateOf(JacRouteEntry(initialPath, initialFragment)) }}
    var externalUrl by remember {{ mutableStateOf<String?>(null) }}
    val backStack = remember {{ mutableStateListOf<JacRouteEntry>() }}
    val scrollState = rememberScrollState()
    val sectionRegistry = remember(currentEntry.path) {{ JacSectionRegistry() }}
    fun navigate(operation: JacNavOperation, target: String, fragment: String?) {{
        val path = target.ifEmpty {{ currentEntry.path }}
        if (!JacRoutes.paths.contains(path)) {{
            return
        }}
        val destination = JacRouteEntry(path, fragment?.takeIf {{ JacRoutes.sections[path]?.contains(it) == true }})
        if (destination == currentEntry) {{
            return
        }}
        if (operation == JacNavOperation.Replace) {{
            currentEntry = destination
        }} else {{
            backStack.add(currentEntry)
            currentEntry = destination
        }}
    }}
    fun goBack() {{
        if (externalUrl != null) {{
            externalUrl = null
        }} else if (backStack.isNotEmpty()) {{
            currentEntry = backStack.removeAt(backStack.lastIndex)
        }} else if (currentEntry.path != JacRoutes.initialPath || currentEntry.fragment != null) {{
            currentEntry = JacRouteEntry(JacRoutes.initialPath, null)
        }}
    }}
    fun openExternal(mode: JacExternalMode, target: String) {{
        if (mode == JacExternalMode.WebView) {{
            externalUrl = target
        }} else {{
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(target)))
        }}
    }}
    LaunchedEffect(navigationRequest) {{
        navigate(JacNavOperation.Replace, initialPath, initialFragment)
    }}
{persist_effect}    LaunchedEffect(currentEntry.path) {{
        scrollState.scrollTo(0)
    }}
    BackHandler(enabled = true) {{
        goBack()
    }}
    Box(modifier = Modifier.fillMaxSize().background(JacDesign.background)) {{
        BoxWithConstraints(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.TopStart) {{
            val viewportWidth = maxWidth
            when (currentEntry.path) {{
{arms}
            }}
        }}
    }}
}}
""";
}

def _emit_screen_fun(name: str, prelude: str, body: str) -> str {
    return f"""
@Composable
fun {name}(viewportWidth: Dp, scrollState: ScrollState, sectionRegistry: JacSectionRegistry, navigate: (JacNavOperation, String, String?) -> Unit, goBack: () -> Unit, openExternal: (JacExternalMode, String) -> Unit) {{
{prelude}{body}
}}
""";
}

def _kt_param_type(jac_type: str) -> str {
    raw = jac_type.strip();
    if raw in COMPOSE_COMPONENT_TYPES {
        return "@Composable () -> Unit";
    }
    return RpcClientEmitter().jac_type_to_kotlin(raw);
}

def _emit_composable_param(p: IntentParam) -> str {
    kt_type = _kt_param_type(p.jac_type);
    if p.default_kt {
        return f"{p.name}: {kt_type} = {p.default_kt}";
    }
    return f"{p.name}: {kt_type}";
}

def _emit_composable_fun(
    name: str, prelude: str, body: str, params: (list[IntentParam] | None) = None
) -> str {
    resolved = params if params is not None else [];
    sig = ", ".join([_emit_composable_param(p) for p in resolved]);
    return f"""
@Composable
fun {name}({sig}) {{
{prelude}{body}
}}
""";
}

def _merge_prelude(react_prelude: str, needs_scope: bool, body: str = "") -> str {
    if body and ("JacClient" in body or "scope.launch" in body) {
        needs_scope = True;
    }
    if needs_scope and "rememberCoroutineScope()" not in react_prelude {
        return "    val scope = rememberCoroutineScope()\n" + react_prelude;
    }
    return react_prelude;
}

def _emit_screen_body(
    comp: (IntentComponent | None),
    native_em: ComposeNativeEmitter,
    model: ComposeModule
) -> str {
    if comp is None {
        return "    Column(modifier = Modifier.fillMaxSize()) {\n    }";
    }
    view = model.compose_view_for(comp.name);
    if view is not None {
        return native_em.emit_view(view);
    }

    if comp.view is not None {
        model.intent.add_diagnostic(
            f"component '{comp.name}' uses DOM IR (view), which the Compose "
            "framework does not support — use Compose primitives "
            "(Column, Text, Button, …)"
        );
    }
    return "    Column(modifier = Modifier.fillMaxSize()) {\n    }";
}

obj _ScreenPlanEntry {
    has name: str,
        comp: (IntentComponent | None) = None,
        body_override: str = "";
}

def _screen_plan_from_entries(entries: list[_RouteEntry]) -> list[_ScreenPlanEntry] {
    return [
        _ScreenPlanEntry(
            name=e.screen_name, comp=e.comp, body_override=e.body_override
        ) for e in entries
    ];
}

def _collect_reusable_plan(
    model: ComposeModule, seen: set[str]
) -> list[_ScreenPlanEntry] {
    entries: list[_ScreenPlanEntry] = [];
    for (cname, comp) in model.intent.components.items() {
        if comp.is_screen or comp.route_path {
            continue;
        }
        if model.compose_view_for(cname) is None {
            continue;
        }
        if cname in seen {
            continue;
        }
        seen.add(cname);
        entries.append(_ScreenPlanEntry(name=cname, comp=comp));
    }
    return entries;
}

def _emit_planned_screen(
    plan_entry: _ScreenPlanEntry,
    native_em: ComposeNativeEmitter,
    react_em: ReactiveComposeEmitter,
    model: ComposeModule
) -> str {
    if plan_entry.body_override {
        return _emit_screen_fun(plan_entry.name, "", plan_entry.body_override);
    }
    prelude = react_em.emit_prelude(plan_entry.comp) if plan_entry.comp else "";
    body = _emit_screen_body(plan_entry.comp, native_em, model);
    prelude = _merge_prelude(prelude, native_em.needs_coroutine_scope, body);
    return _emit_screen_fun(plan_entry.name, prelude, body);
}

def _emit_planned_reusable(
    plan_entry: _ScreenPlanEntry,
    native_em: ComposeNativeEmitter,
    react_em: ReactiveComposeEmitter,
    model: ComposeModule
) -> str {
    prelude = react_em.emit_prelude(plan_entry.comp) if plan_entry.comp else "";
    body = _emit_screen_body(plan_entry.comp, native_em, model);
    prelude = _merge_prelude(prelude, native_em.needs_coroutine_scope, body);
    return _emit_composable_fun(
        plan_entry.name,
        prelude,
        body,
        plan_entry.comp.params if plan_entry.comp else []
    );
}

impl ComposeEmit.emit_screens -> str {
    pkg = self.model.intent.package_name;
    native_em = ComposeNativeEmitter();
    react_em = ReactiveComposeEmitter();

    screen_plan = _screen_plan_from_entries(self.route_plan());
    seen: set[str] = set();
    for plan_entry in screen_plan {
        seen.add(plan_entry.name);
    }
    screens: list[str] = [];
    for plan_entry in screen_plan {
        screens.append(
            _emit_planned_screen(plan_entry, native_em, react_em, self.model)
        );
    }

    reusable_plan = _collect_reusable_plan(self.model, seen);
    reusable: list[str] = [];
    for plan_entry in reusable_plan {
        reusable.append(
            _emit_planned_reusable(plan_entry, native_em, react_em, self.model)
        );
    }

    for diag in native_em.diagnostics {
        self.model.intent.add_diagnostic(diag);
    }

    design = emit_jac_design();
    app = self.emit_jac_app();
    return (
        f"package {pkg}\n\n"
        + _screen_imports()
        + _emit_kotlin_imports(self.model)
        + "\n"
        + design
        + "\n"
        + _section_registry_stub()
        + "\n"
        + app
        + "\n"
        + "\n".join(screens)
        + ("\n" + "\n".join(reusable) if reusable else "")
    );
}

def _prune_stale_kotlin(out: Path, java_root: str, keep: set[str]) -> int {
    pkg_dir = out / java_root;
    if not pkg_dir.is_dir() {
        return 0;
    }
    removed = 0;
    for path in pkg_dir.rglob("*.kt") {
        try {
            rel = path.relative_to(out).as_posix();
        } except Exception {
            continue;
        }
        if rel in keep {
            continue;
        }
        try {
            path.unlink();
            removed += 1;
        } except Exception {
            ;
        }
    }
    return removed;
}

impl ComposeEmit.write -> list[Path] {
    out = self.out_dir;
    out.mkdir(parents=True, exist_ok=True);

    routes = [e.path for e in self.route_plan()];

    files = build_gradle_scaffold(
        self.model.intent.package_name,
        self.model.intent.app_name,
        self.model.intent.backend_url,
        routes,
        self.dev
    );

    pkg_path = package_to_path(self.model.intent.package_name);
    base_root = f"app/src/main/java/{pkg_path}";
    hot_root = f"hot/src/main/java/{pkg_path}";

    screens_root = hot_root if self.dev else base_root;

    screens_src = self.emit_screens();
    client_src = emit_jac_client(
        self.model.intent.package_name, self.model.intent.interop_manifest
    );

    if self.model.intent.diagnostics {
        try {
            import from jaclang.cli.console { console }
            console.error("  Compose codegen failed with diagnostics:");
            for diag in self.model.intent.diagnostics {
                console.error(f"    - {diag}");
            }
        } except Exception {
            ;
        }
        raise RuntimeError(
            "Compose codegen produced diagnostics — refusing to emit a broken "
            "Android project. Fix the issues above (or use <Raw kotlin=\"…\"> "
            "for verbatim Kotlin where the surface is genuinely unsupported)."
        );
    }
    files[f"{screens_root}/Screens.kt"] = screens_src;
    files[f"{screens_root}/JacClient.kt"] = client_src;
    files[f"{screens_root}/JacMath.kt"] = _emit_jac_math(
        self.model.intent.package_name
    );

    written: list[Path] = [];
    reused = 0;
    for (rel, content) in files.items() {
        path = out / rel;
        path.parent.mkdir(parents=True, exist_ok=True);

        if path.is_file() {
            try {
                if path.read_text(encoding="utf-8") == content {
                    reused += 1;
                    written.append(path);
                    continue;
                }
            } except Exception {
                ;
            }
        }
        path.write_text(content, encoding="utf-8");
        written.append(path);
    }

    keep = set(files.keys());
    pruned = _prune_stale_kotlin(out, base_root, keep);
    if self.dev {
        pruned += _prune_stale_kotlin(out, hot_root, keep);
    } else {
        orphan_hot = out / "hot";
        if orphan_hot.is_dir() {
            import shutil;
            try {
                shutil.rmtree(orphan_hot);
            } except Exception {
                ;
            }
        }
    }

    try {
        import from jaclang.cli.console { console }
        if reused {
            console.print(
                f"  ✔ Wrote {len(written) - reused}, reused {reused} unchanged"
                    + (f", pruned {pruned} stale" if pruned else "")
                    + " (gradle cache)",
                style="muted"
            );
        }
    } except Exception {
        ;
    }
    return written;
}
