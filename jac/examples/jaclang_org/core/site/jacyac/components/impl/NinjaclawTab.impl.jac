impl clock_of(stamp: str) -> str {
    return stamp[11:16] + " UTC" if len(stamp) >= 16 else "";
}

impl question_of(job: JobView) -> str {
    return job.question or "(" + (job.detail or "not shown") + ")";
}

impl ClawHeader(model: ClawModel) -> JsxElement {
    a = model.activity;
    state = a.state if a else "warming";
    <div className="border-b border-border p-4" id="lx-claw-header">
        <div className="flex items-start gap-3">
            <div
                className="flex size-11 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary"
            >
                <Bot size={22}/>
            </div>
            <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                    <span className="font-display text-lg font-bold">ninjaclaw</span>
                    <Badge
                        variant={"default"
                            if state in ["idle", "working"]
                            else "secondary"}
                        id="lx-claw-state"
                    >
                        {STATE_TEXT.get(state, state)}
                    </Badge>
                </div>
                <p className="mt-1 text-sm text-muted-foreground">
                    Mention @ninjaclaw in a post or a reply, or post in #help, and it answers Jac questions with a tutorial or the docs. Off-topic posts are ignored. Everything it does shows up here.
                </p>
                {if a and a.detail {
                    <p
                        className="mt-1 text-sm text-muted-foreground"
                        id="lx-claw-detail"
                    >
                        {a.detail}
                    </p>
                }}
                {if a {
                    <div
                        className="mt-2 flex flex-wrap gap-4 text-xs text-muted-foreground"
                    >
                        <span>{"jac " + a.serving_version}</span>
                        <span>{"repo " + (a.repo_phase or "idle")}</span>
                        <Link
                            to="/jacyac/tutorials"
                            className="text-primary hover:underline"
                        >
                            {str(a.tutorials) + " tutorials"}
                        </Link>
                        <span>{str(a.gaps) + " docs gaps"}</span>
                    </div>
                }}
            </div>
        </div>
    </div>
}

impl OutcomeBadge(job: JobView) -> JsxElement {
    if job.status == "working" {
        return
            <Badge variant="secondary" className="gap-1">
                <LoaderCircle size={12} className="animate-spin"/>
                working
            </Badge>;
    }
    if job.status == "queued" {
        return
            <Badge variant="outline" className="gap-1">
                <Hourglass size={12}/>
                queued
            </Badge>;
    }
    label = OUTCOME_LABELS.get(job.outcome, job.outcome or job.status);
    if job.outcome in ["ignored", "throttled", "removed"] {
        return
            <Badge variant="outline" className="gap-1 text-muted-foreground">
                <CircleSlash size={12}/>
                {label}
            </Badge>;
    }
    if job.status == "failed" or job.outcome == "gap" {
        return
            <Badge variant="outline" className="gap-1">
                <CircleAlert size={12}/>
                {label}
            </Badge>;
    }
    return
        <Badge className="gap-1">
            <CircleCheck size={12}/>
            {label}
        </Badge>;
}

impl StepList(steps: list[StepView]) -> JsxElement {
    <ol className="mt-3 flex flex-col gap-1.5 border-l border-border pl-3">
        {for (i, st) in enumerate(steps) {
            <li key={str(i)} className="text-sm">
                <span className="mr-2 font-mono text-xs text-muted-foreground">
                    {clock_of(st.at)}
                </span>
                <span className="mr-2 text-xs font-semibold uppercase text-primary">
                    {st.phase}
                </span>
                <span className="text-foreground/90">{st.text}</span>
            </li>
        }}
    </ol>
}

impl JobRow(job: JobView) -> JsxElement {
    <Link
        to={"/jacyac/ninjaclaw/" + job.job_id}
        className="block border-b border-border px-4 py-3 transition-colors hover:bg-muted/30"
    >
        <div className="flex items-center gap-2">
            <OutcomeBadge job={job}/>
            <span className="text-xs text-muted-foreground">
                {"@"
                    + handle_of(job.asker)
                    + " · "
                    + job.source
                    + " · "
                    + clock_of(job.created_at)}
            </span>
        </div>
        <p className="mt-1 line-clamp-2 text-sm text-foreground">{question_of(job)}</p>
    </Link>
}

impl JobDetail(job: JobView) -> JsxElement {
    <div className="p-4" id="lx-claw-job">
        <div className="flex flex-wrap items-center gap-2">
            <OutcomeBadge job={job}/>
            <span className="text-xs text-muted-foreground">
                {"asked by @"
                    + handle_of(job.asker)
                    + " via "
                    + job.source
                    + " at "
                    + clock_of(job.created_at)}
            </span>
        </div>
        <p className="mt-3 whitespace-pre-wrap text-[0.95rem] text-foreground">
            {question_of(job)}
        </p>
        {if job.reply {
            <div className="mt-4 rounded-xl bg-muted px-4 py-3 text-sm">
                <div className="mb-1 text-xs font-semibold text-muted-foreground">
                    ninjaclaw replied
                </div>
                <RichText text={job.reply}/>
            </div>
        }}
        {if job.detail {
            <p className="mt-3 text-sm text-muted-foreground">{job.detail}</p>
        }}
        {if job.tutorial_slug {
            <Link
                to={"/jacyac/tutorials/" + job.tutorial_slug}
                className="mt-3 inline-flex items-center gap-1.5 text-sm text-primary hover:underline"
            >
                <BookOpen size={14}/>
                Open the tutorial
            </Link>
        }}
        {if job.consulted {
            <div className="mt-4">
                <div className="text-xs font-semibold uppercase text-muted-foreground">
                    Consulted
                </div>
                <ul className="mt-1 list-disc pl-5 text-sm text-foreground/90">
                    {for (i, c) in enumerate(job.consulted) {
                        <li key={str(i)}>{c}</li>
                    }}
                </ul>
            </div>
        }}
        {if job.blocks {
            <div className="mt-4">
                <div className="text-xs font-semibold uppercase text-muted-foreground">
                    Verification
                </div>
                <ul className="mt-1 flex flex-col gap-1 text-sm">
                    {for b in job.blocks {
                        <li key={str(b.index)} className="flex items-start gap-2">
                            {if b.ok {
                                <CircleCheck
                                    size={14}
                                    className="mt-0.5 shrink-0 text-primary"
                                />
                            } else {
                                <CircleAlert
                                    size={14}
                                    className="mt-0.5 shrink-0 text-destructive"
                                />
                            } }
                            <span>
                                {"block "
                                    + str(b.index + 1)
                                    + " · "
                                    + b.mode
                                    + (": " + b.detail if b.detail else "")}
                            </span>
                        </li>
                    }}
                </ul>
            </div>
        }}
        <div className="mt-4">
            <div className="text-xs font-semibold uppercase text-muted-foreground">
                Steps
            </div>
            <StepList steps={job.steps}/>
        </div>
    </div>
}

