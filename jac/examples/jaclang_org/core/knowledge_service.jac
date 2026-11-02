import logging;
import os;
import from datetime { datetime, UTC }
import from jaclang.cli.manifest_route { resolve_cli_version }

obj ReleaseDocsInfo {
    has label: str = "",
        tag: str = "",
        version: str = "",
        fingerprint: str = "";
}

obj ReleaseLines {
    has ready: bool = False,
        serving_label: str = "",
        lines: list[ReleaseDocsInfo] = [];
}

glob REPO_TICK_S: float = 60.0,
     WORK_TICK_S: float = 5.0,
     UPKEEP_TICK_S: float = 60.0,
     SWEEP_BATCH: int = 5,
     QUEUE_LIMIT: int = 20,
     _BUNDLES: dict[str, DocBundle] = {},
     _CATALOG: dict[str, list[IndexDoc]] = {},
     log: logging.Logger = logging.getLogger("knowledge");

def release_bundle(line: ReleaseLine) -> DocBundle;

@schedule(trigger=ScheduleTrigger.STATIC, interval=REPO_TICK_S)
def:priv knowledge_repo_tick;

def:pub knowledge_status -> RepoStatus;

def:pub release_doc_lines -> ReleaseLines;

def:pub release_docs(tag: str) -> DocBundle | None;

def ninjaclaw_enabled -> tuple[bool, str];

def docs_catalog -> list[IndexDoc];

def tutorial_catalog -> list[IndexDoc];

def public_view(job: ClawJob, live: list[StepView] | None = None) -> JobView;

@schedule(trigger=ScheduleTrigger.STATIC, interval=WORK_TICK_S)
def:priv ninjaclaw_work_tick;

@schedule(trigger=ScheduleTrigger.STATIC, interval=UPKEEP_TICK_S)
def:priv ninjaclaw_upkeep_tick;

def finish_chore;

def start_sweep(version: str) -> bool;

def start_promotion;

def:pub ninjaclaw_submit(secret: str, asks: list[AskInput]) -> list[str];

def:pub ninjaclaw_results(secret: str, job_ids: list[str]) -> list[JobReply];

def:pub ninjaclaw_forget(secret: str, job_ids: list[str]) -> int;

def:pub ninjaclaw_retained(secret: str, job_ids: list[str]) -> list[str];

def:pub ninjaclaw_activity -> Activity;

def:pub ninjaclaw_job(job_id: str) -> JobView | None;

def:pub ninjaclaw_tutorials -> list[TutorialCard];

def:pub ninjaclaw_tutorial(slug: str) -> TutorialView | None;
