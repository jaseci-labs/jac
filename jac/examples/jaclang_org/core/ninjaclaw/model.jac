obj AskInput {
    has ask_key: str = "",
        tweet_id: str = "",
        asker: str = "",
        question: str = "",
        source: str = "mention",
        asked_at: str = "";
}

obj JobReply {
    has job_id: str = "",
        ask_key: str = "",
        tweet_id: str = "",
        status: str = "",
        reply: str = "";
}

obj StepView {
    has at: str = "",
        phase: str = "",
        text: str = "";
}

obj LinkView {
    has title: str = "",
        href: str = "";
}

obj BlockView {
    has index: int = 0,
        mode: str = "",
        ok: bool = False,
        detail: str = "";
}

obj JobView {
    has job_id: str = "",
        asker: str = "",
        question: str = "",
        source: str = "",
        status: str = "",
        outcome: str = "",
        reply: str = "",
        detail: str = "",
        tutorial_slug: str = "",
        links: list[LinkView] = [],
        consulted: list[str] = [],
        blocks: list[BlockView] = [],
        steps: list[StepView] = [],
        created_at: str = "",
        finished_at: str = "";
}

obj TutorialCard {
    has slug: str = "",
        title: str = "",
        summary: str = "",
        status: str = "",
        verified_version: str = "",
        answered: int = 0,
        created_at: str = "";
}

obj TutorialView {
    has card: TutorialCard = TutorialCard(),
        body: str = "",
        blocks: list[BlockView] = [],
        job_id: str = "",
        pr_url: str = "";
}

obj UpkeepView {
    has last_sweep_at: str = "",
        swept_version: str = "",
        passed: int = 0,
        stale: int = 0,
        pr_state: str = "",
        pr_url: str = "",
        pr_note: str = "",
        running: str = "";
}

obj Activity {
    has enabled: bool = False,
        state: str = "",
        detail: str = "",
        repo_phase: str = "",
        serving_version: str = "",
        current: JobView | None = None,
        queue: list[JobView] = [],
        recent: list[JobView] = [],
        upkeep: UpkeepView = UpkeepView(),
        tutorials: int = 0,
        gaps: int = 0;
}
