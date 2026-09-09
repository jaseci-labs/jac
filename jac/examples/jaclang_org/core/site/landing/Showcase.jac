import from core.source.files { SourceView, example_sources }
import from core.site.ui.badge { Badge }
import from core.site.ui.tabs { Tabs, TabsList, TabsTrigger, TabsContent }
import from core.site.ui.CodeBlock { CodeBlock }
import from .Reveal { Reveal }
import from "@jac/runtime" { Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { CheckmarkCircle01Icon, ArrowUpRight01Icon }

glob _NATIVE_LINES: list[str] = [
         "obj Buffer { has n: int = 0; }",
         "",
         "with entry {",
         "    a: own Buffer = Buffer();   # opt in, one declaration",
         "    v: &Buffer = &a;            # shared borrow of the owner",
         "    a.n = 5;    # error[E1303]: cannot mutate while borrowed",
         "    print(v.n); # the borrow remains live through this use",
         "    b = a;      # moves the value out of 'a'",
         "    print(a);   # error[E1301]: use of 'a' after move",
         "}",
         "",
         "# jac build --as native  →  zero-RC machine code",

     ];

def:pub ShowcasePanel(
    lines: list[str],
    file: str,
    heading: str,
    blurb: str,
    points: list[str],
    link_label: str,
    link_href: str
) -> JsxElement {
    return
        <div className="grid grid-cols-1 items-start gap-8 lg:grid-cols-[1.15fr_1fr]">
            <CodeBlock lines={lines} title={file}/>
            <div className="pt-2">
                <h3 className="text-xl font-semibold tracking-tight">{heading}</h3>
                <p className="mt-3 text-base leading-relaxed text-muted-foreground">
                    {blurb}
                </p>
                <ul className="mt-6 flex flex-col gap-4">
                    {for (i, pt) in enumerate(points) {
                        <li key={str(i)} className="flex items-start gap-3">
                            <HugeiconsIcon
                                icon={CheckmarkCircle01Icon}
                                strokeWidth={2}
                                className="mt-0.5 size-4 shrink-0 text-primary"
                            />
                            <span
                                className="text-sm leading-relaxed text-muted-foreground"
                            >
                                {pt}
                            </span>
                        </li>
                    }}
                </ul>
                {if link_href.startswith("/") {
                    <Link
                        to={link_href}
                        className="mt-6 inline-flex items-center gap-1 text-sm font-medium text-primary hover:underline"
                    >
                        {link_label}
                        <HugeiconsIcon
                            icon={ArrowUpRight01Icon}
                            strokeWidth={2}
                            className="size-3.5"
                        />
                    </Link>
                } else {
                    <a
                        href={link_href}
                        target="_blank"
                        rel="noreferrer"
                        className="mt-6 inline-flex items-center gap-1 text-sm font-medium text-primary hover:underline"
                    >
                        {link_label}
                        <HugeiconsIcon
                            icon={ArrowUpRight01Icon}
                            strokeWidth={2}
                            className="size-3.5"
                        />
                    </a>
                } }
            </div>
        </div>;
}

def:pub Showcase -> JsxElement {
    has samples: list[SourceView] = [];

    async def load_samples -> None;

    def sample_lines(name: str) -> list[str] {
        want = "core/site/examples/" + name + ".jac";
        for v in samples {
            if v.path == want {
                return v.raw_lines;
            }
        }
        return [];
    }

    can with entry {
        _ = load_samples();
    }

    return
        <section id="language" className="pt-16 pb-16 sm:pt-24 sm:pb-24">
            <div
                className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
            >
                <Reveal>
                    <div className="mx-auto max-w-2xl text-center">
                        <Badge variant="outline" className="mb-4">The language</Badge>
                        <h2
                            className="text-balance text-3xl font-bold tracking-tight sm:text-4xl"
                        >
                            AI, graphs, and UIs are language features
                        </h2>
                        <p className="mt-4 text-balance text-lg text-muted-foreground">
                            Not frameworks you assemble around it. The things every real application needs are compiler-generated and type-checked.
                        </p>
                    </div>
                </Reveal>
                <Reveal delay={100}>
                    <div className="mt-12">
                        <Tabs defaultValue="ai">
                            <TabsList
                                className="mx-auto mb-8 flex h-auto w-fit max-w-full flex-wrap justify-center"
                            >
                                <TabsTrigger value="ai" className="pl-4 pr-4 pt-2 pb-2">
                                    AI · by llm()
                                </TabsTrigger>
                                <TabsTrigger
                                    value="graph"
                                    className="pl-4 pr-4 pt-2 pb-2"
                                >
                                    Graphs · walkers
                                </TabsTrigger>
                                <TabsTrigger
                                    value="full"
                                    className="pl-4 pr-4 pt-2 pb-2"
                                >
                                    Full-stack · one file
                                </TabsTrigger>
                                <TabsTrigger
                                    value="native"
                                    className="pl-4 pr-4 pt-2 pb-2"
                                >
                                    Native · own &amp; borrow
                                </TabsTrigger>
                            </TabsList>
                            <TabsContent value="ai">
                                <ShowcasePanel
                                    lines={sample_lines("ai_priority")}
                                    file="core/site/examples/ai_priority.jac"
                                    heading="There is no prompt to write."
                                    blurb="Delegate a function body to a model with two words."
                                    points={[
                                        "The compiler builds the prompt from your signature and sem annotations.",
                                        "The return type is the enforced output schema — typed values, never loose text.",
                                        "Any LiteLLM provider, or fully local weights. One line in jac.toml.",

                                    ]}
                                    link_label="Meaning-Typed Programming"
                                    link_href="/docs/latest/reference/plugins/byllm"
                                />
                            </TabsContent>
                            <TabsContent value="graph">
                                <ShowcasePanel
                                    lines={sample_lines("graph_api")}
                                    file="core/site/examples/graph_api.jac"
                                    heading="Your graph is your API."
                                    blurb="Nodes and edges are the data model. Walkers — mobile computation — are the endpoints."
                                    points={[
                                        "walker:pub is a REST endpoint: fields are the request body, report is the JSON response, Swagger included.",
                                        "Connecting a node is the write to the database — there is no other API.",
                                        "Every user is a graph root. Isolation is topology, not a WHERE clause.",

                                    ]}
                                    link_label="Object-Spatial Programming"
                                    link_href="/docs/latest/tutorials/language/osp"
                                />
                            </TabsContent>
                            <TabsContent value="full">
                                <ShowcasePanel
                                    lines={sample_lines("fullstack_todo")}
                                    file="core/site/examples/fullstack_todo.jac"
                                    heading="Frontend and backend in one file."
                                    blurb="The JSX component compiles to React, while the graph operations stay on the server."
                                    points={[
                                        "await get_todos() is a real RPC — HTTP call, serialization, and shared types, all generated.",
                                        "Rename a field: every stale use on either side is a compile error.",
                                        "jac run serves it. jac run --dev adds hot reload.",

                                    ]}
                                    link_label="Full-stack tutorial"
                                    link_href="/docs/latest/build/fullstack-web"
                                />
                            </TabsContent>
                            <TabsContent value="native">
                                <ShowcasePanel
                                    lines={_NATIVE_LINES}
                                    file="Ownership diagnostics · illustrative example"
                                    heading="Systems code, by degrees."
                                    blurb="Gradual borrow checking turns the managed-vs-systems divide into a gradient."
                                    points={[
                                        "Unannotated code stays fully managed. own and & opt in one declaration at a time.",
                                        "Full adoption: native artifacts with no refcounting and no garbage collector.",
                                        "The same source targets standalone binaries and in-browser wasm — no gcc, no emscripten.",

                                    ]}
                                    link_label="Gradual borrow checking"
                                    link_href="/docs/latest/reference/language/ownership-borrowing"
                                />
                            </TabsContent>
                        </Tabs>
                    </div>
                </Reveal>
            </div>
        </section>;
}
