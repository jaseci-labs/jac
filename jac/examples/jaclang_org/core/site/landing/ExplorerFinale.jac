import from core.site.ui.badge { Badge }
import from core.site.ui.button { buttonVariants }
import from .Reveal { Reveal }
import from core.site.source.SourceBrowser { SourceBrowser }
import from .CopyCommand { CopyCommandBlock }
import from "@jac/runtime" { Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    GlobeIcon,
    SmartPhone01Icon,
    ComputerIcon,
    CommandLineIcon,
    UserGroupIcon,
    ChartHistogramIcon,
    StarIcon,
    Book02Icon,
    BookOpen01Icon,
    DiscordIcon
}

glob BOOK_URL: str = "https://doi.org/10.5281/zenodo.21464040",
     RUN_LINES: list[str] = ["jac create mysite --awesome", "cd mysite", "jac run"];

def:pub WorkspaceAppCard(icon: any, tag: str, title: str, body: str) -> JsxElement {
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
                            One Program. One codebase. Six distinct apps.
                        </h2>
                        <p className="mt-4 text-balance text-lg text-muted-foreground">
                            Explore the full workspace behind this site: four ways to use it and two services, all sharing the same Jac core.
                        </p>
                    </div>
                </Reveal>
                <Reveal delay={100}>
                    <div
                        className="mt-12 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3"
                    >
                        <WorkspaceAppCard
                            icon={GlobeIcon}
                            tag="web"
                            title="The website"
                            body="The site in front of you: live docs, the source explorer, JacYac, Ninja Scores, and the WebAssembly rocket arena."
                        />
                        <WorkspaceAppCard
                            icon={SmartPhone01Icon}
                            tag="mobile"
                            title="JacYac on your phone"
                            body="A mobUI app for the JacYac feed, profiles, channels, and Ninja Scores, built on the same social graph and scoring core."
                        />
                        <WorkspaceAppCard
                            icon={CommandLineIcon}
                            tag="cli"
                            title="The command line"
                            body="Score repositories, read and post to JacYac, and sync or inspect the docs graph from your terminal."
                        />
                        <WorkspaceAppCard
                            icon={ComputerIcon}
                            tag="desktop"
                            title="The desktop app"
                            body="The same site in an OS webview, connected to jaclang.org for its live backend."
                        />
                        <WorkspaceAppCard
                            icon={UserGroupIcon}
                            tag="social_graph"
                            title="The social service"
                            body="Profiles, follows, posts, comments, and channels live in a persistent graph, explored and updated by Jac walkers."
                        />
                        <WorkspaceAppCard
                            icon={ChartHistogramIcon}
                            tag="scoring"
                            title="The scoring service"
                            body="Analyze GitHub codebases, calculate Ninja Scores and belts, and add optional AI insights to the reports."
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
                        six apps · one shared core · all Jac
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
