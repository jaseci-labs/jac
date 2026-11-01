impl Navbar -> JsxElement {
    theme = useTheme();
    dark = theme.dark;

    can with [dark] entry {
        document.documentElement.classList.toggle("dark", dark);
    }

    async can with entry {
        _ = await ensure_install();
    }

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
                    <DropdownMenu>
                        <DropdownMenuTrigger asChild={True}>
                            <button
                                className="inline-flex items-center gap-1 rounded-md pl-3 pr-2 pt-1.5 pb-1.5 text-sm text-muted-foreground transition-colors hover:bg-accent hover:text-foreground data-[state=open]:bg-accent data-[state=open]:text-foreground"
                            >
                                Explore
                                <HugeiconsIcon
                                    icon={ArrowDown01Icon}
                                    strokeWidth={2}
                                    className="size-3.5"
                                />
                            </button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end" className="w-64">
                            {for item in _EXPLORE {
                                <DropdownMenuItem key={item["to"]} asChild={True}>
                                    <Link
                                        to={item["to"]}
                                        className="flex flex-col items-start gap-0.5"
                                    >
                                        <span className="text-sm font-medium">
                                            {item["label"]}
                                        </span>
                                        <span className="text-xs text-muted-foreground">
                                            {item["note"]}
                                        </span>
                                    </Link>
                                </DropdownMenuItem>
                            }}
                        </DropdownMenuContent>
                    </DropdownMenu>
                    <Link
                        to="/jacyac"
                        className="rounded-md pl-3 pr-3 pt-1.5 pb-1.5 text-sm text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                    >
                        JacYac
                    </Link>
                    <Link
                        to="/docs/latest"
                        className="rounded-md pl-3 pr-3 pt-1.5 pb-1.5 text-sm text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                    >
                        Docs
                    </Link>
                    <button
                        onClick={lambda { theme.toggle(); }}
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
                    <Link
                        to="/jacyac"
                        className={cn(
                            buttonVariants().call(None, {"size": "sm"}),
                            "hidden sm:inline-flex"
                        )}
                    >
                        <img
                            src="/static/assets/jacyak-logo.svg"
                            alt=""
                            className="size-4"
                        />
                        Join JacYac
                    </Link>
                </div>
            </div>
        </header>;
}
