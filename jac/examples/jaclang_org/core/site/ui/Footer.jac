import from "@jac/runtime" { Link }

glob _COLS: list[dict] = [
         {
             "title": "Language",
             "links": [
                 {"label": "Documentation", "href": "/docs/latest"},
                 {"label": "Playground", "href": "https://playground.jaseci.org"},
                 {
                     "label": "First-app tutorial",
                     "href": "/docs/latest/tutorials/first-app/build-ai-day-planner"
                 },
                 {"label": "Install guide", "href": "/docs/latest/quick-guide/install"},

             ],

         },
         {
             "title": "Community",
             "links": [
                 {"label": "GitHub", "href": "https://github.com/jaseci-labs/jac"},
                 {"label": "Discord", "href": "https://discord.gg/6j3QNdtcN6"},
                 {
                     "label": "Contributing",
                     "href": "/docs/latest/community/contributing"
                 },
                 {
                     "label": "This is Jac (demo)",
                     "href": "https://github.com/jaseci-labs/this_is_jac"
                 },

             ],

         },
         {
             "title": "Research",
             "links": [
                 {
                     "label": "Object-Spatial Programming",
                     "href": "https://arxiv.org/abs/2503.15812"
                 },
                 {
                     "label": "Meaning-Typed Programming",
                     "href": "https://arxiv.org/abs/2405.08965"
                 },
                 {
                     "label": "The ninja book",
                     "href": "https://doi.org/10.5281/zenodo.21464040"
                 },
                 {
                     "label": "Research & papers",
                     "href": "/docs/latest/community/research"
                 },

             ],

         },

     ];

def:pub Footer -> JsxElement {
    return
        <footer className="border-t border-border/60 bg-card/40">
            <div
                className="mx-auto max-w-7xl pl-4 pr-4 pt-14 pb-10 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
            >
                <div
                    className="grid grid-cols-1 gap-10 lg:grid-cols-[1.4fr_1fr_1fr_1fr]"
                >
                    <div>
                        <div className="flex items-center gap-2.5">
                            <img
                                src="/static/assets/jac-logo.svg"
                                alt="Jac logo"
                                className="size-8"
                            />
                            <span className="text-lg font-bold tracking-tight">
                                Jac
                            </span>
                        </div>
                        <p
                            className="mt-4 max-w-xs text-sm leading-relaxed text-muted-foreground"
                        >
                            One language, one compiler, the whole stack. No glue.
                        </p>
                        <p className="mt-4 text-xs text-muted-foreground">
                            This site is a Jac program — built end to end in Jac.
                        </p>
                    </div>
                    {for (ci, col) in enumerate(_COLS) {
                        <div key={str(ci)}>
                            <p className="mb-4 text-sm font-semibold">{col["title"]}</p>
                            <ul className="flex flex-col gap-2.5">
                                {for (li, lk) in enumerate(
                                    col["links"] as list[dict]
                                ) {
                                    <li key={str(li)}>
                                        {if (lk["href"] as str).startswith("/") {
                                            <Link
                                                to={lk["href"]}
                                                className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                                            >
                                                {lk["label"]}
                                            </Link>
                                        } else {
                                            <a
                                                href={lk["href"]}
                                                target="_blank"
                                                rel="noreferrer"
                                                className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                                            >
                                                {lk["label"]}
                                            </a>
                                        } }
                                    </li>
                                }}
                            </ul>
                        </div>
                    }}
                </div>
                <div
                    className="mt-12 flex flex-col items-center justify-between gap-4 border-t border-border/60 pt-8 sm:flex-row"
                >
                    <p className="text-xs text-muted-foreground">
                        © 2026 Jaseci Labs. MIT licensed. A member of the NVIDIA Inception Program.
                    </p>
                    <p className="font-mono text-xs text-muted-foreground">
                        {"root ++> you;"}
                    </p>
                </div>
            </div>
        </footer>;
}