impl NinjaclawTab(model: ClawModel, focus: str) -> JsxElement {
    a = model.activity;
    <div>
        <ClawHeader {model}/>
        {if model.error {
            <p className="border-b border-border p-4 text-sm text-destructive">
                {model.error}
            </p>
        }}
        {if focus {
            <div>
                <Link
                    to="/jacyac/ninjaclaw"
                    className="flex items-center gap-1.5 border-b border-border px-4 py-2 text-sm text-muted-foreground hover:text-foreground"
                >
                    <ArrowLeft size={14}/>
                    All activity
                </Link>
                {if model.job {
                    <JobDetail job={model.job}/>
                } elif not model.loading {
                    <p className="p-4 text-sm text-muted-foreground">No such job.</p>
                } }
            </div>
        } elif a {
            <div>
                <section id="lx-claw-now">
                    <h3
                        className="px-4 pt-4 text-xs font-semibold uppercase text-muted-foreground"
                    >
                        Now
                    </h3>
                    {if a.current {
                        <div className="border-b border-border px-4 pb-4">
                            <Link
                                to={"/jacyac/ninjaclaw/" + a.current.job_id}
                                className="mt-2 block text-sm font-medium text-foreground hover:underline"
                            >
                                {a.current.question}
                            </Link>
                            <StepList steps={a.current.steps}/>
                        </div>
                    } else {
                        <p
                            className="border-b border-border px-4 pt-1 pb-4 text-sm text-muted-foreground"
                        >
                            Nothing in progress.
                        </p>
                    } }
                </section>
                {if a.queue {
                    <section id="lx-claw-queue">
                        <h3
                            className="px-4 pt-4 text-xs font-semibold uppercase text-muted-foreground"
                        >
                            {"Queue · " + str(len(a.queue))}
                        </h3>
                        {for j in a.queue {
                            <JobRow key={j.job_id} job={j}/>
                        }}
                    </section>
                }}
                <section id="lx-claw-recent">
                    <h3
                        className="px-4 pt-4 text-xs font-semibold uppercase text-muted-foreground"
                    >
                        Recent
                    </h3>
                    {if a.recent {
                        for j in a.recent {
                            <JobRow key={j.job_id} job={j}/>
                        }
                    } else {
                        <p className="px-4 pt-1 pb-4 text-sm text-muted-foreground">
                            No questions yet. Mention @ninjaclaw in a post to ask one.
                        </p>
                    } }
                </section>
                <section id="lx-claw-upkeep" className="border-t border-border p-4">
                    <h3
                        className="text-xs font-semibold uppercase text-muted-foreground"
                    >
                        Upkeep
                    </h3>
                    <p className="mt-1 text-sm text-muted-foreground">
                        {(
                            "Last re-verification "
                            + clock_of(a.upkeep.last_sweep_at)
                            + " on jac "
                            + a.upkeep.swept_version
                            + ": "
                            + str(a.upkeep.passed)
                            + " passed, "
                            + str(a.upkeep.stale)
                            + " stale."
                        )
                            if a.upkeep.last_sweep_at
                            else "No re-verification has run yet."}
                    </p>
                    {if a.upkeep.running {
                        <p
                            className="mt-1 flex items-center gap-1.5 text-sm text-foreground"
                            id="lx-claw-sweep"
                        >
                            <LoaderCircle size={12} className="animate-spin"/>
                            {a.upkeep.running}
                        </p>
                    }}
                    {if a.upkeep.pr_state {
                        <p className="mt-1 text-sm text-muted-foreground">
                            {"Docs PR: "
                                + a.upkeep.pr_state
                                + (
                                    " · " + a.upkeep.pr_note if a.upkeep.pr_note else ""
                                )}
                            {if a.upkeep.pr_url {
                                <a
                                    href={a.upkeep.pr_url}
                                    target="_blank"
                                    rel="noreferrer"
                                    className="ml-1 text-primary hover:underline"
                                >
                                    {a.upkeep.pr_url}
                                </a>
                            }}
                        </p>
                    }}
                </section>
            </div>
        } else {
            <div className="flex justify-center py-16">
                <div
                    className="size-8 animate-spin rounded-full border-2 border-primary border-t-transparent"
                />
            </div>
        }  }
    </div>
}
