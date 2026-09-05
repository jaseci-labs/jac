import from core.source.files { source_tree, source_file, SourceFile, SourceView }
import from core.site.ui.CodeBlock { CodeLines }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowRight01Icon, Folder01Icon }

glob _DOT_COLORS: dict = {
         "jac": "bg-orange-400",
         "toml": "bg-sky-400",
         "css": "bg-purple-400",
         "markdown": "bg-zinc-400",

     };

def _ancestors_of(d: str) -> list[str];

def _dir_paths(rows: list[dict]) -> list[str];

def _build_rows(tree: list[SourceFile]) -> list[dict];

def:pub SourceBrowser(
    className: str = "", initial_path: str = "web/main.jac"
) -> JsxElement {
    has tree: list[SourceFile] = [],
        rows: list[dict] = [],
        closed: list[str] = [],
        view: SourceView | None = None,
        busy: bool = False;

    async can with entry {
        fetched = await source_tree();
        tree = fetched;
        built = _build_rows(fetched);
        rows = built;
        home_dir = "/".join(initial_path.split("/")[:-1]);
        open_chain = _ancestors_of(home_dir);
        closed = [
            d
            for d in _dir_paths(built)
            if d not in open_chain
        ];
        view = await source_file(initial_path);
    }

    async def open_path(path: str);

    def toggle_dir(d: str);

    def is_visible(row: dict) -> bool;

    total_lines: int = 0;
    for f in tree {
        total_lines = total_lines + f.lines;
    }

    return
        <div
            className={"code-window flex h-full flex-col overflow-hidden rounded-xl text-left "
                + className}
        >
            <div
                className="code-titlebar flex shrink-0 items-center gap-2 pl-4 pr-4 pt-2.5 pb-2.5"
            >
                <span className="size-2.5 rounded-full bg-white/15"></span>
                <span className="size-2.5 rounded-full bg-white/15"></span>
                <span className="size-2.5 rounded-full bg-white/15"></span>
                <span className="ml-2 font-mono text-xs text-white/45">
                    jaclang.org — this site, serving itself, for real,{" "}
                    <a
                        href="https://github.com/jaseci-labs/jac/tree/main/jac/examples/jaclang_org"
                        target="_blank"
                        rel="noreferrer"
                        className="underline decoration-white/30 underline-offset-2 transition-colors hover:text-white/70"
                    >
                        see github
                    </a>
                </span>
                <span
                    className="ml-auto flex items-center gap-1.5 font-mono text-[10px] uppercase tracking-widest text-emerald-400"
                >
                    <span
                        className="size-1.5 animate-pulse rounded-full bg-emerald-400"
                    ></span>
                    live source
                </span>
            </div>
            <div className="flex min-h-0 flex-1">
                <aside
                    className="w-44 shrink-0 overflow-y-auto border-r border-white/5 pt-2 pb-2"
                >
                    {for (ri, row) in enumerate(rows) {
                        if is_visible(row) {
                            if row["kind"] == "dir" {
                                <button
                                    key={str(ri)}
                                    onClick={lambda { toggle_dir(row["path"] as str); }}
                                    className="flex w-full cursor-pointer items-center gap-1.5 pt-1 pb-1 pr-2 font-mono text-[11px] text-white/60 hover:bg-white/5 hover:text-white/90"
                                    style={{
                                        "paddingLeft": str(
                                            10 + (row["depth"] as int) * 12
                                        )
                                            + "px"
                                    }}
                                >
                                    <HugeiconsIcon
                                        icon={ArrowRight01Icon}
                                        strokeWidth={2}
                                        className={"size-3 shrink-0 text-white/35 transition-transform"
                                            + (
                                                ""
                                                    if row["path"] in closed
                                                    else " rotate-90"
                                            )}
                                    />
                                    <HugeiconsIcon
                                        icon={Folder01Icon}
                                        strokeWidth={2}
                                        className="size-3 shrink-0 text-orange-400/70"
                                    />
                                    <span className="truncate">{row["name"]}</span>
                                </button>
                            } else {
                                <button
                                    key={str(ri)}
                                    onClick={lambda { open_path(row["path"] as str); }}
                                    className={"flex w-full cursor-pointer items-center gap-1.5 pt-1 pb-1 pr-2 font-mono text-[11px] transition-colors hover:bg-white/5 "
                                        + (
                                            "bg-white/10 text-orange-300"
                                                if (view and view.path == row["path"])
                                                else "text-white/45 hover:text-white/85"
                                        )}
                                    style={{
                                        "paddingLeft": str(
                                            24 + (row["depth"] as int) * 12
                                        )
                                            + "px"
                                    }}
                                >
                                    <span
                                        className={"size-1.5 shrink-0 rounded-[2px] "
                                            + (
                                                (_DOT_COLORS[row["lang"]] as str)
                                                or "bg-zinc-500"
                                            )}
                                    ></span>
                                    <span className="truncate">{row["name"]}</span>
                                </button>
                            }
                        }
                    }}
                    {if len(rows) == 0 {
                        <p className="pl-3 pt-2 font-mono text-[11px] text-white/35">
                            reading tree
                            <span className="caret ml-1"></span>
                        </p>
                    }}
                </aside>
                <section className="flex min-w-0 flex-1 flex-col">
                    <div
                        className="flex h-8 shrink-0 items-center gap-2 border-b border-white/5 pl-3 pr-3"
                    >
                        {if view {
                            <span
                                className="truncate font-mono text-[11px] text-white/60"
                            >
                                {(view.path as str).replace("/", " / ")}
                            </span>
                            <span
                                className="ml-auto shrink-0 font-mono text-[10px] text-white/30"
                            >
                                {str(view.lines)}{" lines · "}{f"{(
                                    view.size_bytes as float
                                )
                                    / 1024:.1f}"}{" kB"}
                            </span>
                        } else {
                            <span className="font-mono text-[11px] text-white/35">
                                …
                            </span>
                        } }
                    </div>
                    <div
                        className={"min-h-0 flex-1 overflow-auto transition-opacity"
                            + (" opacity-40" if busy else "")}
                    >
                        {if view {
                            <div key={view.path} className="anim-fade-in pt-2 pb-4">
                                <CodeLines
                                    lines={view.raw_lines}
                                    lang={view.language}
                                    numbers={True}
                                />
                            </div>
                        } else {
                            <p className="pl-4 pt-4 font-mono text-xs text-white/35">
                                {"opening "}
                                {initial_path}
                                <span className="caret ml-1"></span>
                            </p>
                        } }
                    </div>
                </section>
            </div>
            <div
                className="flex shrink-0 items-center justify-between border-t border-white/5 pl-4 pr-4 pt-1.5 pb-1.5 font-mono text-[10px] text-white/35"
            >
                <span>
                    {str(len(tree))}{" files · "}{str(total_lines)}{" lines · 1 config · 0 glue artifacts"}
                </span>
                <span className="text-orange-400/80">$ jac run</span>
            </div>
        </div>;
}
