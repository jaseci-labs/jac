obj KindSpec {
    has name: str,
        description: str,
        `entry: str,
        action: str,
        verb: str,
        summary: str,
        flags: dict[str, any] = {},
        needs_entry: bool = True,
        output_dir: str = "",
        codespace: str = "",
        ui: str = "",
        has_server: bool = False;
}

glob KIND_SPECS: dict[str, KindSpec] = {
         spec.name: spec
         for spec in [
             KindSpec(
                 name="cli",
                 description="Command-line Jac project",
                 `entry="main",
                 action="execute",
                 verb="run",
                 summary="Execute {kind} entry-point {entry}"
             ),
             KindSpec(
                 name="cli-native",
                 description="Natively-compiled Jac program (compiled and run)",
                 `entry="main",
                 action="execute",
                 verb="run",
                 summary="Execute {kind} entry-point {entry}"
             ),
             KindSpec(
                 name="native-binary",
                 description="Natively-compiled standalone binary (built into dist/)",
                 `entry="main",
                 action="build",
                 verb="native",
                 summary="Build native binary -> {output}",
                 output_dir="dist"
             ),
             KindSpec(
                 name="native-lib",
                 description="Natively-compiled shared library (.so / .dylib / .dll)",
                 `entry="main",
                 action="build",
                 verb="native",
                 summary="Build shared library (.so / .dylib / .dll)",
                 flags={"lib": True}
             ),
             KindSpec(
                 name="service",
                 description="Headless Jac API service (server walkers, no client)",
                 `entry="main",
                 action="serve",
                 verb="run",
                 summary="Serve headless API service",
                 flags={"no_client": True},
                 has_server=True
             ),
             KindSpec(
                 name="service-mesh",
                 description="Jac microservice (server walkers; colocates its service apps)",
                 `entry="main",
                 action="serve",
                 verb="run",
                 summary="Serve microservice consumer (colocates its service apps)",
                 has_server=True
             ),
             KindSpec(
                 name="py-package",
                 description="Distributable Python package (built into a wheel)",
                 `entry="lib",
                 action="build",
                 verb="build",
                 summary="Build PyPI wheel into dist/",
                 flags={"as": "wheel"},
                 needs_entry=False
             ),
             KindSpec(
                 name="js-package",
                 description="Distributable npm package (built into a tarball)",
                 `entry="lib",
                 action="build",
                 verb="build",
                 summary="Build npm package into dist/",
                 flags={"as": "npm"},
                 needs_entry=False,
                 codespace="client",
                 ui="dom"
             ),
             KindSpec(
                 name="web-app",
                 description="Minimal full-stack Jac app (server walkers + client UI)",
                 `entry="main",
                 action="serve",
                 verb="run",
                 summary="Serve full-stack app with client (dev mode)",
                 flags={"dev": True},
                 ui="dom",
                 has_server=True
             ),
             KindSpec(
                 name="web-static",
                 description="Client-only Jac app (runs in the browser, no backend)",
                 `entry="main",
                 action="serve",
                 verb="run",
                 summary="Serve client-only app as a static page (no backend)",
                 ui="dom"
             ),
             KindSpec(
                 name="desktop",
                 description="Jac desktop app (OS webview + native build)",
                 `entry="main",
                 action="serve",
                 verb="run",
                 summary="Run desktop app (OS webview)",
                 ui="dom"
             ),
             KindSpec(
                 name="mobile",
                 description="Jac mobile app (mobUI over React Native)",
                 `entry="main",
                 action="build",
                 verb="build",
                 summary="Build mobile app bundle",
                 ui="mobui"
             )
         ]
     },
     VALID_KINDS: list[str] = list(KIND_SPECS.keys()),
     UI_DOM: str = "dom",
     UI_MOBUI: str = "mobui",
     MOBILE_PLATFORMS: list[str] = ["android", "ios", "web"];

def kind_spec(kind: str) -> KindSpec | None {
    return KIND_SPECS.get(kind);
}

def kind_entry(kind: str) -> str {
    spec = KIND_SPECS.get(kind);
    return spec.`entry if spec else "main";
}

def is_valid_kind(kind: str) -> bool {
    return kind in KIND_SPECS;
}

def kind_ui(kind: str) -> str {
    spec = KIND_SPECS.get(kind);
    return spec.ui if spec else "";
}

def kind_has_client(kind: str) -> bool {
    return bool(kind_ui(kind));
}

def kind_is_mobui(kind: str) -> bool {
    return kind_ui(kind) == UI_MOBUI;
}

def kind_codespace(kind: str) -> str {
    spec = KIND_SPECS.get(kind);
    return spec.codespace if spec else '';
}

def kind_has_server(kind: str) -> bool {
    spec = KIND_SPECS.get(kind);
    return spec.has_server if spec else kind == '';
}
