import from "@jac/runtime" { Outlet, useLocation }

def:pub SiteShell -> JsxElement {
    location = useLocation();
    in_app = (
        location.pathname.startswith("/jacyac")
        or location.pathname.startswith("/socialize")
    );
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
