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

impl stamp -> str {
    return datetime.now(UTC).replace(tzinfo=None).isoformat() + "Z";
}

impl fit(text: str, limit: int) -> str {
    return text if len(text) <= limit else text[:limit - 1].rstrip() + "…";
}

impl job_path(job_id: str) -> str {
    return "/jacyac/ninjaclaw/" + job_id;
}

impl link_reply(title: str, href: str, job_id: str) -> str {
    tail = " · how I found it: " + job_path(job_id);
    head = " covers this: " + href;
    room = REPLY_LIMIT - len(tail) - len(head);
    return fit(title, max(room, 12)) + head + tail;
}

impl gap_reply(links: list[LinkView], job_id: str) -> str {
    text = "I couldn't find a tutorial or docs page that answers this yet, so I logged it as a docs gap: "
        + job_path(job_id);
    for link in links {
        extra = " · closest: " + link.href;
        if len(text) + len(extra) <= REPLY_LIMIT {
            text = text + extra;
        }
    }
    return text;
}

impl generated_reply(job_id: str) -> str {
    return "I wrote a short tutorial for this, with every example checked on this jac: {tutorial} · how I wrote it: "
        + job_path(job_id);
}

impl step_fits(deadline: float, step_s: float) -> bool {
    return deadline - time.monotonic() >= step_s;
}

impl write_verified(
    spec: JobSpec, note: Callable, deadline: float
) -> tuple[TutorialDraft | None, list[BlockView], str] {
    if not step_fits(deadline, 4 * CALL_MAX_S) {
        return (None, [], "not enough time left in this job to write a tutorial");
    }
    DEADLINE["at"] = deadline;
    try {
        return _write_verified(spec, note, deadline);
    } finally {
        DEADLINE.pop("at", None);
    }
}

impl _write_verified(
    spec: JobSpec, note: Callable, deadline: float
) -> tuple[TutorialDraft | None, list[BlockView], str] {
    repo_root = Path(spec.repo_root);
    open_toolbox(repo_root, agent_catalog(repo_root), note);
    note("write", "no existing answer: researching and drafting a short tutorial");
    draft = write_tutorial(spec.question, spec.version);
    blocks: list[BlockView] = [];
    for attempt in range(MAX_REPAIRS + 1) {
        note("write", "draft: " + draft.title);
        blocks = verify_markdown(draft.body, note, deadline);
        failures: list[str] = [];
        if not blocks {
            failures = [
                "the tutorial has no ```jac code block; add a runnable example"
            ];
        } else {
            failures = [
                "block " + str(b.index + 1) + ": " + b.detail
                for b in blocks
                if not b.ok
            ];
        }
        if not failures {
            return (
                TutorialDraft(
                    title=draft.title,
                    summary=draft.summary,
                    body=draft.body,
                    blocks=blocks
                ),
                blocks,
                ""
            );
        }
        if attempt == MAX_REPAIRS {
            break;
        }
        if not step_fits(deadline, 3 * CALL_MAX_S) {
            note("repair", "out of time for this question; logging it as a docs gap");
            break;
        }
        note("repair", str(len(failures)) + " problem(s); fixing the draft");
        draft = repair_tutorial(spec.question, draft, failures, spec.version);
    }
    return (None, blocks, "could not produce a tutorial whose examples all pass");
}

impl Runner.busy -> bool {
    with self.lock {
        return self.spec is not None;
    }
}

impl Runner.start(spec: JobSpec, catalog: list[IndexDoc], work: Callable) -> bool {
    with self.lock {
        if self.spec is not None {
            return False;
        }
        if not spec.run_id {
            spec.run_id = uuid4().hex;
        }
        self.spec = spec;
        self.steps = [];
    }

    def run {
        outcome: Outcome = Outcome(status="failed", outcome="failed");
        try {
            outcome = work(spec, catalog, self.note);
        } except Exception as e {
            outcome = Outcome(
                status="failed",
                outcome="failed",
                detail=(type(e).__name__ + ": " + str(e))[:400]
            );
            self.note("failed", outcome.detail);
        }
        with self.lock {
            outcome.steps = list(self.steps);
            self.done.append(
                RunResult(run_id=spec.run_id, job_id=spec.job_id, outcome=outcome)
            );
            self.spec = None;
        }
    }
    threading.Thread(
        target=run, name="ninjaclaw-" + spec.job_id[:8], daemon=True
    ).start();
    return True;
}

impl Runner.note(phase: str, text: str) -> None {
    with self.lock {
        self.steps.append(StepView(at=stamp(), phase=phase, text=fit(text, 400)));
    }
}

impl Runner.live -> tuple[JobSpec | None, list[StepView]] {
    with self.lock {
        return (self.spec, list(self.steps));
    }
}

impl Runner.pending -> list[RunResult] {
    with self.lock {
        return list(self.done);
    }
}

impl Runner.ack(run_ids: list[str]) -> None {
    gone = set(run_ids);
    with self.lock {
        self.done = [
            r
            for r in self.done
            if r.run_id not in gone
        ];
    }
}

impl run_pipeline(spec: JobSpec, catalog: list[IndexDoc], note: Callable) -> Outcome {
    deadline = time.monotonic() + JOB_LEASE_S - LEASE_MARGIN_S;
    out = Outcome();
    note("classify", "reading the post");
    if classify_ask(spec.question) == AskKind.OFF_TOPIC {
        note("classify", "not a Jac question: ignoring it");
        out.status = "ignored";
        out.outcome = "ignored";
        return out;
    }
    note("retrieve", "searching the tutorials and the docs of the serving release");
    hits = search(catalog, spec.question, CANDIDATES);
    out.consulted = [h.doc.kind + ": " + h.doc.title for h in hits];
    if hits {
        note("retrieve", "candidates: " + ", ".join([h.doc.title for h in hits[:5]]));
        candidates = [
            Candidate(
                index=i,
                kind=h.doc.kind,
                title=h.doc.title,
                excerpt=excerpt(h.doc, spec.question)
            ) for (i, h) in enumerate(hits)
        ];
        note("judge", "checking whether a candidate answers it");
        pick = pick_answer(spec.question, candidates);
        if pick.index >= 0
            and pick.index < len(hits)
            and pick.confidence >= MIN_CONFIDENCE {
            doc = hits[pick.index].doc;
            note("judge", "matched " + doc.title + ": " + pick.why);
            out.outcome = "linked_tutorial"
                if doc.kind == "tutorial"
                else "linked_docs";
            out.links = [LinkView(title=doc.title, href=doc.href)];
            out.tutorial_slug = doc.key if doc.kind == "tutorial" else "";
            out.reply = link_reply(doc.title, doc.href, spec.job_id);
            return out;
        }
        note("judge", "no candidate answers it: " + pick.why);
    } else {
        note("retrieve", "nothing in the tutorials or docs matches");
    }
    if spec.repo_root {
        (tutorial, blocks, why) = write_verified(spec, note, deadline);
        out.blocks = blocks;
        if tutorial is not None {
            note("publish", "every example passed: publishing " + tutorial.title);
            out.outcome = "generated";
            out.tutorial = tutorial;
            out.reply = generated_reply(spec.job_id);
            return out;
        }
        note("gap", why);
        out.detail = why;
    }
    out.outcome = "gap";
    out.detail = out.detail or "no existing tutorial or docs page answers it";
    out.links = [LinkView(title=h.doc.title, href=h.doc.href) for h in hits[:2]];
    out.reply = gap_reply(out.links, spec.job_id);
    return out;
}
