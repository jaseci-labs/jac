"""Concurrent subagents using async walkers (event-loop IO-bound).

Async walkers interleave at every `await` point.  Three walkers each
make one LLM call — total wall-clock ≈ slowest single call, not sum.

Run:
    jac run async_subagents.jac
"""

import asyncio;
import time;
import from jaclang.byllm.llm { Model }

glob llm = Model(model_name="openrouter/google/gemma-2-9b-it:free");


# ---------------------------------------------------------------------------
# Async subagent walkers
# ---------------------------------------------------------------------------
async walker async_researcher {
    has topic: str,
        result: str = "";

    def answer(q: str) -> str by llm();
    async can run with Root entry {
        self.result = self.answer(f"In one sentence, what is {self.topic}?");
    }
}

async walker async_summariser {
    has text: str,
        result: str = "";

    def summarise(t: str) -> str by llm();
    async can run with Root entry {
        self.result = self.summarise(f"Summarise in ≤10 words: {self.text}");
    }
}

async walker async_translator {
    has text: str,
        lang: str,
        result: str = "";

    def translate(t: str, target: str) -> str by llm();
    async can run with Root entry {
        self.result = self.translate(
            f"Translate to {self.lang}: {self.text}", self.lang
        );
    }
}


# ---------------------------------------------------------------------------
# Async orchestrator — gathers all three on the event loop
# ---------------------------------------------------------------------------
async def run_all -> tuple {
    r = async_researcher(topic="the Jac programming language");
    s = async_summariser(
        text="Jac is a graph-native, agentic language built on Python that lets walkers traverse nodes."
    );
    tr = async_translator(text="Hello, world!", lang="French");

    await asyncio.gather(r.run(root), s.run(root), tr.run(root));

    return (r, s, tr);
}


glob t_start = time.time();

with entry {
    (r_done, s_done, tr_done) = asyncio.run(run_all());
}

glob elapsed = time.time() - t_start;

with entry {
    print(f"\n[researcher]  {r_done.result}");
    print(f"[summariser]  {s_done.result}");
    print(f"[translator]  {tr_done.result}");
    print(f"\nWall-clock: {elapsed:.2f}s  (async interleaved — close to max, not sum)");
}
