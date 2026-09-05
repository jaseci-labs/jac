import from core.site.ui.button { buttonVariants }
import from core.site.ui.badge { Badge }
import from core.utils { cn }
import from "@jac/runtime" { Link }
import from core.site.ui.GraphBackdrop { GraphBackdrop }
import from core.site.source.FloatingSource { FloatingSource }
import from .CopyCommand { CopyCommand }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { StarIcon, BookOpen01Icon }

glob INSTALL_CMD: str = "curl -fsSL https://jaclang.org/install.sh | bash";

def:pub Hero -> JsxElement {
    return
        <section
            id="top"
            className="relative overflow-hidden pt-36 pb-24 sm:pt-44 sm:pb-32"
        >
            <div className="hero-glow absolute inset-0"></div>
            <div className="dot-grid absolute inset-0"></div>
            <GraphBackdrop/>
            <div
                className="relative mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
            >
                <div
                    className="grid grid-cols-1 items-center gap-14 lg:gap-10 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] xl:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]"
                >
                    <div className="text-center lg:text-left">
                        <div className="anim-fade-up">
                            <Badge
                                variant="outline"
                                className="mb-6 border-primary/40 bg-primary/5 pl-3 pr-3 pt-1 pb-1 text-primary"
                            >
                                The first synechic + topokinetic programming language
                            </Badge>
                        </div>
                        <h1
                            className="anim-fade-up anim-d1 text-balance text-5xl font-bold tracking-tight sm:text-6xl lg:text-5xl xl:text-4xl"
                        >
                            One language.
                            <br/>
                            Every stack.
                            <br/>
                            <span className="text-gradient">No glue.</span>
                        </h1>
                        <p
                            className="anim-fade-up anim-d2 mx-auto mt-6 max-w-xl text-balance text-lg leading-8 text-muted-foreground lg:mx-0 xl:text-base xl:leading-7"
                        >
                            Jac is to Python/Typescript/Rust/Zig/C++/C, what C is to X86/Arm/RISC-V/MIPS. With C you don&apos;t code ASM, with Jac you don&apos;t code the Polyglot. Jac is{" "}
                            <span className="text-gradient font-medium">synechic</span>
                            .
                        </p>
                        <div
                            className="anim-fade-up anim-d3 mt-8 flex flex-col items-center gap-3 sm:flex-row sm:flex-wrap lg:items-start"
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
                                Read the docs
                            </Link>
                        </div>
                        <div
                            className="anim-fade-up anim-d4 mt-6 flex justify-center lg:justify-start"
                        >
                            <CopyCommand
                                command={INSTALL_CMD}
                                className="max-w-full sm:max-w-xl"
                            />
                        </div>
                        <p
                            className="anim-fade-up anim-d5 mt-4 text-sm text-muted-foreground"
                        >
                            One self-contained binary. No Python, Node, or C toolchain required.
                        </p>
                    </div>
                    <div className="anim-fade-up anim-d3 hidden min-w-0 lg:block">
                        <FloatingSource
                            closable={True}
                            initial_path="web/pages/index.jac"
                        />
                        <p
                            className="mt-3 text-center font-mono text-xs text-muted-foreground"
                        >
                            the actual codebase serving this page — click around · it follows you
                        </p>
                    </div>
                </div>
            </div>
        </section>;
}
