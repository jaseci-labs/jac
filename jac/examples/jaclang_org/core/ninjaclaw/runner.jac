import os;
import time;
import socket;
import threading;
import from uuid { uuid4 }
import from pathlib { Path }
import from datetime { datetime, UTC }

obj JobSpec {
    has job_id: str = "",
        question: str = "",
        asker: str = "",
        source: str = "",
        repo_root: str = "",
        version: str = "",
        run_id: str = "";
}

obj TutorialDraft {
    has slug: str = "",
        title: str = "",
        summary: str = "",
        body: str = "",
        blocks: list[BlockView] = [];
}

obj Outcome {
    has status: str = "done",
        outcome: str = "",
        reply: str = "",
        detail: str = "",
        links: list[LinkView] = [],
        consulted: list[str] = [],
        blocks: list[BlockView] = [],
        steps: list[StepView] = [],
        tutorial: TutorialDraft | None = None,
        tutorial_slug: str = "";
}

obj RunResult {
    has run_id: str,
        job_id: str,
        outcome: Outcome;
}

obj Runner {
    has lock: threading.Lock = threading.Lock(),
        spec: JobSpec | None = None,
        steps: list[StepView] = [],
        done: list[RunResult] = [];

    def busy -> bool;
    def start(spec: JobSpec, catalog: list[IndexDoc], work: Callable) -> bool;
    def note(phase: str, text: str) -> None;
    def live -> tuple[JobSpec | None, list[StepView]];
    def pending -> list[RunResult];
    def ack(run_ids: list[str]) -> None;
}

glob MIN_CONFIDENCE: float = 0.6,
     MAX_REPAIRS: int = 2,
     JOB_LEASE_S: float = 7200.0,
     LEASE_MARGIN_S: float = 1200.0,
     CANDIDATES: int = 12,
     REPLY_LIMIT: int = 280,
     RUNNER: Runner = Runner(),
     WORKER_ID: str = socket.gethostname()
         + ":"
         + str(os.getpid())
         + ":"
         + uuid4().hex[:8];

def stamp -> str;

def fit(text: str, limit: int) -> str;

def job_path(job_id: str) -> str;

def link_reply(title: str, href: str, job_id: str) -> str;

def gap_reply(links: list[LinkView], job_id: str) -> str;

def generated_reply(job_id: str) -> str;

def step_fits(deadline: float, step_s: float) -> bool;

def write_verified(
    spec: JobSpec, note: Callable, deadline: float
) -> tuple[TutorialDraft | None, list[BlockView], str];

def _write_verified(
    spec: JobSpec, note: Callable, deadline: float
) -> tuple[TutorialDraft | None, list[BlockView], str];

def run_pipeline(spec: JobSpec, catalog: list[IndexDoc], note: Callable) -> Outcome;
