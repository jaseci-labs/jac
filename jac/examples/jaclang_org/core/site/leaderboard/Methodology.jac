import from core.site.ui.GraphBackdrop { GraphBackdrop }
import from core.leaderboard.format { belt_class, belt_label }
import from core.site.ui.badge { Badge }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ChampionIcon }

glob SUBSTANCE_ROWS: list[list[str]] = [
         [
             "Jac volume",
             "18",
             "Jac lines on a log scale — full marks near 50k lines, so a 500-line gem still registers"
         ],
         [
             "Jac share of the code",
             "12",
             "the percentage of the repo's programming-language bytes that are Jac. Markup, styles, shell, and config (.html/.css/.sh/.json/...) don't count as code, and vendored dirs (node_modules, .venv, dist, ...) never dilute the share — a thin Jac wrapper around a Python codebase can't pass as substance"
         ]
     ],
     BREADTH_ROWS: list[list[str]] = [
         [
             "Object-spatial programming",
             "7",
             "walker / node / edge declarations, spawn, ++> connect ops"
         ],
         ["AI integration", "6", "delegating work with `by llm`"],
         ["Client codespace", "5", "JSX components: JsxElement / JsxPage returns"],
         [
             "Server codespace",
             "4",
             ".sv.jac files, sv blocks, walker:pub / def:pub endpoints"
         ],
         ["Native codespace", "4", ".na.jac files, na blocks or na imports"],
         ["Tests", "3", "test blocks"],
         ["Multi-codespace bonus", "3", "using two or more of cl / sv / na together"]
     ],
     CRAFT_ROWS: list[list[str]] = [
         [
             "README",
             "2 + 3",
             "2 for having one, up to 3 more scaling with length (full near 60 lines)"
         ],
         ["jac.toml", "4", "packaged as a Jac project"],
         ["License", "3", "LICENSE / LICENSE.md / LICENSE.txt"],
         ["CI", "3", "any workflow under .github/workflows/"],
         ["docs/", "2", "a docs directory"],
         ["Recent upkeep", "3 / 2 / 1", "last push within 30 / 90 / 365 days"]
     ],
     COMMUNITY_ROWS: list[list[str]] = [
         ["Stars", "12", "log scale, full marks near 1,000 stars"],
         ["Forks", "5", "log scale, full marks near 200 forks"],
         ["Topics", "3", "at least one GitHub topic is set"]
     ],
     BELT_STEPS: list[list[str]] = [
         ["white", "0"],
         ["yellow", "20"],
         ["orange", "35"],
         ["green", "50"],
         ["brown", "65"],
         ["black", "80"]
     ];

def:pub RubricTable(cols: list[str], rows: list[list[str]]) -> JsxElement {
    return
        <table className="mt-3 w-full border-collapse text-sm">
            <thead>
                <tr className="border-b border-border/70">
                    <th
                        className="pb-2 text-left font-mono text-[10px] uppercase tracking-widest text-muted-foreground"
                    >
                        {cols[0]}
                    </th>
                    <th
                        className="w-16 pb-2 text-right font-mono text-[10px] uppercase tracking-widest text-muted-foreground"
                    >
                        {cols[1]}
                    </th>
                    <th
                        className="hidden pb-2 pl-4 text-left font-mono text-[10px] uppercase tracking-widest text-muted-foreground sm:table-cell"
                    >
                        {cols[2]}
                    </th>
                </tr>
            </thead>
            <tbody>
                {for row in rows {
                    <tr key={row[0]} className="border-b border-border/40">
                        <td className="pt-2.5 pb-2.5 pr-3 align-top font-medium">
                            {row[0]}
                        </td>
                        <td
                            className="pt-2.5 pb-2.5 text-right align-top font-mono tabular-nums text-primary"
                        >
                            {row[1]}
                        </td>
                        <td
                            className="hidden pt-2.5 pb-2.5 pl-4 align-top text-[13px] leading-5 text-muted-foreground sm:table-cell"
                        >
                            {row[2]}
                        </td>
                    </tr>
                }}
            </tbody>
        </table>;
}

