import from "@jac/runtime" { useLocation }

def:pub PackagesShell -> JsxElement {
    has catalog: PackageCatalog | None = None,
        detail: PackageDetail | None = None,
        loading: bool = True,
        q: str = "";

    loc = useLocation();
    parts = [
        p
        for p in (loc.pathname as str).split("/")
        if p
    ];
    name: str = (parts[1] + "/" + parts[2]) if len(parts) >= 3 else "";
    version: str = (parts[3] if len(parts) >= 4 else "") as str;

    async def load(want_name: str, want_version: str) {
        loading = True;
        if want_name {
            detail = await package_detail(name=want_name, version=want_version);
        } elif catalog is None {
            catalog = await package_catalog();
        }
        loading = False;
    }

    def handle_filter(e: ChangeEvent) {
        q = e.target.value;
    }

    can with [loc.pathname] entry {
        load(name, version);
    }

    return
        <div
            className="mx-auto max-w-5xl pl-4 pr-4 pt-24 pb-16 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
        >
            {if name {
                <PackagePage
                    name={name}
                    detail={detail if detail and not loading else None}
                    loading={loading}
                />
            } else {
                <PackagesIndex
                    catalog={catalog}
                    loading={loading}
                    q={q}
                    onFilter={handle_filter}
                />
            } }
        </div>;
}
