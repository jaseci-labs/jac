import from core.site.ui.badge { Badge }
import from core.site.ui.button { buttonVariants }
import from core.utils { cn }
import from .Reveal { Reveal }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowUpRight01Icon,
    Infinity01Icon,
    HierarchyIcon,
    CpuIcon,
    LockIcon,
    StarIcon
}

glob BOOK_URL: str = "https://doi.org/10.5281/zenodo.21464040";

def:pub ConceptCard(icon: any, name: str, line: str) -> JsxElement {
    return
        <div
            className="flex items-start gap-3 rounded-xl border border-border/70 bg-card/40 pt-4 pb-4 pl-4 pr-4"
        >
            <div
                className="flex size-9 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary"
            >
                <HugeiconsIcon icon={icon} strokeWidth={2} className="size-4"/>
            </div>
            <div className="min-w-0">
                <p className="text-sm font-semibold">{name}</p>
                <p className="mt-1 text-xs leading-relaxed text-muted-foreground">
                    {line}
                </p>
            </div>
        </div>;
}

def:pub BookSection -> JsxElement {
    return
        <section
            id="book"
            className="border-y border-border/60 bg-card/30 pt-16 pb-16 sm:pt-24 sm:pb-24"
        >
            <div
                className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
            >
                <div
                    className="grid grid-cols-1 items-center gap-12 lg:grid-cols-[minmax(0,2fr)_minmax(0,3fr)]"
                >
                    <Reveal>
                        <div className="relative mx-auto w-fit">
                            <div
                                className="absolute -inset-8 rounded-full bg-primary/15 blur-3xl"
                            ></div>
                            <a
                                href={BOOK_URL}
                                target="_blank"
                                rel="noreferrer"
                                className="relative block"
                            >
                                <img
                                    src="/static/assets/ninja-book-cover.svg"
                                    alt="Cover of A Synechic and Topokinetic Programming Language"
                                    className="w-60 -rotate-2 rounded-lg border border-border/60 shadow-2xl transition-transform hover:rotate-0 sm:w-72"
                                />
                            </a>
                            <p
                                className="relative mt-5 text-center font-mono text-xs text-muted-foreground"
                            >
                                “the ninja book” · latest edition
                            </p>
                        </div>
                    </Reveal>
                    <Reveal delay={120}>
                        <div>
                            <Badge variant="outline" className="mb-4">The book</Badge>
                            <p
                                className="text-balance text-2xl font-semibold leading-snug tracking-tight sm:text-3xl"
                            >
                                Anything derivable from the meaning of a program{" "}
                                <span className="text-gradient">
                                    should be derived
                                </span>{" "}
                                — by the compiler and runtime, not the developer.
                            </p>
                            <p
                                className="mt-5 text-base leading-relaxed text-muted-foreground"
                            >
                                <em>
                                    A Synechic and Topokinetic Programming Language
                                </em>{" "}
                                develops the theory beneath Jac — and introduces four concepts new to the field:
                            </p>
                            <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2">
                                <ConceptCard
                                    icon={Infinity01Icon}
                                    name="Synechic languages"
                                    line="One continuous, checked medium across runtimes, ecosystems, and toolchains."
                                />
                                <ConceptCard
                                    icon={HierarchyIcon}
                                    name="Topokinetic languages"
                                    line="The locus of computation is a first-class, mobile construct that travels through data."
                                />
                                <ConceptCard
                                    icon={CpuIcon}
                                    name="Polypilers"
                                    line="Compilers whose unit is the whole polyglot application — their targets are ecosystems, not instruction sets."
                                />
                                <ConceptCard
                                    icon={LockIcon}
                                    name="Gradual borrow checking"
                                    line="From fully managed semantics to zero-RC native artifacts, one declaration at a time."
                                />
                            </div>
                            <div
                                className="mt-7 flex flex-col gap-3 sm:flex-row sm:flex-wrap"
                            >
                                <a
                                    href={BOOK_URL}
                                    target="_blank"
                                    rel="noreferrer"
                                    className={buttonVariants().call(
                                        None, {"variant": "outline", "size": "lg"}
                                    )}
                                >
                                    Read the book — latest version
                                    <HugeiconsIcon
                                        icon={ArrowUpRight01Icon}
                                        strokeWidth={2}
                                        className="size-4"
                                    />
                                </a>
                                <a
                                    href="https://github.com/jaseci-labs/jac"
                                    target="_blank"
                                    rel="noreferrer"
                                    className={buttonVariants().call(
                                        None, {"size": "lg"}
                                    )}
                                >
                                    <HugeiconsIcon
                                        icon={StarIcon}
                                        strokeWidth={2}
                                        className="size-4"
                                    />
                                    Star the repo
                                </a>
                            </div>
                        </div>
                    </Reveal>
                </div>
            </div>
        </section>;
}
