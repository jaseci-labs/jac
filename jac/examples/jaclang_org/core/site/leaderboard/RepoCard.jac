import from core.leaderboard.board { BoardEntry }
import from core.leaderboard.scoring { RepoFeatures }
import from core.utils { cn }
import from core.leaderboard.format { belt_class, belt_label, time_ago }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { GitForkIcon, StarIcon }

glob RANK_RING: dict[str, str] = {
         "1": "ring-2 ring-yellow-400/70",
         "2": "ring-2 ring-slate-300/50",
         "3": "ring-2 ring-amber-600/60"
     },
     RANK_PIP: dict[str, str] = {
         "1": "bg-yellow-400 text-yellow-950",
         "2": "bg-slate-300 text-slate-900",
         "3": "bg-amber-600 text-amber-50"
     };

def:pub AxisBar(label: str, val: int, mx: int) -> JsxElement {
    return
        <div className="flex items-center gap-2">
            <span
                className="w-20 shrink-0 font-mono text-[10px] uppercase tracking-wider text-muted-foreground"
            >
                {label}
            </span>
            <div className="h-1.5 min-w-0 flex-1 overflow-hidden rounded-full bg-muted">
                <div
                    className="h-full rounded-full bg-primary transition-all duration-700"
                    style={{"width": str(Math.round(val * 100 / mx)) + "%"}}
                ></div>
            </div>
            <span
                className="w-10 shrink-0 text-right font-mono text-[10px] text-muted-foreground"
            >
                {str(val)}/{str(mx)}
            </span>
        </div>;
}

def:pub FeatureChips(features: RepoFeatures) -> JsxElement {
    chips: list[str] = [];
    if features.osp {
        chips.append("OSP");
    }
    if features.ai {
        chips.append("AI");
    }
    if features.cl {
        chips.append("cl");
    }
    if features.sv {
        chips.append("sv");
    }
    if features.na {
        chips.append("na");
    }
    if features.tests {
        chips.append("tests");
    }
    return
        <div className="flex flex-wrap gap-1.5">
            {for (i, label) in enumerate(chips) {
                <span
                    key={str(i)}
                    className="rounded-full border border-primary/40 bg-primary/10 pl-2 pr-2 pt-0.5 pb-0.5 font-mono text-[10px] text-primary"
                >
                    {label}
                </span>
            }}
        </div>;
}

def:pub RepoCard(
    repo: BoardEntry, rank: int, onSelect: Callable[[MouseEvent], None]
) -> JsxElement {
    key = str(rank);
    return
        <div
            onClick={onSelect}
            title="Click for the full score breakdown"
            className={cn(
                "flex h-full cursor-pointer flex-col gap-4 rounded-2xl border border-border/70 bg-card/40 pt-5 pb-5 pl-5 pr-5 transition-all hover:-translate-y-1 hover:border-primary/40",
                RANK_RING.get(key) or ""
            )}
        >
            <div className="flex items-start gap-3">
                <span
                    className={cn(
                        "flex size-7 shrink-0 items-center justify-center rounded-full font-mono text-xs font-bold",
                        RANK_PIP.get(key) or "bg-muted text-muted-foreground"
                    )}
                >
                    {key}
                </span>
                <img
                    src={repo.avatar_url}
                    alt=""
                    className="size-11 shrink-0 rounded-xl border border-border/60"
                />
                <div className="min-w-0 flex-1">
                    <a
                        href={repo.html_url}
                        target="_blank"
                        rel="noreferrer"
                        onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                        className="block truncate text-sm font-semibold hover:text-primary"
                    >
                        {repo.name}
                    </a>
                    <p className="truncate text-xs text-muted-foreground">
                        {repo.owner}
                    </p>
                </div>
                <div className="text-right">
                    <p className="text-2xl font-bold tabular-nums text-gradient">
                        {str(repo.score)}
                    </p>
                    <span
                        className={cn(
                            "rounded-full pl-2 pr-2 pt-0.5 pb-0.5 text-[10px] font-semibold",
                            belt_class(repo.belt)
                        )}
                    >
                        {belt_label(repo.belt)}
                    </span>
                </div>
            </div>
            {if repo.description != "" {
                <p className="line-clamp-2 text-[13px] leading-5 text-muted-foreground">
                    {repo.description}
                </p>
            }}
            <div className="flex flex-col gap-1.5">
                <AxisBar label="substance" val={repo.breakdown.substance} mx={30}/>
                <AxisBar label="breadth" val={repo.breakdown.breadth} mx={30}/>
                <AxisBar label="craft" val={repo.breakdown.craft} mx={20}/>
                <AxisBar label="community" val={repo.breakdown.community} mx={20}/>
            </div>
            <FeatureChips features={repo.features}/>
            <div
                className="mt-auto flex items-center gap-4 border-t border-border/40 pt-3 font-mono text-[11px] text-muted-foreground"
            >
                <span className="flex items-center gap-1">
                    <HugeiconsIcon
                        icon={StarIcon}
                        strokeWidth={2}
                        className="size-3.5"
                    />
                    {str(repo.stars)}
                </span>
                <span className="flex items-center gap-1">
                    <HugeiconsIcon
                        icon={GitForkIcon}
                        strokeWidth={2}
                        className="size-3.5"
                    />
                    {str(repo.forks)}
                </span>
                <span>
                    {str(repo.jac_lines)}{" "}
                    jac lines
                    {if repo.jac_pct > 0 {
                        <span className="text-primary">
                            {" · " + str(repo.jac_pct) + "% Jac"}
                        </span>
                    }}
                </span>
                {if repo.scored_sha != "" {
                    <a
                        href={repo.permalink}
                        target="_blank"
                        rel="noreferrer"
                        onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                        title="The repo exactly as it was scored"
                        className="ml-auto truncate transition-colors hover:text-primary"
                    >
                        {"@" + repo.scored_sha[:7] + " · " + time_ago(repo.scored_at)}
                    </a>
                } else {
                    <span className="ml-auto">{time_ago(repo.scored_at)}</span>
                } }
            </div>
        </div>;
}
