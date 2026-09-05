import from "@jac/runtime" { Outlet, useLocation }
import from core.site.ui.Navbar { Navbar }
import from core.site.ui.Footer { Footer }

def init_theme {
    saved = localStorage.getItem("jac-theme");
    if saved == "light" {
        document.documentElement.classList.remove("dark");
    } else {
        document.documentElement.classList.add("dark");
    }
}

def:pub layout -> JsxLayout {
    init_theme();
    location = useLocation();
    in_app = location.pathname.startswith("/socialize");
    return
        <div
            className="min-h-screen overflow-x-clip bg-background text-foreground antialiased"
        >
            <Navbar/>
            <main>
                <Outlet/>
            </main>
            {if not in_app {
                <Footer/>
            }}
        </div>;
}
