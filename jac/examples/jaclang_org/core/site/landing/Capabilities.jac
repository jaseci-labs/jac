import from core.site.ui.card { Card, CardHeader, CardTitle, CardContent }
import from core.site.ui.carousel {
    Carousel,
    CarouselContent,
    CarouselItem,
    CarouselPrevious,
    CarouselNext,
    CarouselDots
}
import from .Reveal { Reveal }
import from .WhyJac { WhySlide }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    FlashIcon,
    SourceCodeIcon,
    SparklesIcon,
    DatabaseIcon,
    CloudServerIcon,
    CheckmarkCircle01Icon
}

glob _KINDS: list[dict] = [
         {"name": "Script / CLI tool", "cmd": "jac run app.jac"},
         {"name": "Zero-dependency native binary", "cmd": "jac build --as native"},
         {"name": "REST API + Swagger + auth", "cmd": "jac run --serve api.jac"},
         {"name": "Service apps, one workspace", "cmd": "jac run --serve --fleet"},
         {"name": "Full-stack web app", "cmd": "jac run"},
         {"name": "Desktop app (OS webview)", "cmd": "jac build  # desktop"},
         {"name": "Mobile app (Android / iOS)", "cmd": "jac build  # mobile"},
         {"name": "WebAssembly in the browser", "cmd": "jac build  # web-static"},
         {"name": "AI agents & LLM apps", "cmd": "def act -> Plan by llm();"},
         {"name": "Python package (PyPI wheel)", "cmd": "jac build --as wheel"},
         {"name": "npm package (+ .d.ts)", "cmd": "jac build --as npm"},
         {"name": "C-ABI shared library", "cmd": "jac build --native --lib"},

     ];

def:pub PillarCard(icon: any, title: str, body: str) -> JsxElement {
    return
        <Card
            className="h-full border-border/80 transition-all hover:-translate-y-1 hover:border-primary/40 hover:shadow-md"
        >
            <CardHeader>
                <div
                    className="mb-2 flex size-10 items-center justify-center rounded-lg bg-primary/10 text-primary"
                >
                    <HugeiconsIcon icon={icon} strokeWidth={2} className="size-5"/>
                </div>
                <CardTitle className="text-lg">{title}</CardTitle>
            </CardHeader>
            <CardContent>
                <p className="text-sm leading-relaxed text-muted-foreground">{body}</p>
            </CardContent>
        </Card>;
}

def:pub Capabilities -> JsxElement {
    return
        <section
            id="build"
            className="border-t border-border/60 bg-card/30 pt-16 pb-16 sm:pt-24 sm:pb-24"
        >
            <div
                className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
            >
                <Reveal>
                    <div className="relative">
                        <Carousel className="w-full" opts={{"loop": True}}>
                            <CarouselContent>
                                <CarouselItem>
                                    <WhySlide
                                        title="What you get"
                                        sub="The glue is gone. Everything else got simpler."
                                    >
                                        <div
                                            className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3"
                                        >
                                            <PillarCard
                                                icon={FlashIcon}
                                                title="One binary, your whole toolchain"
                                                body="One download replaces Python, Node, the C compilers, and every package manager."
                                            />
                                            <PillarCard
                                                icon={SourceCodeIcon}
                                                title="~5× less code"
                                                body="Endpoints, ORMs, serializers, and migrations are compiler-generated — never written."
                                            />
                                            <PillarCard
                                                icon={SparklesIcon}
                                                title="AI is a typed function call"
                                                body="The signature is the prompt. The return type is the enforced schema."
                                            />
                                            <PillarCard
                                                icon={DatabaseIcon}
                                                title="Persistence built in"
                                                body="Whatever root reaches, persists. No database, no ORM, no migrations."
                                            />
                                            <PillarCard
                                                icon={CloudServerIcon}
                                                title="Laptop to Kubernetes"
                                                body="jac scale deploy. No Dockerfile, no YAML, no changed code."
                                            />
                                            <PillarCard
                                                icon={CheckmarkCircle01Icon}
                                                title="One type checker, end to end"
                                                body="A cross-tier mistake is a compile error, not a 2 a.m. incident."
                                            />
                                        </div>
                                    </WhySlide>
                                </CarouselItem>
                                <CarouselItem>
                                    <WhySlide
                                        title="Build anything"
                                        sub="The deliverable is a build target, not an architecture decision"
                                    >
                                        <div
                                            className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
                                        >
                                            {for (i, k) in enumerate(_KINDS) {
                                                <div
                                                    key={str(i)}
                                                    className="group flex h-full min-w-0 flex-col gap-3 rounded-xl border border-border/80 bg-card/50 pt-5 pb-5 pl-5 pr-5 transition-all hover:-translate-y-0.5 hover:border-primary/40 hover:bg-card"
                                                >
                                                    <span
                                                        className="text-sm font-medium"
                                                    >
                                                        {k["name"]}
                                                    </span>
                                                    <code
                                                        className="mt-auto block truncate rounded-md bg-muted/60 pl-2.5 pr-2.5 pt-1.5 pb-1.5 font-mono text-xs text-primary"
                                                    >
                                                        {k["cmd"]}
                                                    </code>
                                                </div>
                                            }}
                                        </div>
                                        <p
                                            className="mt-8 text-center text-sm text-muted-foreground"
                                        >
                                            Proof in the repo: a playable chess engine as a standalone binary, a raylib shooter running as in-browser wasm, and JacYac — a full social app in{" "}
                                            <span
                                                className="font-medium text-foreground"
                                            >
                                                475 backend lines
                                            </span>{" "}
                                            with zero glue artifacts.
                                        </p>
                                    </WhySlide>
                                </CarouselItem>
                            </CarouselContent>
                            <CarouselPrevious className="left-3"/>
                            <CarouselNext className="right-3"/>
                            <CarouselDots className="mt-5"/>
                        </Carousel>
                    </div>
                </Reveal>
            </div>
        </section>;
}
