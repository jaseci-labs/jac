import from "@jac/runtime" { Outlet, useLocation }

def init_theme;

def:pub SiteShell -> JsxElement;

impl init_theme {
    saved = localStorage.getItem("jac-theme");
    if saved == "light" {
        document.documentElement.classList.remove("dark");
    } else {
        document.documentElement.classList.add("dark");
    }
}
