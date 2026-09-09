import from core.site.ui.badge { Badge }
import from .Reveal { Reveal }
import from core.site.landing.diagrams.PolypilerDiagram { PolypilerDiagram }
import from "@jac/runtime" { Link }

glob _REPLACED: list[str] = [
         "python",
         "pyenv",
         "conda",
         "pip",
         "pipx",
         "uv",
         "poetry",
         "venv",
         "node",
         "npm",
         "npx",
         "yarn",
         "gcc",
         "clang",
         "ld",
         "lld",
         "make",
         "cmake",
         "emscripten",
         "docker",
         "kubectl",
         "helm",
         "mypy",
         "pyright",
         "tsc",
         "black",
         "ruff",
         "pytest",
         "jest",
         "flask",
         "fastapi",
         "express",
         "langchain",

     ];

def:pub OneBinary -> JsxElement {
    return
        <section
            className="border-y border-border/60 bg-card/30 pt-16 pb-16 sm:pt-24 sm:pb-24"
        >
            <div
                className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
            >
                <Reveal>
                    <div className="mx-auto max-w-2xl text-center">
                        <Badge variant="outline" className="mb-4">One binary</Badge>
                        <h2
                            className="text-balance text-3xl font-bold tracking-tight sm:text-4xl"
                        >
                            Delete your toolchain.
                        </h2>
                        <p className="mt-4 text-balance text-lg text-muted-foreground">
                            A{" "}
                            <strong className="text-foreground">polypiler</strong>
                            : its unit of compilation is the whole polyglot app, and its targets are ecosystems, not instruction sets.
                        </p>
                    </div>
                </Reveal>
                <Reveal delay={120}>
                    <div className="mx-auto mt-12 max-w-5xl">
                        <PolypilerDiagram/>
                    </div>
                </Reveal>
                <Reveal delay={100}>
                    <div
                        className="mx-auto mt-12 max-w-4xl rounded-2xl border border-border/80 bg-background/60 pt-7 pb-7 pl-7 pr-7"
                    >
                        <p
                            className="mb-4 text-center font-mono text-xs uppercase tracking-widest text-muted-foreground"
                        >
                            safe to uninstall
                        </p>
                        <div className="flex flex-wrap justify-center gap-2">
                            {for (i, tool) in enumerate(_REPLACED) {
                                <span
                                    key={str(i)}
                                    className="strike-chip rounded-full border border-border/70 bg-card/60 pl-3 pr-3 pt-1 pb-1 font-mono text-xs text-muted-foreground/70"
                                >
                                    {tool}
                                </span>
                            }}
                        </div>
                        <div
                            className="mt-6 flex items-center justify-center gap-3 border-t border-border/60 pt-6"
                        >
                            <img
                                src="/static/assets/jac-logo.svg"
                                alt=""
                                className="size-8"
                            />
                            <p className="text-sm text-muted-foreground">
                                <span className="font-mono font-semibold text-primary">
                                    jac
                                </span>{" "}
                                — the one thing left on your machine.{" "}
                                <Link
                                    to="/docs/latest/quick-guide/one-binary"
                                    className="font-medium text-primary hover:underline"
                                >
                                    The full story →
                                </Link>
                            </p>
                        </div>
                    </div>
                </Reveal>
            </div>
        </section>;
}
