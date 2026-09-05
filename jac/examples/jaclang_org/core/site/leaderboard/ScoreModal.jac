import from core.leaderboard.board { BoardEntry }
import from core.leaderboard.scoring { ScorePart }
import from core.utils { cn }
import from core.leaderboard.format { belt_class, belt_label, time_ago }
import from "@jac/runtime" { Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Cancel01Icon, GitForkIcon, StarIcon }

glob CAT_ORDER: list[list[str]] = [
         ["substance", "Substance", "30"],
         ["breadth", "Breadth", "30"],
         ["craft", "Craft", "20"],
         ["community", "Community", "20"]
     ];

def cat_score(repo: BoardEntry, key: str) -> int {
    if key == "substance" {
        return repo.breakdown.substance;
    }
    if key == "breadth" {
        return repo.breakdown.breadth;
    }
    if key == "craft" {
        return repo.breakdown.craft;
    }
    return repo.breakdown.community;
}

def:pub PartRow(p: ScorePart) -> JsxElement {
    earned = p.pts > 0.0;
    return
        <div className="flex items-start gap-3">
            <div className="w-44 shrink-0 pt-0.5">
                <p
                    className={cn(
                        "text-xs font-medium",
                        "" if earned else "text-muted-foreground/60"
                    )}
                >
                    {p.label}
                </p>
            </div>
            <div className="min-w-0 flex-1 pt-1">
                <div className="h-1.5 overflow-hidden rounded-full bg-muted">
                    <div
                        className={cn(
                            "h-full rounded-full",
                            "bg-primary" if earned else "bg-transparent"
                        )}
                        style={{
                            "width": str(Math.round(p.pts * 100 / Math.max(p.max, 1)))
                                + "%"
                        }}
                    ></div>
                </div>
                <p className="mt-1 text-[11px] leading-4 text-muted-foreground">
                    {p.note}
                </p>
            </div>
            <span
                className={cn(
                    "w-14 shrink-0 pt-0.5 text-right font-mono text-xs tabular-nums",
                    "text-foreground" if earned else "text-muted-foreground/60"
                )}
            >
                {str(p.pts) + "/" + str(int(p.max))}
            </span>
        </div>;
}

def:pub ScoreModal(
    repo: BoardEntry, rank: int, onClose: Callable[[MouseEvent], None]
) -> JsxElement {
    parts: list[ScorePart] = repo.breakdown.details or [];
    return
        <div
            onClick={onClose}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 pl-4 pr-4 backdrop-blur-sm"
        >
            <div
                onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                className="anim-fade-up max-h-[85vh] w-full max-w-2xl overflow-y-auto rounded-2xl border border-border/70 bg-card pt-6 pb-6 pl-6 pr-6 shadow-2xl"
            >
                <div className="flex items-start gap-3">
                    <img
                        src={repo.avatar_url}
                        alt=""
                        className="size-12 shrink-0 rounded-xl border border-border/60"
                    />
                    <div className="min-w-0 flex-1">
                        <a
                            href={repo.html_url}
                            target="_blank"
                            rel="noreferrer"
                            className="block truncate text-base font-semibold hover:text-primary"
                        >
                            {repo.full}
                        </a>
                        {if repo.description != "" {
                            <p className="mt-0.5 text-xs text-muted-foreground">
                                {repo.description}
                            </p>
                        }}
                        <p className="mt-1.5 flex flex-wrap items-center gap-2">
                            <span
                                className={cn(
                                    "rounded-full pl-2 pr-2 pt-0.5 pb-0.5 text-[10px] font-semibold",
                                    belt_class(repo.belt)
                                )}
                            >
                                {belt_label(repo.belt)}
                            </span>
                            <span
                                className="font-mono text-[11px] text-muted-foreground"
                            >
                                {"rank #" + str(rank)}
                            </span>
                            {if repo.jac_pct > 0 {
                                <span className="font-mono text-[11px] text-primary">
                                    {str(repo.jac_pct) + "% Jac"}
                                </span>
                            }}
                            <span
                                className="flex items-center gap-1 font-mono text-[11px] text-muted-foreground"
                            >
                                <HugeiconsIcon
                                    icon={StarIcon}
                                    strokeWidth={2}
                                    className="size-3"
                                />
                                {str(repo.stars)}
                            </span>
                            <span
                                className="flex items-center gap-1 font-mono text-[11px] text-muted-foreground"
                            >
                                <HugeiconsIcon
                                    icon={GitForkIcon}
                                    strokeWidth={2}
                                    className="size-3"
                                />
                                {str(repo.forks)}
                            </span>
                        </p>
                    </div>
                    <p
                        className="shrink-0 text-4xl font-bold tabular-nums text-gradient"
                    >
                        {str(repo.score)}
                    </p>
                    <button
                        onClick={onClose}
                        className="shrink-0 cursor-pointer rounded-lg border border-border/60 pt-1.5 pb-1.5 pl-1.5 pr-1.5 text-muted-foreground transition-colors hover:border-primary/40 hover:text-foreground"
                    >
                        <HugeiconsIcon
                            icon={Cancel01Icon}
                            strokeWidth={2}
                            className="size-4"
                        />
                    </button>
                </div>
                {if len(parts) == 0 {
                    <p
                        className="mt-6 rounded-xl border border-dashed border-border/70 pt-4 pb-4 pl-4 pr-4 text-center text-xs text-muted-foreground"
                    >
                        This repo was scored under an older rubric — resubmit it (rescores unlock every 6 hours) to see the point-by-point breakdown.
                    </p>
                } else {
                    <div className="mt-5 flex flex-col gap-5">
                        {for cat in CAT_ORDER {
                            <div key={cat[0]}>
                                <div
                                    className="mb-2 flex items-baseline justify-between border-b border-border/40 pb-1.5"
                                >
                                    <h3
                                        className="font-mono text-[11px] uppercase tracking-widest text-muted-foreground"
                                    >
                                        {cat[1]}
                                    </h3>
                                    <span className="font-mono text-xs tabular-nums">
                                        {str(cat_score(repo, cat[0])) + "/" + cat[2]}
                                    </span>
                                </div>
                                <div className="flex flex-col gap-2.5">
                                    {for (i, p) in enumerate(
                                        [
                                            q
                                            for q in parts
                                            if q.category == cat[0]
                                        ]
                                    ) {
                                        <PartRow key={str(i)} p={p}/>
                                    }}
                                </div>
                            </div>
                        }}
                    </div>
                } }
                <div
                    className="mt-6 flex flex-wrap items-center gap-3 border-t border-border/40 pt-3 font-mono text-[11px] text-muted-foreground"
                >
                    {if repo.scored_sha != "" {
                        <a
                            href={repo.permalink}
                            target="_blank"
                            rel="noreferrer"
                            className="hover:text-primary"
                        >
                            {"scored @" + repo.scored_sha[:7]}
                        </a>
                    }}
                    {if repo.scored_by_pid > 0 {
                        <span
                            title="The scorer is its own Jac service app; this is the process that scored this repo."
                        >
                            {"by scorer service pid " + str(repo.scored_by_pid)}
                        </span>
                    }}
                    <span>{time_ago(repo.scored_at)}</span>
                    <Link
                        to="/methodology"
                        className="ml-auto text-primary hover:underline"
                    >
                        How scoring works →
                    </Link>
                </div>
            </div>
        </div>;
}