def:pub Section(title: str, total: str, blurb: str) -> JsxElement {
    return
        <div className="mt-10 flex items-baseline gap-3">
            <h2 className="text-xl font-semibold">{title}</h2>
            <span className="font-mono text-sm text-primary">{total}</span>
            <span className="hidden text-sm text-muted-foreground sm:inline">
                {blurb}
            </span>
        </div>;
}

def:pub Methodology -> JsxElement {
    return
        <section className="relative overflow-hidden py-8">
            <div className="hero-glow absolute inset-0"></div>
            <GraphBackdrop/>
            <div className="relative mx-auto max-w-3xl pl-4 pr-4 sm:pl-6 sm:pr-6">
                <Badge variant="outline" className="mb-4">
                    <HugeiconsIcon
                        icon={ChampionIcon}
                        strokeWidth={2}
                        className="size-3.5"
                    />
                    Ninja Scores
                </Badge>
                <h2 className="text-balance text-2xl font-bold tracking-tight">
                    How the{" "}
                    <span className="text-gradient">score</span>{" "}
                    is earned
                </h2>
                <p className="mt-4 text-muted-foreground">
                    Four categories, 100 points. Every repo is downloaded at a pinned commit and statically read — the code is never executed. Substance and breadth measure the Jac itself, craft measures project hygiene, and community is the one place popularity counts — capped at a fifth of the total, so code always outweighs clout.{" "}
                </p>
                <Section
                    title="Substance"
                    total="30 pts"
                    blurb="how much of the repo is really Jac"
                />
                <RubricTable
                    cols={["Signal", "Max", "How it scales"]}
                    rows={SUBSTANCE_ROWS}
                />
                <Section
                    title="Breadth"
                    total="30 pts"
                    blurb="how much of the language it exercises (capped at 30)"
                />
                <RubricTable
                    cols={["Signal", "Pts", "Detected by"]}
                    rows={BREADTH_ROWS}
                />
                <Section
                    title="Craft"
                    total="20 pts"
                    blurb="project hygiene the author controls"
                />
                <RubricTable cols={["Signal", "Pts", "Earned by"]} rows={CRAFT_ROWS}/>
                <Section
                    title="Community"
                    total="20 pts"
                    blurb="the only place popularity counts"
                />
                <RubricTable
                    cols={["Signal", "Max", "How it scales"]}
                    rows={COMMUNITY_ROWS}
                />
                <Section title="Belts" total="" blurb=""/>
                <div className="mt-3 flex flex-wrap items-center gap-2.5">
                    {for (i, step) in enumerate(BELT_STEPS) {
                        <span key={step[0]} className="flex items-center gap-2.5">
                            {if i > 0 {
                                <span
                                    className="font-mono text-xs text-muted-foreground"
                                >
                                    {step[1] + " →"}
                                </span>
                            }}
                            <span
                                className={"rounded-full pl-2.5 pr-2.5 pt-0.5 pb-0.5 text-xs font-semibold "
                                    + belt_class(step[0])}
                            >
                                {belt_label(step[0])}
                            </span>
                        </span>
                    }}
                </div>
                <p
                    className="mt-10 border-t border-border/40 pt-4 text-[13px] leading-6 text-muted-foreground"
                >
                    Fine print: analysis reads the default branch pinned to its head commit, so every score links to the exact tree it measured. Repos rescore at most once every 6 hours. Downloads are capped at 50 MB per repo and only the relevant slice of each archive is extracted. Click any card on the board for its point-by-point breakdown. Scoring itself is its own app: this workspace's jac.toml declares the scorer as a service app rooted at{" "}
                    <code>core/scoring_service.jac</code>
                    , and the site's server consumes it through one plain import — no HTTP client code anywhere. It shares the server's process during development and runs as its own process in the fleet; each card's breakdown names the process that scored it.
                </p>
            </div>
        </section>;
}
