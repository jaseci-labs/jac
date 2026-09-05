import from core.leaderboard.board { BoardEntry }
import from core.progress { JobProgress }
import from core.utils { cn }
import from core.leaderboard.format { belt_class, belt_label }
import from core.site.ui.badge { Badge }
import from core.site.ui.input { Input }
import from core.site.ui.button { Button }
import from "@jac/runtime" { Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Alert01Icon, ArrowRight01Icon, ChampionIcon }

def:pub ScoreReveal(
    repo: BoardEntry, shown_score: int, rank: int, total: int, note: str
) -> JsxElement {
    return
        <div
            className="anim-fade-up mt-5 rounded-2xl border border-primary/40 bg-primary/5 pt-5 pb-5 pl-6 pr-6"
        >
            <p
                className="font-mono text-[11px] uppercase tracking-widest text-muted-foreground"
            >
                {repo.full}
            </p>
            <p className="mt-1 text-5xl font-bold tabular-nums text-gradient">
                {str(shown_score)}
            </p>
            <p className="mt-2">
                <span
                    className={cn(
                        "rounded-full pl-2.5 pr-2.5 pt-1 pb-1 text-xs font-semibold",
                        belt_class(repo.belt)
                    )}
                >
                    {belt_label(repo.belt)}
                </span>
                <span className="ml-3 text-sm text-muted-foreground">
                    {"#" + str(rank) + " of " + str(total)}
                </span>
            </p>
            {if repo.scored_sha != "" {
                <p className="mt-3 font-mono text-[11px] text-muted-foreground">
                    {"scored at commit "}
                    <a
                        href={repo.permalink}
                        target="_blank"
                        rel="noreferrer"
                        className="text-primary hover:underline"
                    >
                        {"@" + repo.scored_sha[:7]}
                    </a>
                </p>
            }}
            {if note != "" {
                <p className="mt-3 text-xs text-muted-foreground">{note}</p>
            }}
        </div>;
}

def:pub BoardSubmit(
    url: str,
    submitting: bool,
    error: str,
    note: str,
    progress: JobProgress | None,
    reveal: BoardEntry | None,
    reveal_score: int,
    reveal_rank: int,
    total: int,
    onUrlChange: Callable[[any], None],
    onKeyDown: Callable[[any], None],
    onSubmit: Callable[[any], None]
) -> JsxElement {
    return
        <div className="mx-auto max-w-2xl text-center">
            <Badge variant="outline" className="mb-4">
                <HugeiconsIcon
                    icon={ChampionIcon}
                    strokeWidth={2}
                    className="size-3.5"
                />
                Ninja Leaderboard
            </Badge>
            <h1 className="text-balance text-4xl font-bold tracking-tight sm:text-5xl">
                How much{" "}
                <span className="text-gradient">ninja</span>{" "}
                is in your Jac?
            </h1>
            <p className="mt-4 text-balance text-muted-foreground">
                Drop any public GitHub repo. We download it, statically read the source (never run it), and score its Jac-ness — OSP, AI, codespaces, craft, and how much of the code is actually Jac — not just its stars.{" "}
                <Link to="/methodology" className="text-primary hover:underline">
                    How scoring works →
                </Link>
            </p>
            <div className="mt-7 flex flex-col gap-2 sm:flex-row">
                <Input
                    value={url}
                    onChange={onUrlChange}
                    onKeyDown={onKeyDown}
                    placeholder="github.com/you/your-jac-project"
                    className="h-11 flex-1 bg-card/60 font-mono text-sm"
                />
                <Button size="lg" onClick={onSubmit} disabled={submitting}>
                    {"Scoring…" if submitting else "Score my repo"}
                    <HugeiconsIcon
                        icon={ArrowRight01Icon}
                        strokeWidth={2}
                        className="size-4"
                    />
                </Button>
            </div>
            {if error != "" {
                <p
                    className="mt-3 flex items-center justify-center gap-2 text-sm text-destructive"
                >
                    <HugeiconsIcon
                        icon={Alert01Icon}
                        strokeWidth={2}
                        className="size-4"
                    />
                    {error}
                </p>
            }}
            {if submitting {
                <div
                    className="mt-4 rounded-xl border border-border/60 bg-card/50 pt-3 pb-3 pl-4 pr-4 text-left backdrop-blur-sm"
                >
                    <p
                        className="flex items-center gap-2 font-mono text-[11px] text-primary"
                    >
                        <span
                            className="size-3 animate-spin rounded-full border-2 border-primary border-t-transparent"
                        ></span>
                        {(progress.detail if progress else "") or "contacting github…"}
                    </p>
                </div>
            }}
            {if reveal {
                <ScoreReveal
                    repo={reveal}
                    shown_score={reveal_score}
                    rank={reveal_rank}
                    total={total}
                    note={note}
                />
            }}
        </div>;
}
