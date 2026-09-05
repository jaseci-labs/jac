import from core.site.ui.badge { Badge }
import from core.site.ui.button { buttonVariants }
import from .Reveal { Reveal }
import from core.site.source.SourceBrowser { SourceBrowser }
import from .CopyCommand { CopyCommandBlock }
import from "@jac/runtime" { Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    GlobeIcon,
    CloudServerIcon,
    CpuIcon,
    StarIcon,
    Book02Icon,
    BookOpen01Icon,
    DiscordIcon
}

glob BOOK_URL: str = "https://doi.org/10.5281/zenodo.21464040",
     RUN_LINES: list[str] = ["jac create mysite --awesome", "cd mysite", "jac run"];

def:pub CodespaceCard(icon: any, tag: str, title: str, body: str) -> JsxElement {
    return
        <div
            className="flex items-start gap-4 rounded-xl border border-border/70 bg-card/40 pt-5 pb-5 pl-5 pr-5"
        >
            <div
                className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary"
            >
                <HugeiconsIcon icon={icon} strokeWidth={2} className="size-5"/>
            </div>
            <div className="min-w-0">
                <p className="text-sm font-semibold">
                    <span
                        className="mr-2 rounded bg-muted pl-1.5 pr-1.5 pt-0.5 pb-0.5 font-mono text-xs text-primary"
                    >
                        {tag}
                    </span>
                    {title}
                </p>
                <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
                    {body}
                </p>
            </div>
        </div>;
}

def:pub ExplorerFinale -> JsxElement {
    return
        <section
            id="explorer"
            className="border-t border-border/60 pt-16 pb-24 sm:pt-24 sm:pb-32"
        >
            <div
                className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
            >
                <Reveal>
                    <div className="mx-auto max-w-2xl text-center">
                        <Badge variant="outline" className="mb-4">Full circle</Badge>
                        <h2
                            className="text-balance text-3xl font-bold tracking-tight sm:text-4xl"
                        >
                            You just watched this whole codebase run.
                        </h2>
                        <p className="mt-4 text-balance text-lg text-muted-foreground">
                            The explorer that followed you down the page holds the entire site — every layer of what you just used, in one program.
                        </p>
                    </div>
                </Reveal>
                <Reveal delay={100}>
                    <div className="mt-12 grid grid-cols-1 gap-4 lg:grid-cols-3">
                        <CodespaceCard
                            icon={GlobeIcon}
                            tag="cl"
                            title="JavaScript, in your browser"
                            body="This page — the carousels, the floating explorer, the docs reader — compiled from Jac to the React app running in front of you right now."
                        />
                        <CodespaceCard
                            icon={CloudServerIcon}
                            tag="sv"
                            title="Python bytecode, in the cloud"
                            body="The walkers serving the docs graph and this live source view — the backend you've been calling on every scroll."
                        />
                        <CodespaceCard
                            icon={CpuIcon}
                            tag="na"
                            title="Native code, via LLVM"
                            body="The rocket arena — machine code from the same backend Rust, Zig, C, C++, Swift & Mojo use, running here as WebAssembly."
                        />
                    </div>
                </Reveal>
                <Reveal delay={150}>
                    <div className="mt-10 h-[620px] w-full">
                        <SourceBrowser className="h-full"/>
                    </div>
                    <p
                        className="mt-4 text-center font-mono text-xs text-muted-foreground"
                    >
                        the whole thing · one program · zero glue
                    </p>
                    <div className="mx-auto mt-10 max-w-xl text-center">
                        <p className="text-balance text-muted-foreground">
                            This isn&apos;t a site you can only look at — everything above runs on{" "}
                            <span className="font-medium text-foreground">
                                your machine
                            </span>
                            , right now, in three commands:
                        </p>
                        <div className="mt-4 flex justify-center">
                            <CopyCommandBlock
                                lines={RUN_LINES}
                                className="w-full sm:w-auto sm:min-w-[26rem]"
                            />
                        </div>
                    </div>
                    <div
                        className="mt-8 flex flex-col items-center gap-3 sm:flex-row sm:flex-wrap sm:justify-center"
                    >
                        <a
                            href="https://github.com/jaseci-labs/jac"
                            target="_blank"
                            rel="noreferrer"
                            className={buttonVariants().call(None, {"size": "lg"})}
                        >
                            <HugeiconsIcon
                                icon={StarIcon}
                                strokeWidth={2}
                                className="size-4"
                            />
                            Star the repo
                        </a>
                        <a
                            href={BOOK_URL}
                            target="_blank"
                            rel="noreferrer"
                            className={buttonVariants().call(
                                None, {"variant": "outline", "size": "lg"}
                            )}
                        >
                            <HugeiconsIcon
                                icon={Book02Icon}
                                strokeWidth={2}
                                className="size-4"
                            />
                            Read the book
                        </a>
                        <Link
                            to="/docs/latest"
                            className={buttonVariants().call(
                                None, {"variant": "outline", "size": "lg"}
                            )}
                        >
                            <HugeiconsIcon
                                icon={BookOpen01Icon}
                                strokeWidth={2}
                                className="size-4"
                            />
                            See the docs
                        </Link>
                        <a
                            href="https://discord.gg/6j3QNdtcN6"
                            target="_blank"
                            rel="noreferrer"
                            className={buttonVariants().call(
                                None, {"variant": "outline", "size": "lg"}
                            )}
                        >
                            <HugeiconsIcon
                                icon={DiscordIcon}
                                strokeWidth={2}
                                className="size-4"
                            />
                            Join the Discord
                        </a>
                    </div>
                </Reveal>
            </div>
        </section>;
}
