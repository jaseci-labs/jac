impl TutorialRow(card: TutorialCard) -> JsxElement {
    <Link
        to={"/jacyac/tutorials/" + card.slug}
        className="block border-b border-border px-4 py-3 transition-colors hover:bg-muted/30"
    >
        <div className="flex items-center gap-2">
            <span className="font-display font-bold text-foreground">{card.title}</span>
            {if card.status == "stale" {
                <Badge variant="outline">stale</Badge>
            }}
        </div>
        <p className="mt-0.5 line-clamp-2 text-sm text-foreground/80">
            <MDSpans text={card.summary}/>
        </p>
        <div className="mt-1 flex gap-3 text-xs text-muted-foreground">
            <span>{"verified on jac " + card.verified_version}</span>
            <span>{count_label(card.answered, "asker", "askers")}</span>
        </div>
    </Link>
}

impl TutorialDetail(view: TutorialView) -> JsxElement {
    card = view.card;
    <article className="p-4" id="lx-tutorial">
        <h2 className="font-display text-2xl font-extrabold">{card.title}</h2>
        <p className="mt-1 text-sm text-muted-foreground">
            <MDSpans text={card.summary}/>
        </p>
        <div
            className="mt-2 flex flex-wrap items-center gap-3 text-xs text-muted-foreground"
        >
            {if card.status == "stale" {
                <Badge variant="outline">stale: failed on the current jac</Badge>
            } else {
                <span className="inline-flex items-center gap-1 text-primary">
                    <ShieldCheck size={14}/>
                    {"verified on jac " + card.verified_version}
                </span>
            } }
            <span>{count_label(card.answered, "asker", "askers")}</span>
            {if view.job_id {
                <Link
                    to={"/jacyac/ninjaclaw/" + view.job_id}
                    className="text-primary hover:underline"
                >
                    how it was written
                </Link>
            }}
            {if view.pr_url {
                <a
                    href={view.pr_url}
                    target="_blank"
                    rel="noreferrer"
                    className="text-primary hover:underline"
                >
                    docs PR
                </a>
            }}
        </div>
        <div className="mt-4">
            <Markdown lines={view.body.split("\n")} skip_title={card.title}/>
        </div>
        {if view.blocks {
            <div className="mt-6 border-t border-border pt-4">
                <div className="text-xs font-semibold uppercase text-muted-foreground">
                    Verification
                </div>
                <ul className="mt-1 flex flex-col gap-1 text-sm">
                    {for b in view.blocks {
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
    </article>
}

impl TutorialsTab(model: ClawModel, focus: str) -> JsxElement {
    <div>
        {if model.error {
            <p className="border-b border-border p-4 text-sm text-destructive">
                {model.error}
            </p>
        }}
        {if focus {
            <div>
                <Link
                    to="/jacyac/tutorials"
                    className="flex items-center gap-1.5 border-b border-border px-4 py-2 text-sm text-muted-foreground hover:text-foreground"
                >
                    <ArrowLeft size={14}/>
                    All tutorials
                </Link>
                {if model.tutorial {
                    <TutorialDetail view={model.tutorial}/>
                } elif not model.loading {
                    <p className="p-4 text-sm text-muted-foreground">
                        No such tutorial.
                    </p>
                } }
            </div>
        } elif model.tutorials {
            <div id="lx-tutorials">
                {for t in model.tutorials {
                    <TutorialRow key={t.slug} card={t}/>
                }}
            </div>
        } elif not model.loading {
            <Empty className="py-16">
                <EmptyHeader>
                    <EmptyMedia variant="icon">
                        <BookOpen/>
                    </EmptyMedia>
                    <EmptyTitle>No tutorials yet</EmptyTitle>
                    <EmptyDescription>
                        Ask @ninjaclaw a Jac question. When nothing in the docs answers it, it writes a short tutorial, checks every example against the serving jac, and files it here.
                    </EmptyDescription>
                </EmptyHeader>
            </Empty>
        }  }
    </div>
}
