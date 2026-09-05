import from .button { buttonVariants }
import from core.utils { cn }
import from "@jac/runtime" { Link }
import from react { useEffect }
import from core.install { ensure_install }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    GithubIcon,
    Moon01Icon,
    Sun01Icon,
    DiscordIcon
}

def:pub Navbar -> JsxElement {
    has dark: bool = True;

    can with entry {
        dark = document.documentElement.classList.contains("dark");
    }

    async def freshen_installer {
        _ = await ensure_install();
    }

    useEffect(
        lambda {
            _ = freshen_installer();
            return lambda {};
        },
        []
    );

    def toggle_theme(_e: MouseEvent);

    return
        <header
            className="fixed inset-x-0 top-0 z-50 border-b border-border/60 bg-background/75 backdrop-blur-xl"
        >
            <div
                className="mx-auto flex h-16 max-w-7xl items-center gap-6 pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
            >
                <Link to="/" className="flex items-center gap-2.5">
                    <img
                        src="/static/assets/jac-logo.svg"
                        alt="Jac logo"
                        className="size-8"
                    />
                    <span className="text-lg font-bold tracking-tight">Jac</span>
                </Link>
                <div className="ml-auto flex items-center gap-2">
                    <Link
                        to="/wait-wuuut"
                        className="rounded-md pl-3 pr-3 pt-1.5 pb-1.5 text-sm text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                    >
                        Wait, Wuuut?!
                    </Link>
                    <Link
                        to="/leaderboard"
                        className="rounded-md pl-3 pr-3 pt-1.5 pb-1.5 text-sm text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                    >
                        Ninja Scores
                    </Link>
                    <Link
                        to="/socialize"
                        className="rounded-md pl-3 pr-3 pt-1.5 pb-1.5 text-sm text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                    >
                        Socialize
                    </Link>
                    <Link
                        to="/docs/latest"
                        className="rounded-md pl-3 pr-3 pt-1.5 pb-1.5 text-sm text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                    >
                        Docs
                    </Link>
                    <button
                        onClick={toggle_theme}
                        title="Toggle theme"
                        className={buttonVariants().call(
                            None, {"variant": "ghost", "size": "icon"}
                        )}
                    >
                        {if dark {
                            <HugeiconsIcon
                                icon={Sun01Icon}
                                strokeWidth={2}
                                className="size-4"
                            />
                        } else {
                            <HugeiconsIcon
                                icon={Moon01Icon}
                                strokeWidth={2}
                                className="size-4"
                            />
                        } }
                    </button>
                    <a
                        href="https://github.com/jaseci-labs/jac"
                        target="_blank"
                        rel="noreferrer"
                        title="GitHub"
                        className={buttonVariants().call(
                            None, {"variant": "ghost", "size": "icon"}
                        )}
                    >
                        <HugeiconsIcon
                            icon={GithubIcon}
                            strokeWidth={2}
                            className="size-4"
                        />
                    </a>
                    <a
                        href="https://discord.gg/6j3QNdtcN6"
                        target="_blank"
                        rel="noreferrer"
                        className={cn(
                            buttonVariants().call(None, {"size": "sm"}),
                            "hidden sm:inline-flex"
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
            </div>
        </header>;
}
