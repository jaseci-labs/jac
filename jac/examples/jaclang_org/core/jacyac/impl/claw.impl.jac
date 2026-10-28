impl useClaw(view: str, focus: str) -> ClawModel {
    has activity: Activity | None = None,
        job: JobView | None = None,
        tutorials: list[TutorialCard] = [],
        tutorial: TutorialView | None = None,
        loading: bool = False,
        error: str = "";
    latest = useRef("");

    async def refresh {
        asked = view + "|" + focus;
        latest.current = asked;
        try {
            if view == "ninjaclaw" {
                got_activity = await ninjaclaw_activity();
                got_job = await ninjaclaw_job(job_id=focus) if focus else None;
                if latest.current != asked {
                    return;
                }
                activity = got_activity;
                job = got_job;
            } elif view == "tutorials" {
                got_tutorial = await ninjaclaw_tutorial(slug=focus) if focus else None;
                got_tutorials = await ninjaclaw_tutorials();
                if latest.current != asked {
                    return;
                }
                tutorial = got_tutorial;
                tutorials = got_tutorials;
            }
            error = "";
        } except BridgeError {
            if latest.current == asked {
                error = "Can't reach ninjaclaw right now. Try again in a moment.";
            }
        } finally {
            if latest.current == asked {
                loading = False;
            }
        }
    }

    async can with (view, focus) entry {
        job = None;
        tutorial = None;
        if view == "ninjaclaw" or view == "tutorials" {
            loading = True;
            await refresh();
        }
    }

    useEffect(
        lambda {
            if view != "ninjaclaw" {
                return lambda {};
            }
            interval = setInterval(lambda { refresh(); }, CLAW_POLL_MS);
            return lambda { clearInterval(interval); };
        },
        [view, focus]
    );

    return ClawModel(
        activity=activity,
        job=job,
        tutorials=tutorials,
        tutorial=tutorial,
        loading=loading,
        error=error,
        refresh=refresh
    );
}
