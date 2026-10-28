import os;
import re;
import from datetime { datetime, UTC, timedelta }
import from jaclang.cli.manifest_route { resolve_cli_version }

node ClawNode {
    def __jac_access__ -> AccessLevel;
}

edge ClawEdge: ClawNode --> ClawNode {
    def __jac_access__ -> AccessLevel;
}

node ClawHub(ClawNode) {
    has created_at: str = "",
        day: str = "",
        jobs_today: int = 0,
        last_sweep_at: str = "",
        swept_version: str = "",
        sweep_passed: int = 0,
        sweep_stale: int = 0,
        pr_state: str = "",
        pr_url: str = "",
        pr_note: str = "",
        pr_number: int = 0,
        pr_slug: str = "",
        pr_checked_at: str = "",
        applied_chore: str = "",
        chore_owner: str = "",
        chore_until: str = "";
}

node ClawJob(ClawNode) {
    has ask_key: str = "",
        tweet_id: str = "",
        asker: str = "",
        question: str = "",
        source: str = "",
        status: str = "queued",
        attempts: int = 0,
        removed: bool = False,
        applied_run: str = "",
        lease_owner: str = "",
        lease_until: str = "",
        outcome: str = "",
        reply: str = "",
        detail: str = "",
        tutorial_slug: str = "",
        links: list[LinkView] = [],
        consulted: list[str] = [],
        blocks: list[BlockView] = [],
        steps: list[StepView] = [],
        created_at: str = "",
        started_at: str = "",
        finished_at: str = "";
}

node ClawTutorial(ClawNode) {
    has slug: str = "",
        title: str = "",
        summary: str = "",
        body: str = "",
        status: str = "published",
        verified_version: str = "",
        blocks: list[BlockView] = [],
        answered: int = 0,
        askers: list[str] = [],
        job_id: str = "",
        created_at: str = "",
        pr_state: str = "",
        pr_url: str = "",
        checked_version: str = "";
}

node ClawGap(ClawNode) {
    has question: str = "",
        job_id: str = "",
        created_at: str = "";
}

edge HasClaw: Node --> ClawHub {
    def __jac_access__ -> AccessLevel;
}

edge HasJob(ClawEdge): ClawHub --> ClawJob {}

edge HasTutorial(ClawEdge): ClawHub --> ClawTutorial {}

edge HasGap(ClawEdge): ClawHub --> ClawGap {}

edge Answered(ClawEdge): ClawTutorial --> ClawJob {}

glob DAILY_JOBS: int = int(os.environ.get("NINJACLAW_DAILY_JOBS", "200") or 200),
     STALE_WORKING_S: float = 900.0,
     CHORE_LEASE_S: float = 7200.0,
     MAX_ATTEMPTS: int = 2,
     RECENT_LIMIT: int = 30,
     PR_POLL_S: float = 3600.0,
     JOB_RETENTION: int = int(
         os.environ.get("NINJACLAW_JOB_RETENTION", "1000") or 1000
     );

def find_hub -> ClawHub | None;

def claw_hub -> ClawHub;

def claw_gaps -> int;

def claw_jobs -> list[ClawJob];

def claw_tutorials -> list[ClawTutorial];

def tutorial_by_slug(slug: str) -> ClawTutorial | None;

def enqueue_asks(asks: list[AskInput]) -> list[str];

def next_queued -> ClawJob | None;

def take_budget -> bool;

def stamp_in(seconds: float) -> str;

def claim_job(job: ClawJob);

def renew_job(job_id: str);

def requeue_stale;

def claim_chore -> bool;

def renew_chore;

def release_chore;

def record_outcome(job: ClawJob, outcome: Outcome);

def slug_for(title: str) -> str;

def job_view(job: ClawJob, live: list[StepView] | None = None) -> JobView;

def tutorial_card(t: ClawTutorial) -> TutorialCard;

def replies_for(job_ids: list[str]) -> list[JobReply];

def forget_jobs(job_ids: list[str]) -> int;

def prune_jobs(keep: int) -> int;

def sweep_inputs -> list[tuple[str, str, str, str, str]];

def apply_sweep(
    results: dict[str, list[BlockView]],
    version: str,
    error: str,
    complete: bool = False
);

def promote_candidates -> list[PromoteCandidate];

def apply_pr(slug: str, result: PrResult);

def pr_checked_recently(hub: ClawHub) -> bool;

def pr_due -> bool;

def pr_cooling -> bool;

def apply_pr_state(state: str);
