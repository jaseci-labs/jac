import from core.leaderboard.board {
    BoardEntry,
    BoardStatus,
    BoardView,
    SubmitResult,
    board_status,
    leaderboard,
    submit_repo
}
import from core.progress { JobProgress }
import from core.leaderboard.scoring { RepoFeatures, ScoreBreakdown }
import from core.utils { cn }
import from core.site.ui.skeleton { Skeleton }
import from core.site.ui.GraphBackdrop { GraphBackdrop }
import from .BoardSubmit { BoardSubmit }
import from .RepoCard { RepoCard }
import from .ScoreModal { ScoreModal }

glob POLL_MS: int = 400,
     POLL_TRIES: int = 200,
     WARMUP_TRIES: int = 8,
     COUNTUP_MS: int = 45,
     SORTS: list[list[str]] = [["score", "Top"], ["newest", "New"], ["stars", "Stars"]],
     ERRORS: dict[str, str] = {
         "bad_url": "That doesn't look like a GitHub repo — try github.com/owner/repo.",
         "not_found": "GitHub says that repo doesn't exist (or it's private).",
         "not_jac": "No .jac files found — the Ninja Leaderboard is for Jac projects.",
         "busy": "Another repo is being scored right now — try again in a few seconds.",
         "fetch_failed": "Couldn't download that repo (too big, or GitHub hiccuped).",
         "internal": "Scoring failed on our side — try again in a moment."
     },
     COOLDOWN_NOTE: str = "This repo was scored recently — showing its standing score (rescores unlock every 6 hours).";

def error_text(code: str) -> str {
    return ERRORS.get(code) or (ERRORS.get("internal") or "");
}

def:pub Leaderboard -> JsxElement {
    has entries: list[BoardEntry] = [],
        loading: bool = True,
        url: str = "",
        submitting: bool = False,
        progress: JobProgress | None = None,
        sub_error: str = "",
        sub_note: str = "",
        reveal: BoardEntry | None = None,
        reveal_score: int = 0,
        detail: BoardEntry | None = None,
        sort_by: str = "score";

    async def load -> None;

    async def poll_progress -> None;

    async def do_submit -> None;

    def start_countup(target: int) {
        reveal_score = 0;
        cur: any = 0;
        iv: any = None;
        iv = setInterval(
            lambda {
                cur = cur + Math.max(1, Math.round((target - cur) / 7));
                if cur >= target {
                    cur = target;
                    _ = clearInterval(iv);
                }
                reveal_score = cur as int;
            },
            COUNTUP_MS
        );
    }

    def handle_url(e: ChangeEvent) {
        url = e.target.value;
    }

    def handle_key(e: KeyboardEvent) {
        if e.key == "Enter" {
            _ = do_submit();
        }
    }

    def handle_submit(_e: MouseEvent) {
        _ = do_submit();
    }

    def rank_of(full: str) -> int {
        for i in range(len(entries)) {
            if entries[i].full == full {
                return i + 1;
            }
        }
        return 0;
    }

    def sorted_entries -> list[BoardEntry] {
        out = [e for e in entries];
        if sort_by == "newest" {
            out.sort(key=lambda (b: BoardEntry) { b.submitted_at; });
            out.reverse();
        } elif sort_by == "stars" {
            out.sort(key=lambda (b: BoardEntry) { -b.stars; });
        }
        return out;
    }

    can with entry {
        _ = load();
    }

    return
        <section className="relative overflow-hidden pt-28 pb-24">
            <div className="hero-glow absolute inset-0"></div>
            <GraphBackdrop/>
            <div
                className="relative mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
            >
                <BoardSubmit
                    url={url}
                    submitting={submitting}
                    error={sub_error}
                    note={sub_note}
                    progress={progress}
                    reveal={reveal}
                    reveal_score={reveal_score}
                    reveal_rank={rank_of(reveal.full) if reveal else 0}
                    total={len(entries)}
                    onUrlChange={handle_url}
                    onKeyDown={handle_key}
                    onSubmit={handle_submit}
                />
                <div className="mt-14 flex items-center gap-2">
                    <h2 className="text-lg font-semibold">The board</h2>
                    <span className="text-sm text-muted-foreground">
                        · {str(len(entries))}{" repo"
                            if len(entries) == 1
                            else " repos"}
                    </span>
                    <div
                        className="ml-auto flex gap-1 rounded-lg border border-border/60 bg-card/40 pt-0.5 pb-0.5 pl-1 pr-1"
                    >
                        {for (i, s) in enumerate(SORTS) {
                            <button
                                key={str(i)}
                                onClick={lambda (_e: MouseEvent) { sort_by = s[0]; }}
                                className={cn(
                                    "cursor-pointer rounded-md pl-2.5 pr-2.5 pt-1 pb-1 text-xs transition-colors",
                                    "bg-primary/15 font-medium text-primary"
                                        if sort_by == s[0]
                                        else "text-muted-foreground hover:text-foreground"
                                )}
                            >
                                {s[1]}
                            </button>
                        }}
                    </div>
                </div>
                {if loading {
                    <div
                        className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-3"
                    >
                        <Skeleton className="h-64 rounded-2xl"/>
                        <Skeleton className="h-64 rounded-2xl"/>
                        <Skeleton className="h-64 rounded-2xl"/>
                    </div>
                } elif len(entries) == 0 {
                    <div
                        className="mt-6 rounded-2xl border border-dashed border-border/70 pt-16 pb-16 text-center"
                    >
                        <p className="text-lg font-medium">
                            No repos on the board yet.
                        </p>
                        <p className="mt-1 text-sm text-muted-foreground">
                            Yours could be first — paste a GitHub URL above.
                        </p>
                    </div>
                } else {
                    <div
                        className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-3"
                    >
                        {for (i, e) in enumerate(sorted_entries()) {
                            <RepoCard
                                key={e.full}
                                repo={e}
                                rank={rank_of(e.full)}
                                onSelect={lambda (_ev: MouseEvent) { detail = e; }}
                            />
                        }}
                    </div>
                }  }
            </div>
            {if detail {
                <ScoreModal
                    repo={detail}
                    rank={rank_of(detail.full)}
                    onClose={lambda (_ev: MouseEvent) { detail = None; }}
                />
            }}
        </section>;
}
