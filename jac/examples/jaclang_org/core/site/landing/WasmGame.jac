import from core.site.ui.badge { Badge }
import from core.site.ui.button { Button }
import from .Reveal { Reveal }
import from react { useEffect }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { GameController01Icon, PlayIcon }

def:pub WasmGame -> JsxElement {
    has launched: bool = False,
        canvasRef: Ref[HTMLCanvasElement] = Ref(),
        stopRef: Ref[any] = Ref();

    def launch(_e: MouseEvent);

    useEffect(
        lambda { return lambda { if stopRef.current {
            stopRef.current();
            stopRef.current = None;
        }}; },
        []
    );

    return
        <section
            id="game"
            className="border-t border-border/60 bg-card/30 pt-16 pb-16 sm:pt-24 sm:pb-24"
        >
            <div
                className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
            >
                <Reveal>
                    <div className="mx-auto max-w-2xl text-center">
                        <Badge variant="outline" className="mb-4">LLVM Backend</Badge>
                        <h2
                            className="text-balance text-3xl font-bold tracking-tight sm:text-4xl"
                        >
                            This entire experience is one Jac program.
                        </h2>
                        <p className="mt-4 text-balance text-lg text-muted-foreground">
                            Frontend (codegen to JS in your browser), Backend (codegen to Python on the server), and this game (same codegen backend Rust, Zig, C &amp; C++ use). Jac is{" "}
                            <span className="text-gradient font-medium">synechic</span>
                            .
                        </p>
                    </div>
                </Reveal>
                <Reveal delay={120}>
                    <div className="mt-12 w-full">
                        <div className="code-window overflow-hidden rounded-xl">
                            <div
                                className="code-titlebar flex items-center gap-2 pl-4 pr-4 pt-2.5 pb-2.5"
                            >
                                <span
                                    className="size-2.5 rounded-full bg-white/15"
                                ></span>
                                <span
                                    className="size-2.5 rounded-full bg-white/15"
                                ></span>
                                <span
                                    className="size-2.5 rounded-full bg-white/15"
                                ></span>
                                <span className="ml-2 font-mono text-xs text-white/45">
                                    game/arena.jac → /static/arena.wasm
                                </span>
                                <span
                                    className="ml-auto font-mono text-[10px] uppercase tracking-widest text-orange-400/80"
                                >
                                    na → wasm
                                </span>
                            </div>
                            <div
                                className="relative w-full"
                                style={{"aspectRatio": "960 / 600"}}
                            >
                                <canvas
                                    ref={canvasRef}
                                    width={960}
                                    height={600}
                                    tabIndex={0}
                                    className="h-full w-full focus:outline-none"
                                    style={{"display": "block", "cursor": "crosshair"}}
                                />
                                <div
                                    className="pointer-events-none absolute left-4 top-3 font-mono text-sm text-white/80"
                                    style={{"textShadow": "0 1px 2px #000"}}
                                >
                                    hp{" "}
                                    <b id="game-hud-hp" className="text-primary">100</b>
                                    {" · "}
                                    kills{" "}
                                    <b id="game-hud-score" className="text-primary">
                                        0
                                    </b>
                                    {" · "}
                                    deaths{" "}
                                    <b id="game-hud-deaths" className="text-primary">
                                        0
                                    </b>
                                    {" · "}
                                    <b id="game-hud-fps" className="text-primary">
                                        0
                                    </b>{" "}
                                    fps
                                </div>
                                {if not launched {
                                    <div
                                        className="absolute inset-0 flex flex-col items-center justify-center gap-5 bg-[#060607]/95 backdrop-blur-sm"
                                    >
                                        <div
                                            className="flex size-16 items-center justify-center rounded-2xl bg-primary/15 text-primary"
                                        >
                                            <HugeiconsIcon
                                                icon={GameController01Icon}
                                                strokeWidth={2}
                                                className="size-8"
                                            />
                                        </div>
                                        <div className="text-center">
                                            <p className="text-lg font-bold text-white">
                                                Jac Rocket Arena
                                            </p>
                                            <p className="mt-1 text-sm text-white/50">
                                                The drones shoot back. Borrow-checked Jac with zero garbage collection, compiled to WebAssembly from{" "}
                                                <span className="font-mono">
                                                    game/arena.jac
                                                </span>
                                            </p>
                                        </div>
                                        <Button size="lg" onClick={launch}>
                                            <HugeiconsIcon
                                                icon={PlayIcon}
                                                strokeWidth={2}
                                                className="size-4"
                                            />
                                            Launch
                                        </Button>
                                    </div>
                                }}
                            </div>
                        </div>
                        <p className="mt-4 text-center text-sm text-muted-foreground">
                            Click the canvas to play and capture the mouse ·{" "}
                            <b className="text-foreground">WASD</b>{" "}
                            move · mouse / arrows aim ·{" "}
                            <b className="text-foreground">Space</b>{" "}
                            fire ·{" "}
                            <b className="text-foreground">Tab</b>{" "}
                            /{" "}
                            <b className="text-foreground">Esc</b>{" "}
                            release
                        </p>
                    </div>
                </Reveal>
            </div>
        </section>;
}
