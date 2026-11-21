import logging;
import os;
import from stdjac { JobFailed, jobj }
import from datetime { datetime, UTC }

comptime REPO_TICK_S: float = 60.0,
         WORK_TICK_S: float = 5.0,
         UPKEEP_TICK_S: float = 60.0;

glob SWEEP_BATCH: int = 5,
     QUEUE_LIMIT: int = 20,
     _CATALOG: dict[str, list[IndexDoc]] = {},
     log: logging.Logger = logging.getLogger("knowledge");

@schedule(interval=REPO_TICK_S)
def:priv knowledge_repo_tick;

glob _repo_job: list[Job[str]] = [];

"""Clone or update the jac repo, as a job: it's minutes of git on a first run."""
@job
def refresh_repo(version: str, note: JobNote) -> str;

def:pub knowledge_status -> RepoStatus;

def ninjaclaw_enabled -> tuple[bool, str];

def docs_catalog -> list[IndexDoc];

def tutorial_catalog -> list[IndexDoc];

def public_view(job: ClawJob, live: list[StepView] | None = None) -> JobView;

@schedule(interval=WORK_TICK_S)
def:priv ninjaclaw_work_tick;

@schedule(interval=UPKEEP_TICK_S)
def:priv ninjaclaw_upkeep_tick;

def finish_chore;

def start_sweep(version: str) -> bool;

def start_promotion;

async def ninjaclaw_submit(asks: list[AskInput]) -> list[str];

async def ninjaclaw_results(job_ids: list[str]) -> list[JobReply];

async def ninjaclaw_forget(job_ids: list[str]) -> int;

async def ninjaclaw_retained(job_ids: list[str]) -> list[str];

def:pub ninjaclaw_activity -> Activity;

def:pub ninjaclaw_job(job_id: str) -> JobView | None;

def:pub ninjaclaw_tutorials -> list[TutorialCard];

def:pub ninjaclaw_tutorial(slug: str) -> TutorialView | None;
